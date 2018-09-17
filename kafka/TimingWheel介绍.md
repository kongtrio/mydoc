在kafka中，有许多请求并不是立即返回，而且处理完一些异步操作或者等待某些条件达成后才返回，这些请求一般都会带有timeout参数，表示如果timeout时间后服务端还不满足返回的条件，就判定此次请求为超时，这时候kafka同样要返回**超时的响应给客户端**，这样客户端才知道此次请求超时了。比如ack=-1的producer请求，就需要等待所有的isr备份完成了才可以返回给客户端，或者到达timeout时间了返回超时响应给客户端。

上面的场景，可以用延迟任务来实现。也就是定义一个任务，在timeout时间后执行，执行的内容一般就是先检查返回条件是否满足，满足的话就返回客户端需要的响应，如果还是不满足，就发送超时响应给客户端。

对于延迟操作，java自带的实现有Timer和ScheduledThreadPoolExecutor。这两个的底层数据结构都是基于一个延迟队列，在准备执行一个延迟任务时，将其插入到延迟队列中。这些延迟队列其实就是一个用最小堆实现的优先级队列，因此，插入一个任务的时间复杂度是O(logN),取出一个任务执行后调整堆的时间也是O(logN)。

如果要执行的延迟任务不多，O(logN)的速度已经够快了。但是对于kafka这样一个高吞吐量的系统来说，O(logN)的速度还不够，为了追求更快的速度，kafka的设计者使用了Timing Wheel的数据结构，让任务的插入时间复杂度达到了O(1)。

## Timing Wheel

![](http://on-img.com/chart_image/5b83e141e4b0fe81b618dd72.png?_=1535370055896)

上面是时间轮的一个结构图，该时间轮有8个槽，当前时间指向0号槽。

我们再看一下Kafka里面TimingWheel的数据结构

```scala
private[timer] class TimingWheel(tickMs: Long, wheelSize: Int, startMs: Long, taskCounter: AtomicInteger, queue: DelayQueue[TimerTaskList]) {

  private[this] val interval = tickMs * wheelSize
  private[this] val buckets = Array.tabulate[TimerTaskList](wheelSize) { _ => new TimerTaskList(taskCounter) }

  private[this] var currentTime = startMs - (startMs % tickMs) // rounding down to multiple of tickMs
}
```

**tickMs：**表示一个槽所代表的时间范围，kafka的默认值的1ms

**wheelSize：**表示该时间轮有多少个槽，kafka的默认值是20

**startMs：**表示该时间轮的开始时间

**taskCounter：**表示该时间轮的任务总数  

**queue：**是一个TimerTaskList的延迟队列。每个槽都有它一个对应的TimerTaskList，TimerTaskList是一个双向链表，有一个expireTime的值，这些TimerTaskList都被加到这个延迟队列中，expireTime最小的槽会排在队列的最前面。

**interval：**时间轮所能表示的时间跨度，也就是tickMs*wheelSize

**buckets：**表示TimerTaskList的数组，即各个槽。

**currentTime：**表示当前时间，也就是时间轮指针指向的时间

### 运行原理  

当新增一个延迟任务时，通过`buckets[expiration / tickMs % wheelSize]`先计算出它应该属于哪个槽。比如延迟任务的delayMs=2ms，当前时间currentTime是0ms，则expiration=delayMs+startMs=2ms，通过前面的公式算出它应该落于2号槽。并把任务封装成TimerTaskEntry然后加入到TimerTaskList链表中。

之后，kafka会启动一个线程，去推动时间轮的指针转动。其实现原理其实就是通过`queue.poll()`取出放在最前面的槽的TimerTaskList。由于queue是一个延迟队列，如果队列中的expireTime没有到达，该操作会阻塞住，直到expireTime到达。如果通过queue.poll()取到了TimerTaskList，说明该槽里面的任务时间都已经到达。这时候就可以遍历该TimerTaskList中的任务，然后执行对应的操作了。

针对上面的例子，就2号槽有任务，所以当取出2号槽的TimerTaskList后，会先将`currentTime = timeMs - (timeMs % tickMs)`，其中timeMs也就是该TimerTaskList的expireTime，也就是2Ms。所以，这时currentTime=2ms，也就是时间轮指针指向2Ms。

### 时间溢出处理  

在kafka的默认实现中，tickMs=1Ms，wheelSize=20，这就表示该时间轮所能表示的延迟时间范围是0~20Ms，那如果延迟时间超过20Ms要如何处理呢？Kafka对时间轮做了一层改进，使时间轮变成层级的时间轮。

一开始，第一层的时间轮所能表示时间范围是0~20Ms之间，假设现在出现一个任务的延迟时间是200Ms，那么kafka会再创建一层时间轮，我们称之为第二层时间轮。

第二层时间轮的创建代码如下

```scala
overflowWheel = new TimingWheel(
          tickMs = interval,
          wheelSize = wheelSize,
          startMs = currentTime,
          taskCounter = taskCounter,
          queue
)
```

也就是第二层时间轮每一个槽所能表示的时间是第一层时间轮所能表示的时间范围，也就是20Ms。槽的数量还是一样，其他的属性也是继承自第一层时间轮。这时第二层时间轮所能表示的时间范围就是0~400Ms了。

之后通过`buckets[expiration / tickMs % wheelSize]`算出延迟时间为200Ms的任务应该位于第二层时间轮的10号槽位。

同理，如果第二层时间轮的时间范围还容纳不了新的延迟任务，就会创建第三层、第四层...

值得注意的是，只有当前时间轮无法容纳目标延迟任务所能表示的时间时，才需要创建更高一级的时间轮，或者说把该任务加到更高一级的时间轮中(如果该时间轮已创建)。

### 一些细节  

1. 当时间轮的指针指向1号槽时，即currentTime=1Ms，说明0号槽的任务都已经到期了，这时0号槽就会被拿出来复用，可以容纳20~21Ms延迟时间的任务。也就是说，如果currentTime=0Ms时进来一个21Ms的延迟任务，就需要创建更高一级的时间轮，但是如果currentTime=1Ms时进来一个21Ms的延迟任务，就可以直接把它放到0号槽中，当currentTime=21时，指针又指向0号槽
2. 细心的同学可能发现，第一层的0号槽所能表示的任务延迟时间范围是0~1Ms，对应的TimerTaskList的expireTime是0Ms。第二层的0号槽锁能表示的任务延迟时间范围是0~20Ms，对应的TimerTaskList的expireTime也是0Ms。他们的TimerTaskList又都是放在一个延迟队列中。这时候执行`queue.poll()`会把这两个TimerTaskList都取出来，然后遍历链表的时候还会判断该任务是否达到执行时间了，如果没有的话，这些任务还会被塞回时间轮中。这时由于第一层指针的转动，原先处于第二层时间轮中的任务可能会重新落到第一层时间轮上面。

## 源码解析

**添加新的延迟任务**

```scala
//SystemTimer.scala  
private def addTimerTaskEntry(timerTaskEntry: TimerTaskEntry): Unit = {
    if (!timingWheel.add(timerTaskEntry)) {
      // Already expired or cancelled
      if (!timerTaskEntry.cancelled)
        taskExecutor.submit(timerTaskEntry.timerTask)
    }
  }
```

**往时间轮添加新的任务** 

```scala
//TimingWheel
def add(timerTaskEntry: TimerTaskEntry): Boolean = {
    //获取任务的延迟时间
    val expiration = timerTaskEntry.expirationMs
    //先判断任务是否已经完成
    if (timerTaskEntry.cancelled) {
      false
      //如果任务已经到期
    } else if (expiration < currentTime + tickMs) {
      false
      //判断当前时间轮所能表示的时间范围是否可以容纳该任务
    } else if (expiration < currentTime + interval) {
      // 根据任务的延迟时间算出应该位于哪个槽
      val virtualId = expiration / tickMs
      val bucket = buckets((virtualId % wheelSize.toLong).toInt)
      bucket.add(timerTaskEntry)

      // 设置TimerTaskList的expireTime
      if (bucket.setExpiration(virtualId * tickMs)) {
        //把TimerTaskList加入到延迟队列
        queue.offer(bucket)
      }
      true
    } else {
      //如果时间超出当前所能表示的最大范围，则创建新的时间轮,并把任务添加到那个时间轮上面
      if (overflowWheel == null) addOverflowWheel()
      overflowWheel.add(timerTaskEntry)
    }
  }
  private[this] def addOverflowWheel(): Unit = {
    synchronized {
      if (overflowWheel == null) {
        overflowWheel = new TimingWheel(
          tickMs = interval,
          wheelSize = wheelSize,
          startMs = currentTime,
          taskCounter = taskCounter,
          queue
        )
      }
    }
  }
```

从上面的代码可以看出，对于当前时间轮是否可以容纳目标任务，是通过`expiration < currentTime + interval`来计算的，也就是根据时间轮的指针往后推interval时间就是时间轮所能表示的时间范围。

**时间轮指针的推进** 

```scala
 //SystemTimer.scala 
def advanceClock(timeoutMs: Long): Boolean = {
      //从延迟队列中取出最近的一个槽，如果槽的expireTime没到，此操作会阻塞timeoutMs
    var bucket = delayQueue.poll(timeoutMs, TimeUnit.MILLISECONDS)
    if (bucket != null) {
      writeLock.lock()
      try {
        while (bucket != null) {
            //推进时间轮的指针
          timingWheel.advanceClock(bucket.getExpiration())
            //把TimerTaskList的任务都取出来重新add一遍，add的时候会检查任务是否已经到期
          bucket.flush(reinsert)
          bucket = delayQueue.poll()
        }
      } finally {
        writeLock.unlock()
      }
      true
    } else {
      false
    }
  }
//TimingWheel
def advanceClock(timeMs: Long): Unit = {
    if (timeMs >= currentTime + tickMs) {
        //推进时间轮的指针
      currentTime = timeMs - (timeMs % tickMs)

      // 推进上层时间轮的指针
      if (overflowWheel != null) overflowWheel.advanceClock(currentTime)
    }
  }
```

## 总结  

相比于常用的DelayQueue的时间复杂度O(logN)，TimingWheel的数据结构在插入任务时只要O(1),获取到达任务的时间复杂度也远低于O(logN)。另外，kafka的TimingWheel在插入任务之前还会先检查任务是否完成，对于那些在任务超时直接就完成指定操作的场景，TimingWheel的表现更加优秀。