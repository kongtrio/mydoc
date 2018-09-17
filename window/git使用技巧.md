#### 如何用命令行提交的时候不输入密码  

​	在用户目录(如C:\Users\yangjb)下有个文件叫.gitconfig，在里面加上  

> [credential] 
>
>  helper = store

​	下次再输入用户名和密码的时候,git就会记住,并且在用户目录下形成.git-credentials文件。以后提交就不用输入密码了。



