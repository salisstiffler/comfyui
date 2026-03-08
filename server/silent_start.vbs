Set WshShell = CreateObject("WScript.Shell")
' 获取当前脚本所在目录
strPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
' 构建启动命令 (假设 python 已加入环境变量)
' 使用 pythonw.exe 可以进一步确保没有控制台交互
strCommand = "pythonw.exe " & strPath & "\host_bridge.py"
' 0 表示隐藏窗口，False 表示不等待程序结束
WshShell.Run strCommand, 0, False
