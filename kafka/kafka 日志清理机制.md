
[toc]
## 一. 日志清理是干什么的？

kafka的日志清理机制主要用于缩减日志的大小，它并不是指通过压缩算法对日志文件进行压缩，而是对重复的日志进行清理来达到目的。在日志清理过程中，会清理重复的key，最后只会保留最后一条key，可以理解为map的put方法。在清理完后，一些segment的文件大小就会变小，这时候，kafka会将那些小的文件再合并成一个大的segment文件。

另外，通过日志清理功能，我们可以做到删除某个key的功能。推送value为null的key到kafka，kafka在做日志清理时就会将这条key从日志中删去。

![在这里插入图片描述](https://img-blog.csdn.net/20180920205417111?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3UwMTMzMzIxMjQ=/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

## 二. 清理相关原理  

对于每一个kafka partition的日志，以segment为单位，都会被分为两部分，**已清理**和**未清理**的部分。同时，未清理的那部分又分为**可以清理的**和**不可清理的**。

![](http://on-img.com/chart_image/5ba233ede4b0d4d65c0e73e4.png?_=1537356964922)

每个日志目录下都会有一个文件`cleaner-offset-checkpoint`来记录当前清理到哪里了，这时候kafka就知道哪部分是已经清理的，哪部分是未清理的。

接着，在未清理的segment中，找出可以清理的那部分segment。首先，active segment肯定是不能清理的。接着kafka会根据`min.compaction.lag.ms`配置找出不能清理的segment，规则是根据segment最后的一条记录的插入时间是否已经超过最小保留时间，如果没有，这个segment就不能清理。这是为了保证日志至少存留多长时间才会被清理。

找出可以清理的segment后，kafka会构建一个SkimpyOffsetMap对象，这个对象是一个key与offset的映射关系的哈希表。接着会遍历可以清理那部分的segment的每一条日志，然后将key和offset存到SkimpyOffsetMap中。

之后，再遍历**已清理部分**和**可以清理部分**的segment的每一条日志，根据SkimpyOffsetMap来判断是否保留。假设一条日志key的offset是1，但是在SkimpyOffsetMap中对应key的offset是100，那么这条日志就可以清楚掉了。

最后，再两次遍历后，可清理部分的segment已变已清理的segment了。同时cleaner checkpoint会执行已经清理的segment的最后一条offset。

## 三、墓碑消息（tombstone）

对于value为null的日志，kafka称这种日志为tombstone，也就是墓碑消息。在执行日志清理时，会删除到期的墓碑消息。墓碑消息的存放时间和broker的配置`log.cleaner.delete.retention.ms`有关，它的默认值是24小时。

kafka做日志清理时，会根据一些规则判断是否要保留墓碑消息。判断规则如下：

> 所在LogSegment的lastModifiedTime + deleteRetionMs > 可清理部分中最后一个LogSegment的lastModifiedTime

所以，墓碑消息的保留时间和已清理部分的最后一个segment有关系。

## 四、日志segment合并  

再经过一次次清理后，各个segment大小会慢慢变小。为了避免日志目录下有过多的小文件，kafka在每次日志清理后会进行小文件日志合并。kafka会保证合并后的segment大小不超过segmentSize(通过log.segments.bytes设置，默认值是1G)，且对应的索引文件占用大小之和不超过maxIndexSize（可以通过broker端参数log.index.interval.bytes设置，默认值为10MB）。

下面是日志合并的示意图：

![在这里插入图片描述](https://img-blog.csdn.net/20180920205433628?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3UwMTMzMzIxMjQ=/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

## 五、清理线程的启动

kafka日志清理是交给LogCleaner组件来完成的。

kafka在启动LogManager时，如果日志清理机制开启的话，就会启动LogCleaner组件开始定时的清理日志。是否开启日志清理是由broker的`log.cleaner.enable`来决定的，默认是开启的。

LogCleaner启动后，会注册n个线程CleanerThread，开始不断的检查日志并清理。这个线程数量和broker的配置`log.cleaner.threads`有关系，默认值是1。当清理线程启动后，就开始检查是否有日志需要清理，接着清理完再检查是否有日志需要清理。如果发现没有需要清理的日志，这个线程会进入休眠，休眠时间根据broker的`log.cleaner.backoff.ms`来决定，默认值是15000。

```scala
//LogCleaner.scala
private[log] val cleanerManager = new LogCleanerManager(logDirs, logs)
private val cleaners = (0 until config.numThreads).map(new CleanerThread(_))
def startup() {
    info("Starting the log cleaner")
    cleaners.foreach(_.start())
}
//CleanerThread.scala
override def doWork() {
   cleanOrSleep()
}
private def cleanOrSleep() {
    //获取哪些日志可以清理,grabFilthiestCompactedLog方法只会返回一个partition的日志
      val cleaned = cleanerManager.grabFilthiestCompactedLog(time) match {
        case None =>
          false
        case Some(cleanable) =>
          //这里拿到要清理的日志
          var endOffset = cleanable.firstDirtyOffset
          try {
              //开始清理日志
            val (nextDirtyOffset, cleanerStats) = cleaner.clean(cleanable)
            recordStats(cleaner.id, cleanable.log.name, cleanable.firstDirtyOffset, endOffset, cleanerStats)
            endOffset = nextDirtyOffset
          } catch {
            case _: LogCleaningAbortedException => // task can be aborted, let it go.
          } finally {
            cleanerManager.doneCleaning(cleanable.topicPartition, cleanable.log.dir.getParentFile, endOffset)
          }
          true
      }
    	//删除一些旧的日志
      val deletable: Iterable[(TopicPartition, Log)] = cleanerManager.deletableLogs()
      deletable.foreach{
        case (topicPartition, log) =>
          try {
            log.deleteOldSegments()
          } finally {
            cleanerManager.doneDeleting(topicPartition)
          }
      }
      //如果没有要清理的日志，就进入休眠
      if (!cleaned)
        backOffWaitLatch.await(config.backOffMs, TimeUnit.MILLISECONDS)
}
```

## 六、通过dirtyRatio获取要清理的partition日志

在`cleanerManager.grabFilthiestCompactedLog`方法中，在这里，kafka会遍历该broker上所有partition目录，判断这些partition是否可以清理，然后从可以清理的那些partition中找出dirtyRatio最高的日志，开始清理。

```scala
//CleanerManager.scala
def grabFilthiestCompactedLog(time: Time): Option[LogToClean] = {
    inLock(lock) {
      val now = time.milliseconds
      this.timeOfLastRun = now
      val lastClean = allCleanerCheckpoints
      val dirtyLogs = logs.filter {
          //判断这个partition log是否可以清理
        case (_, log) => log.config.compact  // match logs that are marked as compacted
      }.filterNot {
          //可能其他线程在清理这个partition log了
        case (topicPartition, _) => inProgress.contains(topicPartition) // skip any logs already in-progress
      }.map {
        case (topicPartition, log) => // create a LogToClean instance for each
          //获取可清理部分的第一条offset和不可清理部分的第一条offset
          val (firstDirtyOffset, firstUncleanableDirtyOffset) = LogCleanerManager.cleanableOffsets(log, topicPartition,
            lastClean, now)
          LogToClean(topicPartition, log, firstDirtyOffset, firstUncleanableDirtyOffset)
      }.filter(ltc => ltc.totalBytes > 0) // skip any empty logs
      this.dirtiestLogCleanableRatio = if (dirtyLogs.nonEmpty) dirtyLogs.max.cleanableRatio else 0
      // 获取dirtyRatio最高的partiton log
      val cleanableLogs = dirtyLogs.filter(ltc => ltc.cleanableRatio > ltc.log.config.minCleanableRatio)
      if(cleanableLogs.isEmpty) {
        None
      } else {
        val filthiest = cleanableLogs.max
        inProgress.put(filthiest.topicPartition, LogCleaningInProgress)
        Some(filthiest)
      }
    }
  }

  def cleanableOffsets(log: Log, topicPartition: TopicPartition, lastClean: immutable.Map[TopicPartition, Long], now: Long): (Long, Long) = {
    val lastCleanOffset: Option[Long] = lastClean.get(topicPartition)

    // 找出之前清理到哪个offset了，从而找到未清理部分的第一条offset
    val logStartOffset = log.logSegments.head.baseOffset
    val firstDirtyOffset = {
      val offset = lastCleanOffset.getOrElse(logStartOffset)
      if (offset < logStartOffset) {
        // don't bother with the warning if compact and delete are enabled.
        if (!isCompactAndDelete(log))
          warn(s"Resetting first dirty offset to log start offset $logStartOffset since the checkpointed offset $offset is invalid.")
        logStartOffset
      } else {
        offset
      }
    }

    // 先把active segment排除出去
    val dirtyNonActiveSegments = log.logSegments(firstDirtyOffset, log.activeSegment.baseOffset)

    val compactionLagMs = math.max(log.config.compactionLagMs, 0L)

    //找出不可清理部分的第一条offset，其中active segment
      //再通过compactionLagMs过滤掉那些不能清理的segment
    val firstUncleanableDirtyOffset: Long = Seq (

        Option(log.activeSegment.baseOffset),
        if (compactionLagMs > 0) {
          dirtyNonActiveSegments.find {
            s =>
              val isUncleanable = s.largestTimestamp > now - compactionLagMs
              isUncleanable
          } map(_.baseOffset)
        } else None
      ).flatten.min

    (firstDirtyOffset, firstUncleanableDirtyOffset)
  }
```

注意以下几点：

1. 是否开启topic的日志清理机制和broker的log.cleanup.policy有关。这个配置的默认值是[delete]，也就是没有开启。但是并不是所有的partition log都会根据这个配置来判断是否开启日志清理。因为每个topic在创建的时候，也会指定是否开启日志清理（会覆盖broker的那个配置）。所以需要遍历所有的partiton，排除掉那些不用清理的partition。
2. dirtyRatio的计算规则为`dirtyRatio = dirtyBytes / (cleanBytes + dirtyBytes)`。其中dirtyBytes表示可清理部分的日志大小，cleanBytes表示已清理部分的日志大小。


