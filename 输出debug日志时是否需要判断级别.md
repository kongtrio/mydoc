最近在看一些代码时，发现经常在输出debug级别日志前做if判断，如下面的这段代码:

```java
if(LOGGER.isDebugEnabled()){
    LOGGER.debug("name {}",name);
}
```

目的应该是作者想尽量的提高性能，减少不必要的输出。但是个人觉的这些应该是日志框架应该处理好的，因此对这个做了一些简单的调研  

### 这样做的原因   

网上查了下，以前某些日志框架是不支持的"{}"占位符的，日志是这样输出的

```Java
LOGGER.debug("name "+ name);
```

也就是用拼接字符串的方式。这样在程序执行到`LOGGER.debug()`时进行字符串拼接，会带来很多无意义的性能损耗。因此，以前的程序都会在外面包一层if判断

```java
if(LOGGER.isDebugEnabled()){
    LOGGER.debug("name "+name);
}
```

由于运行过程中JIT会进行语句优化，发现`LOGGER.isDebugEnabled()`为false后，会将整个语句块去除掉。这样，就避免了日志级别大于debug时会进行无意义的字符串拼接了。

目前主流的一些日志框架都已经支持用占位符的形式输出日志，因此，if判断带来的性能优化效果并不会太大。

### 直接输出和加if判断的对比 

logback框架会在输出debug日志时进行一些判断做优化，避免无意义的输出。我们可以对比下两种方式的源码实现：

下面的logback关于`LOGGER.debug`的实现源码

```java
    //ch.qos.logback.classic.Logger类
	public void debug(Marker marker, String msg, Throwable t) {
        this.filterAndLog_0_Or3Plus(FQCN, marker, Level.DEBUG, msg, (Object[])null, t);
    }

    private void filterAndLog_0_Or3Plus(String localFQCN, Marker marker, Level level, String msg, Object[] params, Throwable t) {
        FilterReply decision = this.loggerContext.getTurboFilterChainDecision_0_3OrMore(marker, this, level, msg, params, t);
        
        if (decision == FilterReply.NEUTRAL) {
            //如果实际日志级别比所用的日志级别大，就直接return,不用输出了
            if (this.effectiveLevelInt > level.levelInt) {
                return;
            }
        } else if (decision == FilterReply.DENY) {
            return;
        }

        this.buildLoggingEventAndAppend(localFQCN, marker, level, msg, params, t);
    }

//LoggerContext.java
    final FilterReply getTurboFilterChainDecision_0_3OrMore(Marker marker, Logger logger, Level level, String format, Object[] params, Throwable t) {
        return this.turboFilterList.size() == 0 ? FilterReply.NEUTRAL : this.turboFilterList.getTurboFilterChainDecision(marker, logger, level, format, params, t);
    }
```

从代码可以看到，如果设置的日志级别是比DEBUG大的级别，那么在执行`LOGGER.debug()`时，几乎就走了2、3步就返回了，下面我们再看一下`LOGGER.isDebugEnabled()`的相关源码 

```java
public boolean isDebugEnabled() {
        return this.isDebugEnabled((Marker)null);
}
public boolean isDebugEnabled(Marker marker) {
        FilterReply decision = this.callTurboFilters(marker, Level.DEBUG);
        if (decision == FilterReply.NEUTRAL) {
            return this.effectiveLevelInt <= 10000;
        } else if (decision == FilterReply.DENY) {
            return false;
        } else if (decision == FilterReply.ACCEPT) {
            return true;
        } else {
            throw new IllegalStateException("Unknown FilterReply value: " + decision);
        }
}
//这里的getTurboFilterChainDecision_0_3OrMore和上面执行LOGGER.DEBUG()的一样
private FilterReply callTurboFilters(Marker marker, Level level) {
        return this.loggerContext.getTurboFilterChainDecision_0_3OrMore(marker, this, level, (String)null, (Object[])null, (Throwable)null);
}
```

所以，要判断`isDebugEnabled()`，做的逻辑其实和上面`LOGGER.debug()`做的差不多，底层都是调用`getTurboFilterChainDecision_0_3OrMore()`方法然后进行一些逻辑判断。

因此，从这个角度出发，完全没必要再输出debug日志前加一层if判断。

### 结论  

排除字符串拼接造成的性能损耗外（如果使用占用符就可以忽略这个损耗），个人觉的完全没必要在输出debug日志前加`if(LOGGER.isDebugEnabled())`。加了性能没得到提高，还增加了代码量，多此一举。

>  PS:在spring的源码中，输出日志前基本都会加一个if判断日志级别。不过这应该是spring输出日志都用字符串拼接而不是占位符的原因。

另外，本人的结论也不一定完全正确，欢迎有不一致意见的人在下方留言探讨。