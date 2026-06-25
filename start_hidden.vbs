' PDF Auto Printer - Hidden Startup Script
' This launches auto_printer.py using python.exe (hidden by VBS window style 0)
' We avoid pythonw.exe because it prevents pystray system tray icon from working.

Set fso = CreateObject("Scripting.FileSystemObject")
Set objShell = CreateObject("WScript.Shell")

' Get script directory
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
logFile = scriptDir & "\startup_debug.txt"
errorLogFile = scriptDir & "\startup_error.txt"

' Delete old logs
On Error Resume Next
fso.DeleteFile logFile
fso.DeleteFile errorLogFile
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
        Log "Already running (PID: " & objProcess.ProcessId & "). Exiting."
        WScript.Quit
    End If
Next

Log "Not running. Starting application..."

' Read Python paths from config.json
pythonwPath = ""
pythonPath = ""
configFile = scriptDir & "\config.json"
If fso.FileExists(configFile) Then
    On Error Resume Next
    Set configStream = fso.OpenTextFile(configFile, 1, False)
    If Err.Number = 0 Then
        configText = configStream.ReadAll
        configStream.Close
        
        ' Parse pythonw_path from JSON
        pos = InStr(configText, """pythonw_path""")
        If pos > 0 Then
            pos2 = InStr(pos, configText, ": """)
            If pos2 > 0 Then
                pos3 = InStr(pos2 + 3, configText, """")
                If pos3 > 0 Then
                    pythonwPath = Mid(configText, pos2 + 3, pos3 - pos2 - 3)
                End If
            End If
        End If
        
        ' Parse python_path from JSON
        pos = InStr(configText, """python_path""")
        If pos > 0 Then
            pos2 = InStr(pos, configText, ": """)
            If pos2 > 0 Then
                pos3 = InStr(pos2 + 3, configText, """")
                If pos3 > 0 Then
                    pythonPath = Mid(configText, pos2 + 3, pos3 - pos2 - 3)
                End If
            End If
        End If
    End If
    On Error GoTo 0
    
    Log "Config pythonw_path: " & pythonwPath
    Log "Config python_path: " & pythonPath
End If

' Build list of Python commands to try (in priority order)
Dim pythonCmds(3)
cmdCount = 0

If pythonPath <> "" And fso.FileExists(pythonPath) Then
    pythonCmds(cmdCount) = """" & pythonPath & """"
    cmdCount = cmdCount + 1
End If
pythonCmds(cmdCount) = "python"
cmdCount = cmdCount + 1
pythonCmds(cmdCount) = "py"
cmdCount = cmdCount + 1

' Try each Python command
' Use cmd /c to redirect stderr to error log for debugging
launched = False

For i = 0 To cmdCount - 1
    pyCmd = pythonCmds(i)
    Log "Trying: " & pyCmd
    
    On Error Resume Next
    Err.Clear
    ' Launch via cmd /c with stderr redirect so we can see Python crash errors
    fullCmd = "cmd /c " & pyCmd & " auto_printer.py 2> """ & errorLogFile & """"
    objShell.Run fullCmd, 0, False
    
    If Err.Number <> 0 Then
        Log "  Run failed: " & Err.Description
        On Error GoTo 0
    Else
        On Error GoTo 0
        ' Wait a moment then check if process is actually running
        WScript.Sleep 3000
        
        Set colCheck = objWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = 'python.exe' OR Name = 'python3.exe'")
        processFound = False
        For Each objProc In colCheck
            If InStr(objProc.CommandLine, "auto_printer.py") > 0 Then
                processFound = True
                Log "  VERIFIED RUNNING (PID: " & objProc.ProcessId & ") with: " & pyCmd
                Exit For
            End If
        Next
        
        If processFound Then
            launched = True
            Exit For
        Else
            ' Process started but crashed - check error log
            Log "  Process exited immediately with: " & pyCmd
            If fso.FileExists(errorLogFile) Then
                On Error Resume Next
                Set errFile = fso.OpenTextFile(errorLogFile, 1, False)
                If Err.Number = 0 Then
                    errContent = errFile.ReadAll
                    errFile.Close
                    If Len(errContent) > 0 Then
                        Log "  Python Error Output:"
                        Log "  " & Replace(errContent, vbCrLf, vbCrLf & "  ")
                    End If
                End If
                On Error GoTo 0
            End If
        End If
    End If
Next

If Not launched Then
    Log "ERROR: All launch methods failed! Python may be crashing on startup."
    Log "Check startup_error.txt for Python error details."
    MsgBox "Could not start PDF Auto Printer." & vbCrLf & vbCrLf & _
           "Python process keeps crashing." & vbCrLf & _
           "Check these files for details:" & vbCrLf & _
           "  - startup_debug.txt" & vbCrLf & _
           "  - startup_error.txt", 16, "Startup Error"
End If
