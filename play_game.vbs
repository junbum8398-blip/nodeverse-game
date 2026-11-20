Option Explicit
Dim sh, fs, folder, bat
Set sh = CreateObject("WScript.Shell")
Set fs = CreateObject("Scripting.FileSystemObject")
folder = fs.GetParentFolderName(WScript.ScriptFullName)
bat = fs.BuildPath(folder, "play_game.bat")
sh.Run Chr(34) & bat & Chr(34), 0, False
