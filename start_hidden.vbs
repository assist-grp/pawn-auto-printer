Set objShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
Set objWMI = GetObject("winmgmts:\\.\root\cimv2")

' Check if auto_printer.py is already running
Set colProcesses = objWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = 'pythonw.exe' OR Name = 'python.exe'")

isRunning = False
For Each objProcess In colProcesses
    If InStr(objProcess.CommandLine, "auto_printer.py") > 0 Then
        isRunning = True
        Exit For
    End If
Next

If isRunning Then
    ' Already running - show notification
    Set objNotification = CreateObject("WScript.Shell")
    objNotification.Popup "PDF Auto Printer is already running in background!", 3, "Auto Printer", 64
Else
    ' Not running - start it
    ' Get the directory where this script is located
    scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
    
    ' Change to the script directory
    objShell.CurrentDirectory = scriptDir
    
    ' Run pythonw (no console window) with auto_printer.py
    objShell.Run "pythonw auto_printer.py", 0, False
    
    ' Show a brief notification
    Set objNotification = CreateObject("WScript.Shell")
    objNotification.Popup "PDF Auto Printer started!", 2, "Auto Printer", 64
End If
