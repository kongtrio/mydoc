[TOC]

## Java Reflection    

### 泛型擦除  

​	泛型在运行期是会被擦除掉的,所以在运行期我们无法获取到泛型的参数信息。但是我们可以通过有用到该泛型类的方法或者变量来获取到该泛型类的参数化信息。  比如:  

```java
public class ParamMethod {
    private List<String> param;

    public List<String> getParam() {
        return this.param;
    }
}
```

```java
public static void main(String[] args) throws Exception {
    Method method = ParamMethod.class.getMethod("getParam");
    Type genericReturnType = method.getGenericReturnType();
    if (genericReturnType instanceof ParameterizedType) {
        ParameterizedType aType = (ParameterizedType) genericReturnType;
        Type[] parameterArgTypes = aType.getActualTypeArguments();
        for (Type parameterArgType : parameterArgTypes) {
            Class parameterArgClass = (Class) parameterArgType;
            System.out.println("parameterArgClass = " + parameterArgClass);
        }
    }

}
```

### 动态代理   

<http://ifeve.com/java-reflection-11-dynamic-proxies/>

​	利用Java的反射机制可以实现运行期动态的创建接口的实现。动态代理的几个用途:

1. 数据库连接以及事物管理  
2. 单元测试中的动态Mock对象  
3. 自定义工厂与依赖注入（DI）容器之间的适配器  
4. **类似AOP的方法拦截器**    