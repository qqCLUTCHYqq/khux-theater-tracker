Option Explicit
Dim shell, fs, folder, script
Set shell = CreateObject("WScript.Shell")
Set fs = CreateObject("Scripting.FileSystemObject")
folder = fs.GetParentFolderName(WScript.ScriptFullName)
script = fs.BuildPath(folder, "Install-KHUX.ps1")
If Not fs.FileExists(script) Or Not fs.FileExists(fs.BuildPath(folder, "Downloader.cs")) Then
    MsgBox "Extract the entire setup ZIP into one folder first.", 48, "KHUX Setup"
    WScript.Quit 1
End If
shell.Run "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & script & """", 0, False
