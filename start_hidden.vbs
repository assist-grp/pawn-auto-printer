' Define Log File
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
logFile = scriptDir & "\startup_debug.txt"

Sub Log(msg)
    On Error Resume Next
    Set f = fso.OpenTextFile(logFile, 8, True)
    f.WriteLine Now & " - " & msg
    f.Close
    On Error GoTo 0
End Sub

' Clear old log
On Error Resume Next
fso.DeleteFile logFile
On Error GoTo 0

Log "Startup script initiated."

Set objShell = CreateObject("WScript.Shell")
Set objWMI = GetObject("winmgmts:\\.\root\cimv2")

' Change to the script directory
objShell.CurrentDirectory = scriptDir
Log "Current Directory set to: " & scriptDir

' Check if auto_printer.py is already running
Log "Checking if process is already running..."
Set colProcesses = objWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = 'pythonw.exe' OR Name = 'python.exe'")

isRunning = False
For Each objProcess In colProcesses
    If InStr(objProcess.CommandLine, "auto_printer.py") > 0 Then
        isRunning = True
        Exit For
    End If
Next

If isRunning Then
    Log "Process already running. Exiting."
Else
    Log "Process not found. Attempting to start."
    ' Try to launch with different python commands
    On Error Resume Next
    
    ' Priority 1: py.exe -w (Standard Windows Launcher)
    err.Clear
    Log "Trying 'py -w'..."
    objShell.Run "py --version", 0, True ' Check version first (wait)
    If Err.Number = 0 Then
        objShell.Run "py -w auto_printer.py", 0, False
        If Err.Number = 0 Then 
            Log "Success: Launched via py -w"
            WScript.Quit
        End If
    Else
        Log "py launcher check failed."
    End If
    
    ' Priority 2: pythonw.exe (PATH based)
    ' pythonw doesn't output version easily to console, use python for check
    err.Clear
    Log "Trying 'python' (PATH)..."
    objShell.Run "python --version", 0, True
    If Err.Number = 0 Then 
        objShell.Run "pythonw auto_printer.py", 0, False
        If Err.Number = 0 Then 
            Log "Success: Launched via pythonw"
            WScript.Quit
        End If
    Else
        Log "python (PATH) check failed."
    End If
    
    ' Priority 3: Check WindowsApps (Store Python) explicitly
    localAppData = objShell.ExpandEnvironmentStrings("%LOCALAPPDATA%")
    
    ' Python 3.exe in WindowsApps
    winAppsPy3 = localAppData & "\Microsoft\WindowsApps\python3.exe"
    Log "Checking WindowsApps path: " & winAppsPy3
    If fso.FileExists(winAppsPy3) Then
        err.Clear
        ' Verify it's not a stub by checking size > 0 (Simple check)
        Set f = fso.GetFile(winAppsPy3)
        if f.Size > 0 Then
            Log "Found python3.exe in WindowsApps. Launching..."
            objShell.Run """" & winAppsPy3 & """ auto_printer.py", 0, False
            If Err.Number = 0 Then 
                Log "Success: Launched via WindowsApps python3.exe"
                WScript.Quit
            Else
                Log "Failed: " & Err.Description
            End If
        Else
            Log "Found WindowsApps python3.exe but it is 0 bytes (Stub)."
        End If
    End If
    
    ' Python.exe in WindowsApps
    winAppsPy = localAppData & "\Microsoft\WindowsApps\python.exe"
    Log "Checking WindowsApps path: " & winAppsPy
    If fso.FileExists(winAppsPy) Then
        err.Clear
         Set f = fso.GetFile(winAppsPy)
        if f.Size > 0 Then
            Log "Found python.exe in WindowsApps. Launching..."
            objShell.Run """" & winAppsPy & """ auto_printer.py", 0, False
            If Err.Number = 0 Then 
                Log "Success: Launched via WindowsApps python.exe"
                WScript.Quit
            Else
                Log "Failed: " & Err.Description
            End If
        Else
             Log "Found WindowsApps python.exe but it is 0 bytes (Stub)."
        End If
    End If

    ' Priority 4: python.exe (Visible window fallback)
    err.Clear
    Log "Trying 'python' (fallback)..."
    objShell.Run "python auto_printer.py", 0, False
    If Err.Number = 0 Then 
        Log "Success: Launched via python"
        WScript.Quit
    Else
        Log "Failed: " & Err.Description
    End If
    
    On Error GoTo 0
    
    ' If we get here, everything failed.
    Log "CRITICAL: All launch methods failed."
    MsgBox "Could not start PDF Auto Printer." & vbCrLf & "Python was not found in PATH or WindowsApps.", 16, "Startup Error"
End If
