[TOC]

## 一、LogManager结构
![](http://on-img.com/chart_image/5b717077e4b067df5a071754.png?_=1534417180862)

## 二、LogManager的创建

LogManager，即日志管理组件，在kafka启动时会创建并启动。

```scala
private def createLogManager(zkClient: ZkClient, brokerState: BrokerState): LogManager = {
    val defaultProps = KafkaServer.copyKafkaConfigToLog(config)
    val defaultLogConfig = LogConfig(defaultProps)
	//从zk获取各个topic的相关配置
    val configs = AdminUtils.fetchAllTopicConfigs(zkUtils).map { case (topic, configs) =>
      topic -> LogConfig.fromProps(defaultProps, configs)
    }
    // read the log configurations from zookeeper
    val cleanerConfig = CleanerConfig(numThreads = config.logCleanerThreads,
                                      dedupeBufferSize = config.logCleanerDedupeBufferSize,
                                      dedupeBufferLoadFactor = config.logCleanerDedupeBufferLoadFactor,
                                      ioBufferSize = config.logCleanerIoBufferSize,
                                      maxMessageSize = config.messageMaxBytes,
                                      maxIoBytesPerSecond = config.logCleanerIoMaxBytesPerSecond,
                                      backOffMs = config.logCleanerBackoffMs,
                                      enableCleaner = config.logCleanerEnable)
    new LogManager(logDirs = config.logDirs.map(new File(_)).toArray,
                   topicConfigs = configs,
                   defaultConfig = defaultLogConfig,
                   cleanerConfig = cleanerConfig,
                   ioThreads = config.numRecoveryThreadsPerDataDir,
                   flushCheckMs = config.logFlushSchedulerIntervalMs,
                   flushCheckpointMs = config.logFlushOffsetCheckpointIntervalMs,
                   retentionCheckMs = config.logCleanupIntervalMs,
                   scheduler = kafkaScheduler,
                   brokerState = brokerState,
                   time = time)
  }
```

LogManager创建后，会先后做两件事

1. 检查日志目录
2. 加载日志目录的文件

##### 检查日志目录

```scala
  private def createAndValidateLogDirs(dirs: Seq[File]) {
    if(dirs.map(_.getCanonicalPath).toSet.size < dirs.size)
      throw new KafkaException("Duplicate log directory found: " + logDirs.mkString(", "))
    for(dir <- dirs) {
      if(!dir.exists) {
        info("Log directory '" + dir.getAbsolutePath + "' not found, creating it.")
        val created = dir.mkdirs()
        if(!created)
          throw new KafkaException("Failed to create data directory " + dir.getAbsolutePath)
      }
      if(!dir.isDirectory || !dir.canRead)
        throw new KafkaException(dir.getAbsolutePath + " is not a readable log directory.")
    }
  }
```

1. 配置的日志目录是否有重复的
2. 日志目录不存在的话就新建一个日志目录
3. 检查日志目录是否可读

##### 加载日志目录的文件

```scala
 private def loadLogs(): Unit = {
    info("Loading logs.")
    val startMs = time.milliseconds
    val threadPools = mutable.ArrayBuffer.empty[ExecutorService]
    val jobs = mutable.Map.empty[File, Seq[Future[_]]]
    //logDirs和配置的日志存放目录路径有关
    for (dir <- this.logDirs) {
      val pool = Executors.newFixedThreadPool(ioThreads)
      threadPools.append(pool)
      //检查上一次关闭是否是正常关闭
      val cleanShutdownFile = new File(dir, Log.CleanShutdownFile)

      if (cleanShutdownFile.exists) {
        debug(
          "Found clean shutdown file. " +
          "Skipping recovery for all logs in data directory: " +
          dir.getAbsolutePath)
      } else {
        // log recovery itself is being performed by `Log` class during initialization
        brokerState.newState(RecoveringFromUncleanShutdown)
      }
      //读取日志检查点
      var recoveryPoints = Map[TopicPartition, Long]()
      try {
        recoveryPoints = this.recoveryPointCheckpoints(dir).read
      } catch {
        case e: Exception =>
          warn("Error occured while reading recovery-point-offset-checkpoint file of directory " + dir, e)
          warn("Resetting the recovery checkpoint to 0")
      }

      val jobsForDir = for {
        dirContent <- Option(dir.listFiles).toList
        logDir <- dirContent if logDir.isDirectory
      } yield {
        CoreUtils.runnable {
          debug("Loading log '" + logDir.getName + "'")
          //根据目录名解析partiton的信息，比如test-0，解析等到的patition就是topic test下的0号分区
          val topicPartition = Log.parseTopicPartitionName(logDir)
          val config = topicConfigs.getOrElse(topicPartition.topic, defaultConfig)
          val logRecoveryPoint = recoveryPoints.getOrElse(topicPartition, 0L)

          val current = new Log(logDir, config, logRecoveryPoint, scheduler, time)
          if (logDir.getName.endsWith(Log.DeleteDirSuffix)) {
            this.logsToBeDeleted.add(current)
          } else {
            val previous = this.logs.put(topicPartition, current)
            //判断是否有重复的分区数据目录
            if (previous != null) {
              throw new IllegalArgumentException(
                "Duplicate log directories found: %s, %s!".format(
                  current.dir.getAbsolutePath, previous.dir.getAbsolutePath))
            }
          }
        }
      }

      jobs(cleanShutdownFile) = jobsForDir.map(pool.submit).toSeq
    }


    try {
      for ((cleanShutdownFile, dirJobs) <- jobs) {
        //等待所有任务完成
        dirJobs.foreach(_.get)
        cleanShutdownFile.delete()
      }
    } catch {
      case e: ExecutionException => {
        error("There was an error in one of the threads during logs loading: " + e.getCause)
        throw e.getCause
      }
    } finally {
      threadPools.foreach(_.shutdown())
    }

    info(s"Logs loading complete in ${time.milliseconds - startMs} ms.")
  }
```

遍历每个日志目录时，会先读取日志检查点文件，然后读取日志目录下的所有文件，然后创建相关的Log对象。需要注意的是，由于加载过程比较慢，对于每个日志目录都会创建一个线程来加载，最后等所有线程都加载完毕后才会退出`loadLogs()`方法。

因此，创建LogManager的过程是阻塞的，当LogManager创建完成后，说明所有的分区目录都加载进来了。

## 三、启动LogManager

创建LogManager后，就会立马调用`startup()`方法启动。

```scala
def startup() {
    /* Schedule the cleanup task to delete old logs */
    if(scheduler != null) {
      info("Starting log cleanup with a period of %d ms.".format(retentionCheckMs))
      scheduler.schedule("kafka-log-retention",
                         cleanupLogs,
                         delay = InitialTaskDelayMs,
                         period = retentionCheckMs,
                         TimeUnit.MILLISECONDS)
      info("Starting log flusher with a default period of %d ms.".format(flushCheckMs))
      scheduler.schedule("kafka-log-flusher", 
                         flushDirtyLogs, 
                         delay = InitialTaskDelayMs, 
                         period = flushCheckMs, 
                         TimeUnit.MILLISECONDS)
      scheduler.schedule("kafka-recovery-point-checkpoint",
                         checkpointRecoveryPointOffsets,
                         delay = InitialTaskDelayMs,
                         period = flushCheckpointMs,
                         TimeUnit.MILLISECONDS)
      scheduler.schedule("kafka-delete-logs",
                         deleteLogs,
                         delay = InitialTaskDelayMs,
                         period = defaultConfig.fileDeleteDelayMs,
                         TimeUnit.MILLISECONDS)
    }
    if(cleanerConfig.enableCleaner)
      cleaner.startup()
}
```

LogManager的启动其实就是提交了4个定时任务，以及根据配置而定开启一个日志清理组件。

### 4个定时任务

1. 旧的日志段删除任务
2. 刷盘任务
3. 检查点任务
4. 分区目录删除任务

## 四、旧的日志段删除任务   

在LogManager启动后，会提交一个周期性的日志段删除任务，用来处理一些超过一定时间以及大小的日志段。这个任务的执行周期和`log.retention.check.interval.ms`有关系，默认值是300000，也就是每5分钟执行一次删除任务。执行的任务方法如下:

```scala
def cleanupLogs() {
    debug("Beginning log cleanup...")
    var total = 0
    val startMs = time.milliseconds
    for(log <- allLogs; if !log.config.compact) {
      debug("Garbage collecting '" + log.name + "'")
      //遍历所有日志，调用log组件的方法删除日志
      total += log.deleteOldSegments()
    }
    debug("Log cleanup completed. " + total + " files deleted in " +
                  (time.milliseconds - startMs) / 1000 + " seconds")
}

def deleteOldSegments(): Int = {
    if (!config.delete) return 0
    //一种是根据时间过期的策略删除日志，一种是根据大小去删除日志。
    deleteRetenionMsBreachedSegments() + deleteRetentionSizeBreachedSegments()
}
```

Kafka对于旧日志段的处理方式有两种

1. 删除：超过时间或大小阈值的旧 segment，直接进行删除；
2. 压缩：不是直接删除日志分段，而是采用合并压缩的方式进行。

Kafka删除的检查策略有两种。一种根据时间过期的策略删除过期的日志，一种是根据日志大小来删除太大的日志。

##### 根据时间策略删除相关日志  

该策略和配置`retention.ms`有关系

```scala
//根据时间策略删除相关日志段
private def deleteRetenionMsBreachedSegments() : Int = {
    if (config.retentionMs < 0) return 0
    val startMs = time.milliseconds
    //传到deleteOldSegments方法中的参数是一个高阶函数，后面的方法中，会遍历所有的segment，并调用此方法
    //一般从最旧的segment开始遍历
    deleteOldSegments(startMs - _.largestTimestamp > config.retentionMs)
}
private def deleteOldSegments(predicate: LogSegment => Boolean): Int = {
    lock synchronized {
      //遍历所有的segment，如果目标segment的largestTimestamp已经到达过期时间了，就标记要删除
      //另外，如果遍历到的segment是最新的一个segment，并且该segment的大小是0，这个segment就不会被删除
      val deletable = deletableSegments(predicate)
      val numToDelete = deletable.size
      if (numToDelete > 0) {
        //如果全部的segment都过期了,为了保证至少有一个segment在工作，我们需要新建一个segment
        if (segments.size == numToDelete)
          roll()
        //异步删除日志段
        deletable.foreach(deleteSegment)
      }
      numToDelete
    }
}
```

上面的代码把所有过期的日志段删除，`config.retentionMs`取决于配置`log.retention.hours`默认为168个小时，也就是7天。删除时要注意两点:

1. 对于那些大小为0并且是正在使用中的日志段不会被删除
2. 如果扫描完发现全部的日志段都过期了，就要马上新生成一个新的日志段来处理后面的消息
3. 日志段的删除时异步的，此处只会标记一下，往日志段文件后面加上`.delete`后缀，然后开启一个定时任务删除文件。定时任务的延迟时间和`file.delete.delay.ms`有关系。

##### 根据日志大小删除相关日志

该删除策略和配置`retention.bytes`有关系。该策略可以保证分区目录的大小始终保持在一个限制的范围内。

```scala
private def deleteRetentionSizeBreachedSegments() : Int = {
    if (config.retentionSize < 0 || size < config.retentionSize) return 0
    //diff表示超出限制的大小
    var diff = size - config.retentionSize
    //这是一个高阶函数，后面的方法中，会遍历所有的segment，并调用此方法
    //一般从最旧的segment开始遍历
    def shouldDelete(segment: LogSegment) = {
      if (diff - segment.size >= 0) {
        diff -= segment.size
        true
      } else {
        false
      }
    }
    deleteOldSegments(shouldDelete)
}
//和时间过期策略调用的是同一个方法，只是传入的predicate函数不一样
private def deleteOldSegments(predicate: LogSegment => Boolean): Int = {
    lock synchronized {
      //遍历所有的segment，如果目标segment的largestTimestamp已经到达过期时间了，就标记要删除
      //另外，如果遍历到的segment是最新的一个segment，并且该segment的大小是0，这个segment就不会被删除
      val deletable = deletableSegments(predicate)
      val numToDelete = deletable.size
      if (numToDelete > 0) {
        //如果全部的segment都过期了,为了保证至少有一个segment在工作，我们需要新建一个segment
        if (segments.size == numToDelete)
          roll()
        //异步删除日志段
        deletable.foreach(deleteSegment)
      }
      numToDelete
    }
}
```

这个策略的扫描逻辑大概是这样的

1. 通过`size-retentionSize`算出diff
2. 遍历segment，对于大小超过diff的日志段，就标记删除。然后将diff的值设置为`diff-segment.size`

使用这种策略，当分区目录下只有一个日志段时，无论该日志段多大，都不会被删除。另外，和时间策略一样，这个删除也是异步删除

## 五、刷盘任务  

kafka在处理Producer请求时，只是将日志写到缓存，并没有执行flush()方法刷到磁盘。因此，logManager中开启了一个刷盘任务，定期检查各个目录，根据刷盘策略执行flush操作。这个任务保证了每隔多久kafka会执行一次刷盘操作。

```scala
  private def flushDirtyLogs() = {
    debug("Checking for dirty logs to flush...")

    for ((topicPartition, log) <- logs) {
      try {
        val timeSinceLastFlush = time.milliseconds - log.lastFlushTime
        debug("Checking if flush is needed on " + topicPartition.topic + " flush interval  " + log.config.flushMs +
              " last flushed " + log.lastFlushTime + " time since last flush: " + timeSinceLastFlush)
        if(timeSinceLastFlush >= log.config.flushMs)
          log.flush
      } catch {
        case e: Throwable =>
          error("Error flushing topic " + topicPartition.topic, e)
      }
    }
  }
```

当距离上次刷盘的时间超过了`log.config.flushMs`时间就会执行一次刷盘，将缓存中的内容持久化到磁盘。但是kafka官方给刷盘频率设置的默认值是Long的最大值，也就是说，kafka官方的建议是把刷盘操作交给操作系统来控制。

另外，这个刷盘任务这是控制指定时间刷盘一次。kafka还有一个关于刷盘的策略是根据日志的条数来控制刷盘频率的，也就是配置`flush.messages`。这个配置是在每次写日志完检查的，当kafka处理Producer请求写日志到缓存后，会检查当前的offset和之前记录的offset直接的差值，如果超过配置的值，就执行一次刷盘。不过`flush.messages`的默认值也是Long的最大值。

## 六、检查点任务

```scala
  def checkpointRecoveryPointOffsets() {
    this.logDirs.foreach(checkpointLogsInDir)
  }
  private def checkpointLogsInDir(dir: File): Unit = {
    val recoveryPoints = this.logsByDir.get(dir.toString)
    if (recoveryPoints.isDefined) {
        //recoveryPoint表示还未刷到磁盘的第一条offset，比如offset=100之前的消息都刷到磁盘中了，那么recoveryPoint就是101
   this.recoveryPointCheckpoints(dir).write(recoveryPoints.get.mapValues(_.recoveryPoint))
    }
  }
```

首先，恢复点是异常关闭时用来恢复数据的。如果数据目录下有`.kafka_cleanshutdown`文件就表示不是异常关闭，就用不上恢复点了。

日志的恢复代码 

```scala
//Log.scala  
private def recoverLog() {
    // if we have the clean shutdown marker, skip recovery
    if(hasCleanShutdownFile) {
      this.recoveryPoint = activeSegment.nextOffset
      return
    }

    // okay we need to actually recovery this log
    val unflushed = logSegments(this.recoveryPoint, Long.MaxValue).iterator
    while(unflushed.hasNext) {
      val curr = unflushed.next
      info("Recovering unflushed segment %d in log %s.".format(curr.baseOffset, name))
      val truncatedBytes =
        try {
          curr.recover(config.maxMessageSize)
        } catch {
          case _: InvalidOffsetException =>
            val startOffset = curr.baseOffset
            warn("Found invalid offset during recovery for log " + dir.getName +". Deleting the corrupt segment and " +
                 "creating an empty one with starting offset " + startOffset)
            curr.truncateTo(startOffset)
        }
      if(truncatedBytes > 0) {
        // we had an invalid message, delete all remaining log
        warn("Corruption found in segment %d of log %s, truncating to offset %d.".format(curr.baseOffset, name, curr.nextOffset))
        unflushed.foreach(deleteSegment)
      }
    }
  }
```



## 七、分区目录删除任务

该任务执行的任务主要是删除分区目录，同时删除底下的segment数据文件。

```scala
  private def deleteLogs(): Unit = {
    try {
      var failed = 0
        //遍历待删除列表的元素，逐一删除分区目录
      while (!logsToBeDeleted.isEmpty && failed < logsToBeDeleted.size()) {
        val removedLog = logsToBeDeleted.take()
        if (removedLog != null) {
          try {
            removedLog.delete()
            info(s"Deleted log for partition ${removedLog.topicPartition} in ${removedLog.dir.getAbsolutePath}.")
          } catch {
            case e: Throwable =>
              error(s"Exception in deleting $removedLog. Moving it to the end of the queue.", e)
              failed = failed + 1
              logsToBeDeleted.put(removedLog)
          }
        }
      }
    } catch {
      case e: Throwable => 
        error(s"Exception in kafka-delete-logs thread.", e)
}
```

做的事情主要就是遍历logsToBeDeleted列表，然后遍历删除元素。

那么什么时候分区会被加到logsToBeDeleted中待删除呢？

1. LogManager启动时会扫描所有分区目录名结尾是'-delete'的分区，加入到logsToBeDeleted中
2. 分区被删除的时候走的都是异步删除策略，会先被加入到logsToBeDeleted中等待删除。

在kafka中，要删除分区需要往broker发送StopReplica请求。broker收到StopReplica请求后，判断是否需要删除分区，如果要删除就执行异步删除步骤，异步删除的代码主要如下 

```scala
  def asyncDelete(topicPartition: TopicPartition) = {
    //从内存中删去相关数据
    val removedLog: Log = logCreationOrDeletionLock synchronized {
        logs.remove(topicPartition)
    }
    if (removedLog != null) {
      //We need to wait until there is no more cleaning task on the log to be deleted before actually deleting it.
      if (cleaner != null) {
        cleaner.abortCleaning(topicPartition)
        cleaner.updateCheckpoints(removedLog.dir.getParentFile)
      }
      //往分区目录名称的最后加上 '-delete'，表示准备删除
      val dirName = Log.logDeleteDirName(removedLog.name)
      //关闭分区目录
      removedLog.close()
      val renamedDir = new File(removedLog.dir.getParent, dirName)
      val renameSuccessful = removedLog.dir.renameTo(renamedDir)
      if (renameSuccessful) {
        removedLog.dir = renamedDir
        // change the file pointers for log and index file
        for (logSegment <- removedLog.logSegments) {
          logSegment.log.setFile(new File(renamedDir, logSegment.log.file.getName))
          logSegment.index.file = new File(renamedDir, logSegment.index.file.getName)
        }
        //加入待删除列表
        logsToBeDeleted.add(removedLog)
        removedLog.removeLogMetrics()
        info(s"Log for partition ${removedLog.topicPartition} is renamed to ${removedLog.dir.getAbsolutePath} and is scheduled for deletion")
      } else {
        throw new KafkaStorageException("Failed to rename log directory from " + removedLog.dir.getAbsolutePath + " to " + renamedDir.getAbsolutePath)
      }
    }
  }
```

1. 需要先把分区目录标记一下，在后缀加上'-delete'表示该分区准备删除了。这样做可以防止如果删除时间没到就宕机，下次重启时可以扫描'-delete'结尾的分区再删除
2. 把分区目录添加到logsToBeDeleted中待删除

## 八、多磁盘选择机制  

当配置了多个磁盘时，kafka是怎么保证数据均匀分布在各个磁盘呢？

这里多磁盘只的是配置`log.dirs`中配置了多个目录。

这个问题和kafka创建一个新的partition时，如何选择目录有关系，下面是kafka创建partition的代码

```scala
  def createLog(topicPartition: TopicPartition, config: LogConfig): Log = {
    logCreationOrDeletionLock synchronized {
      // create the log if it has not already been created in another thread
      getLog(topicPartition).getOrElse {
          //选择新的partition要放在哪个数据目录上
        val dataDir = nextLogDir()
        val dir = new File(dataDir, topicPartition.topic + "-" + topicPartition.partition)
        dir.mkdirs()
        val log = new Log(dir, config, recoveryPoint = 0L, scheduler, time)
        logs.put(topicPartition, log)
        info("Created log for partition [%s,%d] in %s with properties {%s}."
          .format(topicPartition.topic,
            topicPartition.partition,
            dataDir.getAbsolutePath,
            config.originals.asScala.mkString(", ")))
        log
      }
    }
  }

  private def nextLogDir(): File = {
    if(logDirs.size == 1) {
      logDirs(0)
    } else {
        //各个数据目录的文件数量
      val logCounts = allLogs.groupBy(_.dir.getParent).mapValues(_.size)
        //有一些数据目录底下可能没有partition目录
      val zeros = logDirs.map(dir => (dir.getPath, 0)).toMap
      var dirCounts = (zeros ++ logCounts).toBuffer
    
      //排序后，取当前文件数量最小的那个数据目录
      val leastLoaded = dirCounts.sortBy(_._2).head
      new File(leastLoaded._1)
    }
  }
```

从`nextLogDir()`代码中可以看出，当新建一个新的partition目录时，主要还是取partition文件最少的那个数据目录。

这样在极端情况下可能会有一些问题，可能两个数据目录底下的partition文件数一样，但是其中一个数据目录数据量非常大的情况（各个partition的数据量不一样）。因此，在选择多磁盘时也要注意一下，避免造成资源浪费。

## 九、日志清理机制   

