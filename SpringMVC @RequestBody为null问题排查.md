今天写一个springmvc接口，希望入参为json，然后自动转成自己定义的封装对象 ,于是有了下面的代码  

```java
@PostMapping("/update")
@ApiOperation("更新用户信息")
public CumResponseBody update(@RequestBody UserInfoParam param) {
     int userId = getUserId();
     userService.updateUserInfo(userId, param);
     return ResponseFactory.createSuccessResponse("ok");
}

//UserInfoParam.java
public class UserInfoParam {
    private String tel;
    private String email;

    public String getTel() {
        return tel;
    }

    public void setTel(String tel) {
        this.tel = tel;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }
}
```

程序正常启动后，使用swaggerUI发起测试

```shell
curl -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -d '{ \ 
   "email": "12%40mail.com", \ 
   "tel": "13677682911" \ 
 }' 'http://127.0.0.1:9998/api/user/update'
```

最后程序报错 

```
org.springframework.http.converter.HttpMessageNotReadableException: Required request body is missing: public com.pingguiyuan.shop.common.response.CumResponseBody com.pingguiyuan.shop.weixinapi.controller.UserController.update(com.pingguiyuan.shop.common.param.weixin.UserInfoParam)
```

对了几遍，接口的编写和请求内容都确定没有问题，但是请求的json就是没注入进来转成param对象。查了一圈资料也没找到满意的答案，就只能给springMVC的源码打断点跟一遍，看一下具体是哪里出了问题。

由于本篇不是介绍springMVC实现原理的，就不具体介绍springMVC的源码。

最后断点发现springMVC从request的inputstream没取出内容来(`inputstream.read()出来的直接是-1`)。由于有在一个拦截器输出请求的参数内容—>【当请求时get时，通过`request.getParameterMap();`获取参数，当请求时post时，则是直接输出request的inpustream里面的内容】。所以请求的body里面是肯定有内容的,也就是说request.getInputstream()的流是有内容的，那为什么到springMVC这read出来的就是-1呢。

稍微理了下思路，发现是自己给自己挖了个坑。答案是：`request的inputstream只能读一次，博主在拦截器中把inputstream的内容都输出来了，到springMVC这，就没有内容可以读了。`

### 关于inputsteam的一些理解  

servlet request的inpustream是面向流的，这意味着读取该inputstream时是一个字节一个字节读的，直到整个流的字节全部读回来，这期间没有对这些数据做任何缓存。因此，整个流一旦被读完，是无法再继续读的。

这和nio的处理方式就完全不同，如果是nio的话，数据是先被读取到一块缓存中，然后程序去读取这块缓存的内容，这时候就允许程序重复读取缓存的内容，比如`mark()然后reset()`或者直接`clear()`重新读。

特意去看了下InputStream的源码，发现其实是有mark()和reset()方法的，但是默认的实现表示这是不能用的，源码如下 

```Java
public boolean markSupported() {
    return false;
}
public synchronized void reset() throws IOException {
        throw new IOException("mark/reset not supported");
}
public synchronized void mark(int readlimit) {}
```

其中mark是一个空函数，reset函数直接抛出异常。同时，inputstream还提供了`markSupported()`方法，默认是返回false，表示不支持mark，也就是标记（用于重新读）。

但是并不是所有的Inputstream实现都不允许重复读，比如`BufferedInputStream`就是允许重复读的，从类名来看，就知道这个类其实就是将读出来的数据进行缓存，来达到可以重复读的效果。下面是BufferedInputStream重写的3个方法

```java
	public synchronized void mark(int readlimit) {
        marklimit = readlimit;
        markpos = pos;
    }


    public synchronized void reset() throws IOException {
        getBufIfOpen(); // Cause exception if closed
        if (markpos < 0)
            throw new IOException("Resetting to invalid mark");
        pos = markpos;
    }


    public boolean markSupported() {
        return true;
    }
```

可以看到BufferedInputStream的markSupported()方法返回的是true，说明它应该是支持重复读的。我们可以通过mark()和reset()来实现重复读的效果。

### @RequestBody 自动映射原理的简单介绍  

springMVC在处理请求时，先找到对应controller处理该请求的方法，然后遍历整个方法的所有参数，进行封装。在处理参数的过程中，会调用`AbstractMessageConverterMethodArgumentResolver#readWithMessageConverters()`类的方法进行进行一些转换操作，源码如下  

```java
protected <T> Object readWithMessageConverters(HttpInputMessage inputMessage, MethodParameter parameter,
			Type targetType) throws IOException, HttpMediaTypeNotSupportedException, HttpMessageNotReadableException {

		MediaType contentType;
		boolean noContentType = false;
		try {
			contentType = inputMessage.getHeaders().getContentType();
		}
		catch (InvalidMediaTypeException ex) {
			throw new HttpMediaTypeNotSupportedException(ex.getMessage());
		}
		if (contentType == null) {
			noContentType = true;
			contentType = MediaType.APPLICATION_OCTET_STREAM;
		}

		Class<?> contextClass = parameter.getContainingClass();
		Class<T> targetClass = (targetType instanceof Class ? (Class<T>) targetType : null);
		if (targetClass == null) {
			ResolvableType resolvableType = ResolvableType.forMethodParameter(parameter);
			targetClass = (Class<T>) resolvableType.resolve();
		}

		HttpMethod httpMethod = (inputMessage instanceof HttpRequest ? ((HttpRequest) inputMessage).getMethod() : null);
		Object body = NO_VALUE;

		EmptyBodyCheckingHttpInputMessage message;
		try {
			message = new EmptyBodyCheckingHttpInputMessage(inputMessage);

			for (HttpMessageConverter<?> converter : this.messageConverters) {
				Class<HttpMessageConverter<?>> converterType = (Class<HttpMessageConverter<?>>) converter.getClass();
				GenericHttpMessageConverter<?> genericConverter =
						(converter instanceof GenericHttpMessageConverter ? (GenericHttpMessageConverter<?>) converter : null);
				if (genericConverter != null ? genericConverter.canRead(targetType, contextClass, contentType) :
						(targetClass != null && converter.canRead(targetClass, contentType))) {
					if (logger.isDebugEnabled()) {
						logger.debug("Read [" + targetType + "] as \"" + contentType + "\" with [" + converter + "]");
					}
					if (message.hasBody()) {
						HttpInputMessage msgToUse =
								getAdvice().beforeBodyRead(message, parameter, targetType, converterType);
						body = (genericConverter != null ? genericConverter.read(targetType, contextClass, msgToUse) :
								((HttpMessageConverter<T>) converter).read(targetClass, msgToUse));
						body = getAdvice().afterBodyRead(body, msgToUse, parameter, targetType, converterType);
					}
					else {
						body = getAdvice().handleEmptyBody(null, message, parameter, targetType, converterType);
					}
					break;
				}
			}
		}
		catch (IOException ex) {
			throw new HttpMessageNotReadableException("I/O error while reading input message", ex);
		}

		if (body == NO_VALUE) {
			if (httpMethod == null || !SUPPORTED_METHODS.contains(httpMethod) ||
					(noContentType && !message.hasBody())) {
				return null;
			}
			throw new HttpMediaTypeNotSupportedException(contentType, this.allSupportedMediaTypes);
		}

		return body;
	}
```

上面这段代码主要做的事情大概就是获取请求的contentType，然后遍历配置的HttpMessageConverter—>`this.messageConverters`，如果该HttpMessageConverter可以用于解析这种contentType(genericConverter.canRead方法)，就用这种HttpMessageConverter解析请求的请求体内容，最后返回具体的对象。

在spring5.0.7版本中，`messageConverters`默认似乎配置了8种convert。分别是  

1. ByteArrayMessageConverter   
2. StringHttpMessageConverter   
3. ResourceHttpMessageConverter
4. ResourceRegionHttpMessageConverter
5. SourceHttpMessageConverter
6. AllEncompassingFormHttpMessageConverter
7. MappingJackson2HttpMessageConverter
8. Jaxb2RootElementHttpMessageConverter

具体的convert是哪些contentType并怎么解析的，这里不多做介绍，感兴趣的朋友可以自行查看源码。

比如我们请求的header中的contentType是`application/json`，那么在遍历messageConverters的时候，其他`genericConverter.canRead()`都会返回false，说明没有适配上。然后遍历到MappingJackson2HttpMessageConverter时`genericConverter.canRead()`返回true，接着就去获取请求的请求体，并通过json解析成我们@RequestBody定义的对象。

因此，如果我们的请求的contentType和数据协议都是自定义的，我们完全可以自己实现一个`HttpMessageConverter`，然后解析特定的contentType。最后记得将这个实现放入`messageConverters`中，这样springMVC就会自动帮我们把请求内容解析成对象了。