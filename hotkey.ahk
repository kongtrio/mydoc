#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

;;;;;;;;;;;;;;;;;;;;;;;;;本地一些文件目录;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
chrome_path=C:\Program Files (x86)\Google\Chrome\Application\chrome.exe
idea_path=D:\IntelliJ IDEA 14.1.4\bin\idea.exe
youdao_path=D:\YoudaoNote\YoudaoNote.exe
youdao_word_path=C:\Users\yangjb\AppData\Local\Youdao\dict\Application\YodaoDict.exe
xshell_path=D:\Xshell.exe
everything_path=D:\Everything\Everything.exe
ahk_help_path=C:\Program Files\AutoHotkey\AutoHotkey.chm
weixin_path=F:\WeChat\WeChat.exe
doc_path=F:\word\doc  
qq_recieve_path=E:\qq接收文档\290600974\FileRecv
pycharm_path=D:\PyCharm 5.0.4\bin\pycharm.exe


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;【全局快捷键】;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																											 ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;alt快捷键;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																											 ;;;;;
;;;;;;;;;;弹出一个窗口,打开命令模式																			 ;;;;;
!c::            																			 				 ;;;;;
inputBox,command,enter command																			     ;;;;;
if ErrorLevel																			 					 ;;;;;
    return																			                         ;;;;;
else																			                             ;;;;;
	if (command=="tmp")																			             ;;;;;
		run d:/tmp
	else if (command=="firefox")
		run D:\firfox\firefox.exe
	else if (command=="word")
		run %youdao_word_path%
	else if (command=="weixin")
		run %weixin_path%
	else if (command=="c" || command=="d" || command=="e" || command=="f")
		run %command%:/
	else if (command=="doc")
		run %doc_path%
	else if (command=="code")
		run F:\word\code
	else if (command=="export")
		run F:\word\export
	else if (command=="log")
		run F:\word\log
	else if (command=="si")
		run F:\word\si
	else if (command=="war")
		run F:\word\war
	else if (command=="work")
		run F:\word\work
	else if (command=="qqfile")
		run %qq_recieve_path%
	else if (command=="python")
		run %pycharm_path%
	else if (command=="everything")
		run %everything_path%
	else if (command=="shell")
		run %xshell_path%
	else if (command=="maacode")
		run f:/maa
	else
        run "%command%"
return

;;;;;;;;;;;上下左右映射成alt+jkil
!k::
Send {Up}
return

!j::
Send {Down}
return

!h::
Send {Left}
return

!l::
Send {Right}
return

;;;;;;;;;;;;;映射滚轮上下
!i::
Send {WheelDown}
return

!u::
Send {WheelUp}
return

;;;;;;;;;;;;;删除一整行
!d::
Send {Home} 
Send +{End} 
Send {delete}
send {Backspace}
return 

;;;;;;;;;;;;;复制一整行
!y::
send {home}
send +{end}
send ^c
return

;;;;;;;;;;;;;另起一行粘贴内容																				;;;;;
!p::																										;;;;;
send {end}																									;;;;;
send {enter}																								;;;;;
send %clipboard%																							;;;;;
return																										;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																											;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;window键快捷键;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																											;;;;;
;;;;;;;;;;;;;最小化当前窗口																					;;;;;
#w::																								        ;;;;;										
WinMinimize,A 																								;;;;;
return																										;;;;;

;;;;;;;;;;;;;;;在谷歌搜索中打开选中的内容
#q::
Send ^c 
sleep,100
run https://www.google.com/search?q=%clipboard%&oq=%clipboard%&aqs=chrome..69i57j69i61j69i59j0l3.1486j0j1&sourceid=chrome&ie=UTF-8
return

;;;;;;;;;;;;;;;;;;在百度搜索中打开选中的内容
#b::
Send ^c 
sleep,100
run https://www.baidu.com/s?ie=utf-8&f=8&rsv_bp=1&rsv_idx=1&tn=92765401_hao_pg&wd=%clipboard%
return

;;;;;;;;;;;;;;;;;在淘宝中打开选中的内容
#t::
Send ^c 
sleep,100
run https://s.taobao.com/search?q=%clipboard%
return

;;;;;;;;;;;;;;;;;;;;;在京东中打开选中的内容
#j::
Send ^c 
sleep,100
run http://search.jd.com/Search?keyword=%clipboard%&enc=utf-8&wq=%clipboard%&pvid=ckk1trui.xqtaau
return

;;;;;;;;;;;;;;;;;;;;;;在亚马孙中打开选中的内容
#a::
Send ^c 
sleep,100
run https://www.amazon.cn/s/ref=nb_sb_noss?field-keywords=%clipboard%
return

;;;;;;;;;;;;;;;;;;;;;;;;在知乎中打开选中的内容
#z::
Send ^c 
sleep,100
run https://www.zhihu.com/search?type=content&q=%clipboard%
return

;;;;;;;;;;;;;;;;;;;;;;;;;在词典网站中打开选中的内容,查找单词的意思
#c::
Send ^c 
sleep,100																									;;;;;
run http://dict.cn/%clipboard%																				;;;;;
return																										;;;;;
																											;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;打开一个记事本																		;;;;;
#n::																										;;;;;
	run notepad																								;;;;;
return																										;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																											;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;shift键快捷键;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																											;;;;;
;;;;;;;;;;;;;最小化当前窗口																					;;;;;
+enter::																								    ;;;;;										
send {end}
send {enter} 	
send {home}																									;;;;;
return																										;;;;;
																											;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																											;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;字符串映射;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																											;;;;;
;;;;;;;;;;;;;打开计算器  																					;;;;;
::/cal::  																									;;;;;
	run calc																								;;;;;
return		  																								;;;;;																									
;;;;;;;;;;;;;打开autohotkey的api帮助文档
::/ahk::
	run %ahk_help_path% 
return

;;;;;;;;;;;;;打开控制面板
::/con::
	run control
return

;;;;;;;;;;;;;MASP用户密码
::/mp::
	send yangjb{tab}yangjb321{raw}!@#
	send {tab}{tab}
return

;;;;;;;;;;;;;;dspftp用户密码
::/dp::
	send hdfsftp{tab}20dSp16
return
	
::/get::
WinGetClass, title,A
msgbox,%title%
clipboard=%title%
return

;;;;;;;;;;;;;;;打开任务管理器 
::/t:: 
if WinExist Windows 任务管理器 
WinActivate 
else 
Run taskmgr.exe 
return 

;;;;;;;;;;;;;;;;;
::/qq::
WinActivate,拉
return

;;;;;;;;;;;;;;;;打开系统属性 																				;;;;;
::/sys:: 																									;;;;;
Run control sysdm.cpl 																						;;;;;
return 																										;;;;;
																											;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																											;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;其他组合键映射;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																											;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;clrt+shift+c复制文件路径															;;;;;
^+c::																										;;;;;
; null= 																									;;;;;
send ^c 																									;;;;;
sleep,100
clipboard=%clipboard% ;%null%
tooltip,%clipboard%
sleep,500
tooltip,
return

;;;;;;;;;;;;;;;;;;;;;;;;;;开启选择模式向左移动
!+h::
send +{left}
return

;;;;;;;;;;;;;;;;;;;;;;;;;;开启选择模式向右移动
!+l::
send +{right}
return

;;;;;;;;;;;;;;;;;;;;;;;;;;开启选择模式向下移动
!+j::
send +{Down}
return

;;;;;;;;;;;;;;;;;;;;;;;;;;开启选择模式向上移动
!+k::
send +{up}
return

;;;;;;;;;;;;;;;;;;;;;;;;;;;迅速打开idea,打开的话激活窗口
!+i::
	ifWinExist,ahk_class SunAwtFrame
		winActivate
	else
		run %idea_path%
return

;;;;;;;;;;;;;;;;;;;;;;;;;;;迅速打开有道,打开的话激活窗口
!+y::
	ifWinExist,ahk_class NeteaseYoudaoYNoteMainWnd
		winActivate
	else
		run %youdao_path%
return

;;;;;;;;;;;;;;;;;;;;;;;;;;;迅速打开chrom,已经打开的话就激活窗口
!+p::
	ifWinExist,ahk_exe chrome.exe
		winActivate
	else
		run %chrome_path%
return

;;;;;;;;;;;;;;;;;;;;;;;;;;;迅速打开xshell,已经打开的话就激活窗口
!+s::
	ifWinExist,ahk_class Xshell::MainFrame_0
		winActivate
	else
		run %xshell_path%
return

;;;;;;;;;;;;;;;;;;;;;;;;;;;alt+shift+c获取鼠标位置处的颜色取值
!+c::
MouseGetPos, mouseX, mouseY
; 获得鼠标所在坐标，把鼠标的 X 坐标赋值给变量 mouseX ，同理 mouseY
PixelGetColor, color, %mouseX%, %mouseY%, RGB
; 调用 PixelGetColor 函数，获得鼠标所在坐标的 RGB 值，并赋值给 color
StringRight color,color,6
; 截取 color（第二个 color）右边的6个字符，因为获得的值是这样的：#RRGGBB，一般我们只需要 RRGGBB 部分。把截取到的值再赋给 color（第一个 color）。
clipboard = %color%
; 把 color 的值发送到剪贴板
return																										;;;;;
																											;;;;;
																											;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


::ii::
WinActivate,ahk_class TxGuiFoundationd
return


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;【局部快捷键】;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																											 ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;【Chrome】;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#IfWinActive ahk_class Chrome_WidgetWin_1
!n::Send ^t 
!x::Send ^w
!,::Send ^+{Tab} 
!.::Send ^{Tab} 
!z::Send ^+t 
!+h::send ^h
return 


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;【Idea】;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#IfWinActive ahk_class SunAwtFrame  
!n::send !{insert}