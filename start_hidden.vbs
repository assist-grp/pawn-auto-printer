Set objShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
Set objWMI = GetObject("winmgmts:\\.\root\cimv2")

' Get the directory where this script is located
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
' Change to the script directory
objShell.CurrentDirectory = scriptDir

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
    ' Already running - do nothing
Else
    ' Try to launch with different python commands
    On Error Resume Next
    
    ' Priority 1: py.exe -w (Standard Windows Launcher)
    err.Clear
    objShell.Run "py -w auto_printer.py", 0, False
    If Err.Number = 0 Then WScript.Quit
    
    ' Priority 2: pythonw.exe (PATH based)
    err.Clear
    objShell.Run "pythonw auto_printer.py", 0, False
    If Err.Number = 0 Then WScript.Quit
    
    ' Priority 3: Check WindowsApps (Store Python) explicitly
    localAppData = objShell.ExpandEnvironmentStrings("%LOCALAPPDATA%")
    
    ' Python 3.exe in WindowsApps
    winAppsPy3 = localAppData & "\Microsoft\WindowsApps\python3.exe"
    If fso.FileExists(winAppsPy3) Then
        err.Clear
        objShell.Run """" & winAppsPy3 & """ auto_printer.py", 0, False
        If Err.Number = 0 Then WScript.Quit
    End If
    
    ' Python.exe in WindowsApps
    winAppsPy = localAppData & "\Microsoft\WindowsApps\python.exe"
    If fso.FileExists(winAppsPy) Then
        err.Clear
        objShell.Run """" & winAppsPy & """ auto_printer.py", 0, False
        If Err.Number = 0 Then WScript.Quit
    End If

    ' Priority 4: python.exe (Visible window fallback)
    err.Clear
    objShell.Run "python auto_printer.py", 0, False
    If Err.Number = 0 Then WScript.Quit
    
    On Error GoTo 0
    
    ' If we get here, everything failed.
    MsgBox "Could not start PDF Auto Printer." & vbCrLf & "Python was not found in PATH or WindowsApps.", 16, "Startup Error"
End If
