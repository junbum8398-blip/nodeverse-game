@echo off
setlocal
cd /d "%~dp0"

set "GODOT_EXE="
if not defined GODOT_EXE if exist "%~dp0..\Godot_v4.7.2-stable_win64.exe" if not exist "%~dp0..\Godot_v4.7.2-stable_win64.exe\*" set "GODOT_EXE=%~dp0..\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT_EXE if exist "%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe" if not exist "%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe\*" set "GODOT_EXE=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT_EXE if exist "%USERPROFILE%\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe" if not exist "%USERPROFILE%\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe\*" set "GODOT_EXE=%USERPROFILE%\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT_EXE if exist "C:\Users\Playdata\Desktop\Godot_v4.7.2-stable_win64.exe" if not exist "C:\Users\Playdata\Desktop\Godot_v4.7.2-stable_win64.exe\*" set "GODOT_EXE=C:\Users\Playdata\Desktop\Godot_v4.7.2-stable_win64.exe"

if not defined GODOT_EXE (
    echo [ERROR] Could not find Godot_v4.7.2-stable_win64.exe
    pause
    exit /b 1
)

start "" "%GODOT_EXE%" --path "%CD%" --resolution 1600x960 "res://scenes/NodeverseWorld.tscn"
exit /b 0
