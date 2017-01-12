
## Guaua学习  

<http://www.open-open.com/lib/view/open1422415598501.html>  

### 1. 基本工具  

1.1 使用和避免null

	使用Option类。优雅的处理null。

1.2 使用前置条件  

	使用Preconditions类,让方法中的条件检查更简单  

1.3 常见Object方法  

	使用`Objects.equal(a,b)`、`Objects.hashcode()`、`Objects.toString()`方法等。

	`ComparisonChain.start().compare(this.x,that.x)`来比较。  

1.4 排序:Guaua强大的"链式风格比较器"  

	Ordering类。强大!

1.5 Throwables : 简化异常和错误的传播与检查  

	

	
