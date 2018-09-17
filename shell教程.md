本篇博客只是记录shell的一些关键语法，主要是做一个记录，有些内容也是copy过来的，并不是一个完整的教程，想完整学习shell的同学可以前往[菜鸟笔记shell教程](http://www.runoob.com/linux/linux-shell.html)学习。

## shell脚本解释器  

- Bourne Shell（/usr/bin/sh或/bin/sh）
- Bourne Again Shell（/bin/bash）
- C Shell（/usr/bin/csh）
- K Shell（/usr/bin/ksh）
- Shell for Root（/sbin/sh）
- ...

一般我们关注的是 Bash，也就是 Bourne Again Shell，由于易用和免费，Bash 在日常工作中被广泛使用。同时，Bash 也是大多数Linux 系统默认的 Shell。

在一般情况下，人们并不区分 Bourne Shell 和 Bourne Again Shell，所以，像 **#!/bin/sh**，它同样也可以改为 **#!/bin/bash**。

\#! 告诉系统其后路径所指定的程序即是解释此脚本文件的 Shell 程序。

## 定义变量   

```shell
#!/bin/bash
# 注意等于号两边不能有空格
myUrl="http://www.google.com"
# 设置变量成只读变量
readonly myUrl
# 变量被设置为只读变量后就不能修改，否则会报错
myUrl="http://www.runoob.com"
# 删除变量
unset myUrl
```

## 字符串  

Shell字符串的定义可以用`''`或者`""`，甚至可以不加单引号和双引号。

单引号字符串的限制：

- 单引号里的任何字符都会原样输出，单引号字符串中的变量是无效的；
- 单引号字串中不能出现单独一个的单引号（对单引号使用转义符后也不行），但可成对出现，作为字符串拼接使用。

双引号字符串的限制：

- 双引号里可以有变量
- 双引号里可以出现转义字符

**字符串的一些操作**

```shell
# 获取字符串长度
string="abcd"
echo ${#string} #输出 4
# 截取字符串
string="runoob is a great site"
echo ${string:1:4} # 输出 unoo
# 查找字符 i 或 o 的位置(哪个字母先出现就计算哪个)
string="runoob is a great site"
echo `expr index "$string" io`  # 输出 4
```

## 数组  

Shell支持一维数组（不支持多维数组），并且没有限定数组的大小，下标从0开始。

```shell
# 定义一个数组
array_test=(1,2,3)
# 可以直接设定任意下标的值，下标的范围没有限制
array_test[5]=6
array_test[9]=10
# 读取数组的值 ，n表示具体的下标
valuen=${array_name[n]}
# 输出数组的所有元素
echo ${array_name[@]}
# 获取数组的长度 
length=${#array_name[@]}
```

## 参数  

我们执行shell的时候，可以向shell脚本传参数，在shell脚本内可以通过`$n`获取这些参数，比如第一个参数通过`$1`获取，第二个参数通过`$2`。通过`$0`可以获取执行的文件名。

```shell
echo "Shell 传递参数实例！";
echo "执行的文件名：$0";
echo "第一个参数为：$1";
echo "第二个参数为：$2";
echo "第三个参数为：$3";
```

执行`test.sh`时传入参数

```shell
# 如果没传第3个参数，$3获取到的就是一个空值，也不会报错
$ ./test.sh 1 2
```

下面是几个特殊的字符处理

| 参数处理 | 说明                                                         |
| -------- | ------------------------------------------------------------ |
| $#       | 传递到脚本的参数个数                                         |
| $*       | 以一个单字符串显示所有向脚本传递的参数。如"`$*`"用「"」括起来的情况、以"`$1` `$2` … `$n`"的形式输出所有参数。 |
| $$       | 脚本运行的当前进程ID号                                       |
| $!       | 后台运行的最后一个进程的ID号                                 |
| $@       | 与`$*`相同，但是使用时加引号，并在引号中返回每个参数。如"`$@`"用「"」括起来的情况、以"`$1`" "`$2`" … "`$n`" 的形式输出所有参数。 |
| $-       | 显示Shell使用的当前选项，与[set命令](http://www.runoob.com/linux/linux-comm-set.html)功能相同。 |
| $?       | 显示最后命令的退出状态。0表示没有错误，其他任何值表明有错误。 |

`$*` 与 `$@` 区别：

- 相同点：都是引用所有参数。
- 不同点：只有在双引号中体现出来。假设在脚本运行时写了三个参数 1、2、3，，则 " * " 等价于 "1 2 3"（传递了一个参数），而 "@" 等价于 "1" "2" "3"（传递了三个参数）。

## 表达式和运算符

原生bash不支持简单的数学运算，但是可以通过其他命令来实现，例如 awk 和 expr，expr 最常用。

expr 是一款表达式计算工具，使用它能完成表达式的求值操作。

```shell
#!/bin/bash

val=`expr 2 + 2`
echo "两数之和为 : $val"
```

### 1.关系运算符  

关系运算符只支持数字，不支持字符串，除非字符串的值是数字。

下表列出了常用的关系运算符

| 运算符 | 说明                                                  |
| ------ | ----------------------------------------------------- |
| -eq    | 检测两个数是否相等，相等返回 true。                   |
| -ne    | 检测两个数是否不相等，不相等返回 true。               |
| -gt    | 检测左边的数是否大于右边的，如果是，则返回 true。     |
| -lt    | 检测左边的数是否小于右边的，如果是，则返回 true。     |
| -ge    | 检测左边的数是否大于等于右边的，如果是，则返回 true。 |
| -le    | 检测左边的数是否小于等于右边的，如果是，则返回 true。 |

例子：
```shell
a=10
b=20
if [ $a -eq $b ]
then
   echo "$a -eq $b : a 等于 b"
else
   echo "$a -eq $b: a 不等于 b"
fi
```

### 2. 布尔运算符

下表列出了常用的布尔运算符

| 运算符 | 说明                                                |
| ------ | --------------------------------------------------- |
| !      | 非运算，表达式为 true 则返回 false，否则返回 true。 | [ ! false ] 返回 true。                 |
| -o     | 或运算，有一个表达式为 true 则返回 true。           |
| -a     | 与运算，两个表达式都为 true 才返回 true。           |

例子：

```shell
a=10
b=20
if [ $a -lt 100 -a $b -gt 15 ]
then
   echo "$a 小于 100 且 $b 大于 15 : 返回 true"
else
   echo "$a 小于 100 且 $b 大于 15 : 返回 false"
fi
```

### 3. 逻辑运算符

| 运算符 | 说明       |
| ------ | ---------- |
| &&     | 逻辑的 AND |
| \|\|   | 逻辑的 OR  |

### 4. 字符串运算符

| 运算符 | 说明                                      |
| ------ | ----------------------------------------- |
| =      | 检测两个字符串是否相等，相等返回 true。   |
| !=     | 检测两个字符串是否相等，不相等返回 true。 |
| -z     | 检测字符串长度是否为0，为0返回 true。     |
| -n     | 检测字符串长度是否为0，不为0返回 true。   |
| str    | 检测字符串是否为空，不为空返回 true。     |

例子：

```shell
a="abc"
b="efg"
if [ -n "$a" ]
then
   echo "-n $a : 字符串长度不为 0"
else
   echo "-n $a : 字符串长度为 0"
fi
if [ $a ]
then
   echo "$a : 字符串不为空"
else
   echo "$a : 字符串为空"
fi
```

### 5. 文件测试运算符

文件测试运算符用于检测 Unix 文件的各种属性

| 操作符  | 说明                                                         | 举例                      |
| ------- | ------------------------------------------------------------ | ------------------------- |
| -b file | 检测文件是否是块设备文件，如果是，则返回 true。              | [ -b $file ] 返回 false。 |
| -c file | 检测文件是否是字符设备文件，如果是，则返回 true。            | [ -c $file ] 返回 false。 |
| -d file | 检测文件是否是目录，如果是，则返回 true。                    | [ -d $file ] 返回 false。 |
| -f file | 检测文件是否是普通文件（既不是目录，也不是设备文件），如果是，则返回 true。 | [ -f $file ] 返回 true。  |
| -g file | 检测文件是否设置了 SGID 位，如果是，则返回 true。            | [ -g $file ] 返回 false。 |
| -k file | 检测文件是否设置了粘着位(Sticky Bit)，如果是，则返回 true。  | [ -k $file ] 返回 false。 |
| -p file | 检测文件是否是有名管道，如果是，则返回 true。                | [ -p $file ] 返回 false。 |
| -u file | 检测文件是否设置了 SUID 位，如果是，则返回 true。            | [ -u $file ] 返回 false。 |
| -r file | 检测文件是否可读，如果是，则返回 true。                      | [ -r $file ] 返回 true。  |
| -w file | 检测文件是否可写，如果是，则返回 true。                      | [ -w $file ] 返回 true。  |
| -x file | 检测文件是否可执行，如果是，则返回 true。                    | [ -x $file ] 返回 true。  |
| -s file | 检测文件是否为空（文件大小是否大于0），不为空返回 true。     | [ -s $file ] 返回 true。  |
| -e file | 检测文件（包括目录）是否存在，如果是，则返回 true。          | [ -e $file ] 返回 true。  |

## 流程控制  

### 1. If..else 语法 

```shell
if condition1
then
    command1
elif condition2 
then 
    command2
else
    commandN
fi
```

写成1行（适用于终端命令提示符）：

```shell
if [ $(ps -ef | grep -c "ssh") -gt 1 ]; then echo "true"; fi
```

### 2. for循环

```shell
for var in item1 item2 ... itemN
do
    command1
    command2
    ...
    commandN
done
# 例子
for loop in 1 2 3 4 5
do
    echo "The value is: $loop"
done
```

写成1行（适用于终端命令提示符）：

```shell
for var in item1 item2 ... itemN; do command1; command2… done;
```

### 3. While 循环  

```Shell
while condition
do
    command
done
```

例子

```shell
#!/bin/bash
int=1
while(( $int<=5 ))
do
    echo $int
    let "int++"
done
```

### 4. until循环

```Shell
until condition
do
    command
done

a=0
# 例子
until [ ! $a -lt 10 ]
do
   echo $a
   a=`expr $a + 1`
done
```

### 5.case语法  

```shell
case 值 in
模式1)
    command
    ;;
模式2）
    command1
    ;;
esac
```

例子:

```Shell
echo '输入 1 到 4 之间的数字:'
echo '你输入的数字为:'
read aNum
case $aNum in
    1)  echo '你选择了 1'
    ;;
    2)  echo '你选择了 2'
    ;;
    3)  echo '你选择了 3'
    ;;
    4)  echo '你选择了 4'
    ;;
    *)  echo '你没有输入 1 到 4 之间的数字'
    ;;
esac
```

## 函数  

```shell
[ function ] funname [()]{
    action;
    [return int;]
}
```

在函数内可以通过通过`$n`获取函数入参

```shell
funWithParam(){
    echo "第一个参数为 $1 !"
    echo "第二个参数为 $2 !"
    echo "第十个参数为 $10 !"
    echo "第十个参数为 ${10} !"
    echo "第十一个参数为 ${11} !"
    echo "参数总数有 $# 个!"
    echo "作为一个字符串输出所有参数 $* !"
}
funWithParam 1 2 3 4 5 6 7 8 9 34 73
```

注意，`$10` 不能获取第十个参数，获取第十个参数需要${10}。当n>=10时，需要使用${n}来获取参数

## 输入输出重定向  

重定向命令列表如下：

| 命令            | 说明                                               |
| --------------- | -------------------------------------------------- |
| command > file  | 将输出重定向到 file。                              |
| command < file  | 将输入重定向到 file。                              |
| command >> file | 将输出以追加的方式重定向到 file。                  |
| n > file        | 将文件描述符为 n 的文件重定向到 file。             |
| n >> file       | 将文件描述符为 n 的文件以追加的方式重定向到 file。 |
| n >& m          | 将输出文件 m 和 n 合并。                           |
| n <& m          | 将输入文件 m 和 n 合并。                           |
| << tag          | 将开始标记 tag 和结束标记 tag 之间的内容作为输入。 |

如果希望执行某个命令，但又不希望在屏幕上显示输出结果，那么可以将输出重定向到 /dev/null：

```shell
command > /dev/null
```

/dev/null 是一个特殊的文件，写入到它的内容都会被丢弃；如果尝试从该文件读取内容，那么什么也读不到。但是 /dev/null 文件非常有用，将命令的输出重定向到它，会起到"禁止输出"的效果。

每个 Unix/Linux 命令运行时都会打开三个文件：

- 标准输入文件(stdin)：stdin的文件描述符为0，Unix程序默认从stdin读取数据。
- 标准输出文件(stdout)：stdout 的文件描述符为1，Unix程序默认向stdout输出数据。
- 标准错误文件(stderr)：stderr的文件描述符为2，Unix程序会向stderr流中写入错误信息。

如果希望屏蔽 stdout 和 stderr，可以这样写：

```
command > /dev/null 2>&1
```
## shell文件包含

引入其他的shell文件

```shell
. filename   # 注意点号(.)和文件名中间有一空格
或
source filename
```

例子  

```Shell
#使用 . 号来引用test1.sh 文件
. ./test1.sh

# 或者使用以下包含文件代码
# source ./test1.sh

echo "url：$url"
```