## 一、ReplicaManager的创建和启动  

在kafka启动中，在kafkaServer中会初始化ReplicaManager并启动。

```scala
//初始化
replicaManager = new ReplicaManager(config, metrics, time, zkUtils, kafkaScheduler, logManager,isShuttingDown, quotaManagers.follower)
//启动
replicaManager.startup()
```

ReplicaManager.scala的startup方法:

```scala
def startup() {
    scheduler.schedule("isr-expiration", maybeShrinkIsr, period = config.replicaLagTimeMaxMs / 2, unit = TimeUnit.MILLISECONDS)
    scheduler.schedule("isr-change-propagation", maybePropagateIsrChanges, period = 2500L, unit = TimeUnit.MILLISECONDS)
  }
```

启动的时候开启两个定时任务，`isr-expiration`和`isr-change-propagation`。

`isr-expiration`是`config.replicaLagTimeMaxMs / 2`执行一次.replicaLagTimeMaxMs的默认值是10000，也就是默认5s执行一次该任务。

`isr-change-propagation`是2.5s执行一次。

## 二、ReplicaManager管理的两个定时任务  

### 1、ISR过期管理任务

ISR过期管理任务主要负责将那些已经过期的replica移出ISR列表。

```scala
  private def maybeShrinkIsr(): Unit = {
    trace("Evaluating ISR list of partitions to see which replicas can be removed from the ISR")
    allPartitions.values.foreach(partition => partition.maybeShrinkIsr(config.replicaLagTimeMaxMs))
  }  
	//Partition.scala
  def maybeShrinkIsr(replicaMaxLagTimeMs: Long) {
    val leaderHWIncremented = inWriteLock(leaderIsrUpdateLock) {
      leaderReplicaIfLocal match {
        case Some(leaderReplica) =>
          //获取过期的ISR
          val outOfSyncReplicas = getOutOfSyncReplicas(leaderReplica, replicaMaxLagTimeMs)
          if(outOfSyncReplicas.nonEmpty) {
            val newInSyncReplicas = inSyncReplicas -- outOfSyncReplicas
            assert(newInSyncReplicas.nonEmpty)
            info("Shrinking ISR for partition [%s,%d] from %s to %s".format(topic, partitionId,
              inSyncReplicas.map(_.brokerId).mkString(","), newInSyncReplicas.map(_.brokerId).mkString(",")))
            //将新的ISR更新到zk，同时内存中的ISR也要更新
            updateIsr(newInSyncReplicas)
            replicaManager.isrShrinkRate.mark()
            //尝试更新HW
            maybeIncrementLeaderHW(leaderReplica)
          } else {
            false
          }

        case None => false // do nothing if no longer leader
      }
    }

    // 有一些延迟操作可能随着HW的改变可以完成，所以可以检查一下这些延迟操作是否完成
    if (leaderHWIncremented)
      tryCompleteDelayedRequests()
  }
```

- 如果当前broker的replica不是leader，不做任何操作。只有leader才能更新ISR的变动情况
- 获取过期ISR的规则很简单，每个replica都有记录一个lastCaughtUpTimeMs时间，如果超过replicaMaxLagTimeMs时间还没拉取过最新消息，说明这个replica要移出ISR了。replicaMaxLagTimeMs配置的默认值是10000，也就是10s。
- 更新ISR后会修改zk那边的配置
- ISR变动会kafka还会尝试推进HW的值，HW的推进规则后面会介绍
- 在更新ISR时，还会将要更新的partition放到`isrChangeSet`集合中去，同时更新`lastIsrChangeMs`时间，后面ISR变更通知任务会使用到。

### 2、ISR变更通知任务  

ISR变动时，为了让其他的broker能收到ISR变动的通知，会往zk的`/isr_change_notification`注册相应数据。Controller节点会监听这个zk节点数据的变动，发现这个zk节点的数据发生改变，就会重新拉取新的ISR信息，然后再将新的ISR信息发给各个broker。

```scala
  def maybePropagateIsrChanges() {
    val now = System.currentTimeMillis()
    isrChangeSet synchronized {
        //ReplicaManager.IsrChangePropagationBlackOut默认为5000L
        //ReplicaManager.IsrChangePropagationInterval默认为60000L
        //这两个都是常量，不是配置的值。
      if (isrChangeSet.nonEmpty &&
        (lastIsrChangeMs.get() + ReplicaManager.IsrChangePropagationBlackOut < now ||
          lastIsrPropagationMs.get() + ReplicaManager.IsrChangePropagationInterval < now)) {
        ReplicationUtils.propagateIsrChanges(zkUtils, isrChangeSet)
        isrChangeSet.clear()
        lastIsrPropagationMs.set(now)
      }
    }
  }
```

从代码看，这个任务做的事情也很简单，就是将前面`isr-expiration`产生变动ISR的partition发送到zk的`/isr_change_notification`节点中。

为了避免太过频繁的去发送变更通知，这里设置了两个频率常量(数值是写死的，和kafka的配置无关)，这样可以让各个partition的ISR变动通知尽量批量发送，提供吞吐量。

## 三、副本复制数据   

kafka的broker启动后，并不会知道自己存储的那些分区是leader还是follow，因此broker启动后并不会马上开启消息的复制。

副本开始复制消息和controller有关系，当一个新的broker加入集群，controller会感知到，并获取该broker上的所有分区，判断哪些是follow，哪些是leader。最后会发送LEADER_AND_ISR请求给broker。broker收到请求后，将自己管理的分区标识是否是leader，不是leader的那些分区开始向leader拉取消息。

ReplicaManager上面有一个`ReplicaFetcherManager`组件，当某分区成为follow时，就创建一个线程开始复制消息。 这个线程会不断往leader发送`FETCH`请求拉取数据。

```scala
val replicaFetcherManager = new ReplicaFetcherManager(config, this, metrics, time, threadNamePrefix, quotaManager)
```

### leader处理follow的fetch请求  

leader处理完fetch请求后，如果发现请求客户端是follow所在的broker，还会进行一些额外处理。下面是ReplicaManager中拉取消息的代码 

```scala
  def fetchMessages(timeout: Long,
                    replicaId: Int,
                    fetchMinBytes: Int,
                    fetchMaxBytes: Int,
                    hardMaxBytesLimit: Boolean,
                    fetchInfos: Seq[(TopicPartition, PartitionData)],
                    quota: ReplicaQuota = UnboundedQuota,
                    responseCallback: Seq[(TopicPartition, FetchPartitionData)] => Unit) {
    val isFromFollower = replicaId >= 0
    val fetchOnlyFromLeader: Boolean = replicaId != Request.DebuggingConsumerId
    val fetchOnlyCommitted: Boolean = ! Request.isValidBrokerId(replicaId)

    //读取数据
    val logReadResults = readFromLocalLog(
      replicaId = replicaId,
      fetchOnlyFromLeader = fetchOnlyFromLeader,
      readOnlyCommitted = fetchOnlyCommitted,
      fetchMaxBytes = fetchMaxBytes,
      hardMaxBytesLimit = hardMaxBytesLimit,
      readPartitionInfo = fetchInfos,
      quota = quota)

    //如果请求是从follow发出的，需要更新对应replica的LEO，并推进HW
    if(Request.isValidBrokerId(replicaId))
      updateFollowerLogReadResults(replicaId, logReadResults)
	...
  }

  private def updateFollowerLogReadResults(replicaId: Int, readResults: Seq[(TopicPartition, LogReadResult)]) {
    debug("Recording follower broker %d log read results: %s ".format(replicaId, readResults))
    readResults.foreach { case (topicPartition, readResult) =>
      getPartition(topicPartition) match {
        case Some(partition) =>
          //更新replica的一些信息
          partition.updateReplicaLogReadResult(replicaId, readResult)

          tryCompleteDelayedProduce(new TopicPartitionOperationKey(topicPartition))
        case None =>
          warn("While recording the replica LEO, the partition %s hasn't been created.".format(topicPartition))
      }
    }
  }

  def updateReplicaLogReadResult(replicaId: Int, logReadResult: LogReadResult) {
    getReplica(replicaId) match {
      case Some(replica) =>
        replica.updateLogReadResult(logReadResult)
        //如果该replica没在isr中，就把它加入到isr中
        //更新isr后，还会尝试推进HW
        maybeExpandIsr(replicaId, logReadResult)

        debug("Recorded replica %d log end offset (LEO) position %d for partition %s."
          .format(replicaId, logReadResult.info.fetchOffsetMetadata.messageOffset, topicPartition))
      case None =>
        throw new NotAssignedReplicaException(("Leader %d failed to record follower %d's position %d since the replica" +
          " is not recognized to be one of the assigned replicas %s for partition %s.")
          .format(localBrokerId,
                  replicaId,
                  logReadResult.info.fetchOffsetMetadata.messageOffset,
                  assignedReplicas.map(_.brokerId).mkString(","),
                  topicPartition))
    }
  }
```

首先，leader会维护一个`assignedReplicaMap`，保存该partition下所有的Replica。这些Replica下都有具体的一些信息，比如LEO、_lastCaughtUpTimeMs、lastFetchTimeMs等信息。

当leader处理完来自follow的fetch请求后，会更新对应Replica对象的_lastCaughtUpTimeMs，然后查看是否要把此Replica加进ISR中(可能之前这个replica没在ISR中)，最后尝试推进HW。

### leader推进HW

在以下场景时，leader会尝试推进HW

1. partiton的ISR发送变动时   
2. 某个replica的LEO发生改变时  

HW的更新规则

```scala
  private def maybeIncrementLeaderHW(leaderReplica: Replica, curTime: Long = time.milliseconds): Boolean = {
      //获取isr以及最后一次更新时间小于replicaLagTimeMaxMs的replica的LEO
    val allLogEndOffsets = assignedReplicas.filter { replica =>
      curTime - replica.lastCaughtUpTimeMs <= replicaManager.config.replicaLagTimeMaxMs || inSyncReplicas.contains(replica)
    }.map(_.logEndOffset)
      //找最小的那个
    val newHighWatermark = allLogEndOffsets.min(new LogOffsetMetadata.OffsetOrdering)
    val oldHighWatermark = leaderReplica.highWatermark
    if (oldHighWatermark.messageOffset < newHighWatermark.messageOffset || oldHighWatermark.onOlderSegment(newHighWatermark)) {
      leaderReplica.highWatermark = newHighWatermark
      debug("High watermark for partition [%s,%d] updated to %s".format(topic, partitionId, newHighWatermark))
      true
    } else {
      debug("Skipping update high watermark since Old hw %s is larger than new hw %s for partition [%s,%d]. All leo's are %s"
        .format(oldHighWatermark, newHighWatermark, topic, partitionId, allLogEndOffsets.mkString(",")))
      false
    }
  }
```

HW的更新规则很简单，就是找ISR以及最后一次更新时间小于replicaLagTimeMaxMs的replica的LEO，然后取其中最小的那个LEO。要注意的是，这里要加上那些以及满足加入ISR条件但是还未加入ISR的replica。