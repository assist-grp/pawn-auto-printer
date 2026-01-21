' PDF Auto Printer - Hidden Startup Script
' This launches auto_printer.py in the background using pythonw.exe

Set fso = CreateObject("Scripting.FileSystemObject")
Set objShell = CreateObject("WScript.Shell")

' Get script directory
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
logFile = scriptDir & "\startup_debug.txt"

' Delete old log
On Error Resume Next
fso.DeleteFile logFile
On Error GoTo 0

Sub Log(msg)
    On Error Resume Next
    Set f = fso.OpenTextFile(logFile, 8, True)
    f.WriteLine Now & " - " & msg
    f.Close
    On Error GoTo 0
End Sub

Log "=== PDF Auto Printer Startup ==="
Log "Script Directory: " & scriptDir

' Change to script directory
objShell.CurrentDirectory = scriptDir
Log "Working Directory: " & objShell.CurrentDirectory

' Check if already running
Set objWMI = GetObject("winmgmts:\\.\root\cimv2")
Set colProcesses = objWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = 'pythonw.exe' OR Name = 'python.exe'")

For Each objProcess In colProcesses
    If InStr(objProcess.CommandLine, "auto_printer.py") > 0 Then
        Log "Already running. Exiting."
        WScript.Quit
    End If
Next

Log "Not running. Starting application..."

' Try pythonw first (hidden), then python (visible fallback)
On Error Resume Next

' Method 1: pythonw (hidden)
Err.Clear
objShell.Run "pythonw auto_printer.py", 0, False
If Err.Number = 0 Then
    Log "SUCCESS: Started with pythonw"
    WScript.Quit
End If
Log "pythonw failed: " & Err.Description

' Method 2: python (visible fallback)
Err.Clear
objShell.Run "python auto_printer.py", 0, False
If Err.Number = 0 Then
    Log "SUCCESS: Started with python (visible)"
    WScript.Quit
End If
Log "python failed: " & Err.Description

' Method 3: py -w (Windows launcher hidden)
Err.Clear
objShell.Run "py -w auto_printer.py", 0, False
If Err.Number = 0 Then
    Log "SUCCESS: Started with py -w"
    WScript.Quit
End If
Log "py -w failed: " & Err.Description

' Method 4: py (Windows launcher visible)
Err.Clear
objShell.Run "py auto_printer.py", 0, False
If Err.Number = 0 Then
    Log "SUCCESS: Started with py"
    WScript.Quit
End If
Log "py failed: " & Err.Description

Log "ERROR: All launch methods failed!"
MsgBox "Could not start PDF Auto Printer." & vbCrLf & "Python was not found. Please check startup_debug.txt", 16, "Startup Error"
On Error GoTo 0
