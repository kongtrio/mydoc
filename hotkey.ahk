#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

;chrom path
chrome_path=C:\Program Files (x86)\Google\Chrome\Application\chrome.exe

;idea path
idea_path=D:\IntelliJ IDEA 14.1.4\bin\idea.exe

;youdao_path
youdao_path=D:\YoudaoNote\YoudaoNote.exe

;x_shell path
xshell_path=D:\Xshell.exe

;everything path
everything_path=D:\Everything\Everything.exe

;ahk path
ahk_help_path=C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe

;weixin path
weixin_path=F:\WeChat\WeChat.exe

#f::
	ifWinExist,ahk_exe %everything_path%
		WinMove,11,11
	else
		run %everything_path%
return

;把谷歌浏览器映射成alt+1
#1::
	ifWinExist,ahk_exe %chrome_path%
		winActivate
	else
		run %chrome_path%
return

;把idea映射成alt+2
#2::
	ifWinExist,ahk_exe %idea_path%
		winActivate
	else
		run %idea_path%
return

;开启有道
#3::
	ifWinExist,ahk_exe %youdao_path%
		WinMaximize
	else
		run %youdao_path%
return

;开启xshell
#4::
	ifWinExist,ahk_exe %xshell_path%
		WinMaximize
	else
		run %xshell_path%
return

;open weiin
#8::
	ifWinExist,ahk_exe %weixin_path%
		winActivate
	else
		run %weixin_path%
return

;win+n to open a notepad
#n::
	run notepad
return

;type ahk help to open ahk help
::ahkhelp::
	ifWinExist,ahk_exe %ahk_help_path%
		WinMaximize
	else
		run %ahk_help_path% 
return

#w::
WinMinimize,A
return

#q::
WinRestore,A
return

;上下左右映射成alt+jkil
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

;映射滚轮上下
!i::
Send {WheelDown}
return

!u::
Send {WheelUp}
return



#o::
if WinExist("ahk_exe chrome.exe")
	WinActivate, ahk_exe C:\Program Files (x86)\Google\Chrome\Application\chrome.exe
else
	Run, C:\Program Files (x86)\Google\Chrome\Application\chrome.exe  


::c-calc::
run calc
return

::c-control::
run control
return

::pycharm::
run D:\PyCharm 5.0.4\bin\pycharm.exe
return

::wspwd::
send yangjb{tab}yangjb321{raw}!@#
send {tab}{tab}
return

::ftppwd::
send hdfsftp{tab}20dSp16
return

!e::
inputBox,command,enter command
if ErrorLevel
    return
else
	if (command=="tmp")
		run d:/tmp
	else if (command=="firefox")
		run D:\firfox\firefox.exe
	else if (command=="youdao")
		run C:\Users\yangjb\AppData\Local\Youdao\dict\Application\YodaoDict.exe
	else if (command=="pwd")
		send yangjb{tab}yangjb321{raw}!@#
	else if (command=="c" || command=="d" || command=="e" || command=="f")
		run %command%:/
	else if (command=="doc")
		run F:\word\doc
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
	else if (command="qqfile")
		run E:\qq接收文档\290600974\FileRecv
	else
        run "%command%"
return

!q::
inputBox,key,enter key
if ErrorLevel
    return
else
    run https://www.google.com/search?q=%key%&oq=%key%&aqs=chrome..69i57j69i61j69i59j0l3.1486j0j1&sourceid=chrome&ie=UTF-8
return





