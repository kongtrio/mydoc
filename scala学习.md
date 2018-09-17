## 基础语法  
`scala中，行的最后可以不用';' ，加不加都可以`
#### 定义包比较灵活  
一种是和java一样在文件头部定义包
```scala
package com.runoob
class HelloWorld
```
一种是类似C#的方式
```scala
package com.runoob {
  class HelloWorld 
}
```
使用这种方式可以在一个文件内定义多个包  

#### 引用
和java一样用import导入包。
```scala
import java.awt.Color  // 引入Color
import java.awt._  // 引入包内所有成员
def handler(evt: event.ActionEvent) { // java.awt.event.ActionEvent
  ...  // 因为引入了java.awt，所以可以省去前面的部分
}
```
import语句可以出现在任何地方，而不是只能在文件顶部。import的效果从开始延伸到语句块的结束。这可以大幅减少名称冲突的可能性。
如果想要引入包中的几个成员，可以使用selector（选取器）：
```scala
import java.awt.{Color, Font}
// 重命名成员
import java.util.{HashMap => JavaHashMap}
// 隐藏成员
import java.util.{HashMap => _, _} // 引入了util包的所有成员，但是HashMap被隐藏了
import java.util.{List => _, Map => _, Set => _, _} //隐藏多个成员
```

## 数据类型&变量  

#### 多出来的类型   

scala相比java，多出来的一些数据类型

| 数据类型 | 描述 |
| ------- | ------------------------------------------------------------ |
| Unit    | 表示无值，和其他语言中void等同。用作不返回任何结果的方法的结果类型。Unit只有一个实例值，写成()。 |
| Null    | null 或空引用                                                |
| Nothing | Nothing类型在Scala的类层级的最低端；它是任何其他类型的子类型。 |
| Any     | Any是所有其他类的超类                                        |
| AnyRef  | AnyRef类是Scala里所有引用类(reference class)的基类           |

在Scala中，是没有基本类型的，也就是说，可以对数字等基础类型调用方法。

#### 多行字符串的表示方法 

多行字符串用三个双引号来表示分隔符，格式为：""" ... """

```scala
val foo = """菜鸟教程
www.runoob.com
www.w3cschool.cc
www.runnoob.com
以上三个地址都能访问"""
```

#### 变量和常量的声明

变量声明用`var`，常量声明用`val`。常量的作用和java的final类似

可以同时声明几个变量

```scala
val xmax, ymax = 100,200  // xmax声明为100, ymax声明为200
val xmax, ymax = 100  // xmax, ymax都声明为100
```

#### 访问修饰符  

scala中访问修饰符只有public、protected、private。默认都为public。

在 scala 中，对Protected成员的访问比 java 更严格一些。因为它只允许保护成员在定义了该成员的的类的子类中被访问。而在java中，用protected关键字修饰的成员，除了定义了该成员的类的子类可以访问，同一个包里的其他类也可以进行访问。

有意思的是，在scala中，访问修饰符可以通过使用限定词强调，格式为

```scala
private[x] 
或 
protected[x]
```

也就是说，如果你有个类，只想被某个包底下的成员使用，那么可以这么做

```scala
package kongtrio {
  package test1 {

    private[kongtrio] class ScalaTest {
      val name = "hei"
    }

  }

  package test2 {

    import kongtrio.test1.ScalaTest

    object Test {
      def main(args: Array[String]): Unit = {
        val test = new ScalaTest
        print(test.name)
      }
    }

  }

}
```

上面的代码中，ScalaTest和Test在两个不同的包中，并ScalaTest还是private的。但是使用了限定词强调，因此只要是`kongtrio`包下面的类就都可以看见ScalaTest类，其他包下的类就看不到ScalaTest类了。

## 函数和方法  

Scala 方法是类的一部分，而函数是一个对象可以赋值给一个变量。换句话来说在类中定义的函数即是方法。

Scala 中的函数则是一个完整的对象，Scala 中的函数其实就是继承了 Trait 的类的对象。

Scala 中使用 **val** 语句可以定义函数，**def** 语句定义方法。在scala中，可以在方法中定义函数，**也可以在函数中定义函数**。函数可作为一个参数传入到方法中，而方法不行。

#### 方法声明

```scala
def functionName ([参数列表]) : [return type]
//无入参、无返回值的函数。:Unit和'='可以去掉，可写可不写。下面的例子有的有写，有的没写
def test(){
    
}
//例子.传入两个参数，args表示一个可变参数，String后面的'*'表示这参数是可变的，类似java的'...'
//返回一个String类型的返回值。如果无返回值，就用Unit表示或者不写
def test(age:Int,args:String*):String = {
    //在scala中，可以不用写return
    "hello world"
}

//可以设置默认值的函数
def test2(a:Int,b:Int,c:Int=3){}
//如果指定了参数名，那么a和b的传入顺序可以乱掉
test(b=2,a=1)

//传名调用函数
def time(): Long = {
    println("time 方法内")
    System.currentTimeMillis()
}
//time参数后面加个'=>'传名调用，这时调用'test(time())'方法时,会等真正使用到time()时才调用time()方法
//最后输出
//test 方法内
//time 方法内
//time = 1533291592954
def test(time: => Long) = {
    println("test 方法内")
    println("time = " + time)
}

//匿名函数
//匿名函数的语法很简单，箭头左边是参数列表，右边是函数体。
var inc = (x:Int) => x+1

//偏应用函数
//你不需要提供函数需要的所有参数，只需要提供部分，或不提供所需参数
def test(a: Int, b: String) = {
    println("a=" + a + " b  = " + b)
}
//固定第一个参数为1，然后构造一个'新的函数'
val f = test(1, _: String)
f("hello")

//方法内定义函数 
def test() = {
    def f(a: Int) = {
      
    }
}

//高阶函数
//高阶函数可以使用其他函数作为参数，或者使用函数作为输出结果
def test() = {
    def f(age: Int) = {
      println(age)
      "hello"
    }
    val str = myMethed(f, 2)
    println(str(2))
}
//myMethed第一个入参是一个函数，这个函数的入参是Int，返回值是String，所以用Int=>String表示
//myMethed返回值也是一个函数,Int => String表示返回的函数入参是Int，返回值是String
def myMethed(a: Int => String, b: Int): Int => String = {
    a(b)
    def hei(hei: Int): String = {
      "world" + hei
    }
    hei
}

//函数柯里化。上面是正常的函数，下面是将函数柯里化
def add(x:Int,y:Int)=x+y
def add(x:Int)(y:Int) = x + y
//实现原理大概就是这样，js里面也可以这么做
def add(x:Int)=(y:Int)=>x+y
```

方法如果不写等于号和方法主体，那么方法会被隐式声明为**抽象(abstract)**，包含它的类型于是也是一个抽象类型。

#### 闭包 

```scala
var factor = 3  
//在一个函数内部使用其他函数的变量factor，说明这个函数是一个闭包
val multiplier = (i:Int) => i * factor  
```

## 数组  

```scala
//一维数组
var z = new Array[String](3)
//定义二维数组
var myMatrix =Array.ofDim[String](3,4)
// 输出所有数组元素
for ( x <- myList ) {
    println( x )
}
for (i <- 0 to x.length - 1) {
      println(x(i))
}
//也可以这么输出
for (i <- x.indices) {
      println(x(i))
}
//创建区间数组
//获取10、12、14、16、18
var myList1 = Array.range(10, 20, 2)
//获取11、12、13、14、15、16、17、18、19
var myList2 = Array.range(10,20)
```

## 集合 

Scala 集合分为可变的和不可变的集合。不可变的集合仍然可以模拟添加，移除或更新操作。但是这些操作将在每一种情况下都返回一个新的集合，同时使原来的集合不发生改变。

#### List  

列表是不可变的，值一旦被定义了就不能改变。

```scala
val site: List[String] = List("Runoob", "Google", "Baidu")
// 空列表
val empty: List[Nothing] = List()
//构造列表的两个基本单位是 Nil 和 ::
var list = "hello" :: Nil
```

**连接两个列表**  

```scala
def test() {
    var list = "hello" :: Nil
    var list2 = "world" :: Nil
    //用':::'连接两个list,输出List(hello, world)
    //效果和list.concat(list2)一样。也可以用list++list2
    println(list ::: list2)
    //用'.:::'连接两个list,输出 List(world, hello)
    println(list.:::(list2))
}
```

**通过一些自带的函数创建列表** 

```scala
//List.fill填充
//重复 Runoob 3次
val site = List.fill(3)("Runoob")

//List.tabulate()  通过给定的函数来创建列表 
//创建5个元素，会执行5次传入的函数，入参从0开始到4
val ints = List.tabulate(5)(n => "hello" + n)
```

**添加元素**

```scala
val nums = List(1)
//在列表头部添加元素
val ints = 2 +: nums
val ints = nums.+:(2)
val ints = nums.::(2)
//在列表后添加元素
val ints = nums :+ 2
val ints2 = nums.:+(2)
```

**可变的List在scala里面叫`ListBuffer`**

```scala
val mylist = ListBuffer(1)
//可以直接对列表进行增删操作
mylist += 2
mylist += 5
mylist -= 2
```

#### Set  

Scala 集合分为可变的和不可变的集合。

默认情况下，Scala 使用的是不可变集合，如果你想使用可变集合，需要引用 **scala.collection.mutable.Set** 包。默认引用 scala.collection.immutable.Set。

```scala
val set = Set(1,2,3)
println(set.exists(_ % 2 == 0)) //true
println(set.drop(1)) //Set(2,3)
```

**可变集合的增删改查** 

```scala
import scala.collection.mutable.Set
val mutableSet = Set(1,2,3)
mutableSet.add(4)
mutableSet.remove(1)
mutableSet += 5
mutableSet -= 2
```

连接两个集合等操作和List差不多。

**下面介绍一些比较好玩的函数**

```scala
val set1 = Set(1, 2)
val set2 = Set(2, 3)
//求交集
val set3 = set1 & set2
//求并集
val set4 = set1 | set2
//下面两个都是求差集
val set5 = set1 &~ set2
val set6 = set1 -- set2
```

#### Map

Map 有两种类型，可变与不可变，区别在于可变对象可以修改它，而不可变对象不可以。

默认情况下 Scala 使用不可变 Map。如果你需要使用可变集合，你需要显式的引入 **import scala.collection.mutable.Map** 类

```scala
// Map 键值对演示
val colors = Map("red" -> "#FF0000", "azure" -> "#F0FFFF")
```

**可变Map**

```scala
val colors = Map("red" -> "#FF0000", "azure" -> "#F0FFFF")
colors += "yellow" -> "#888888"
colors.put("green", "hei")
```

**合并两个Map**

```scala
val map1 = Map("red" -> "1")
val map2 = Map("red" -> "2")
//最后结果是red->2。因为map2放后面，key相同时，后面的会覆盖前面的
val map3 = map1 ++ map2
```

#### 元组 

与列表一样，元组也是不可变的，但与列表不同的是元组可以包含不同类型的元素。

```scala
val t = (4,3,2,1)
//访问元组的值
val sum = t._1 + t._2 + t._3 + t._4
//迭代元组
t.productIterator.foreach{ i =>println("Value = " + i )}
```

#### Option

从map中的get返回的值是**Option**类

```scala
val myMap: Map[String, String] = Map("key1" -> "value")
val value1: Option[String] = myMap.get("key1")
val value2: Option[String] = myMap.get("key2")
 
println(value1) // Some("value1")
println(value2) // None
```

#### 迭代器  

Scala Iterator（迭代器）不是一个集合，它是一种用于访问集合的方法。

```scala
val it = Iterator("Baidu", "Google", "Runoob", "Taobao")  
while (it.hasNext){
    println(it.next())
}
```

## Scala类和对象  

scala的一个文件里面可以定义多个类。这些类默认就是public的，在java中一个文件内最多只能有一个public的类。

```scala
class Point(xc: Int, yc: Int) {
   var x: Int = xc
   var y: Int = yc

   def move(dx: Int, dy: Int) {
      x = x + dx
      y = y + dy
      println ("x 的坐标点: " + x);
      println ("y 的坐标点: " + y);
   }
}
```

scala的继承也是单继承，要重写父类的某个方法时，必须在方法前面加上override关键字。但是在重写父类的抽象方法时就不需要加override关键字。

```scala
class Location(override val xc: Int, override val yc: Int,
   val zc :Int) extends Point(xc, yc){
   var z: Int = zc
	
   def move(dx: Int, dy: Int, dz: Int) {
      x = x + dx
      y = y + dy
      z = z + dz
      println ("x 的坐标点 : " + x);
      println ("y 的坐标点 : " + y);
      println ("z 的坐标点 : " + z);
   }
   //重写的话需要加override关键字
   override def move(dx: Int, dy: Int){}
}
```

#### scala单例对象  

在 Scala 中，是没有 static 这个东西的，但是它也为我们提供了单例模式的实现方法，那就是使用关键字 object。单例对象中的所有方法都可以看成是static方法。

单例对象不能带参数，单例对象可以与某个类共享同一个名称，这样单例对象就被称作是这个类的伴生对象，而这个类是这个单例对象的伴生类，另外，他们必须要定义在同一个文件中。

```scala
//定义单例对象,注意，单例对象不能带有参数
object Test {
   def main(args: Array[String]) {
      print("hello world")
   }
}
```

## Scala的接口 

在scala中，用trait关键字表示接口，scala的接口可以定义属性和方法的实现。

```scala
trait Equal {
  def isEqual(x: Any): Boolean
  def isNotEqual(x: Any): Boolean = !isEqual(x)
}
class Point(xc: Int, yc: Int) extends Equal {
  var x: Int = xc
  var y: Int = yc
  def isEqual(obj: Any) =
    obj.isInstanceOf[Point] &&
    obj.asInstanceOf[Point].x == x
}
```

## Scala的模式匹配  

scala的模式匹配其实就是java的switch，但是比起java更加灵活。

```scala
def matchTest(x: Any): Any = x match {
      case 1 => "one"
      case "two" => 2
      //如果传入的是Int类，就输出"scala.Int"
      case y: Int => "scala.Int"
      //‘_’ 表示匹配全部
      case _ => "many"
}
```

## Scala的异常处理  

scala的异常处理和java差不多

```scala
object Test {
   def main(args: Array[String]) {
      try {
         val f = new FileReader("input.txt")
      } catch {
         case ex: FileNotFoundException =>{
            println("Missing file exception")
         }
         case ex: IOException => {
            println("IO Exception")
         }
      }
   }
}
```

## scala的两个web应用框架:
1. Lift
2. Play


