@echo off
setlocal
cd /d "%~dp0"

echo [1/2] Creating backup of 3D Godot Project...
set "TIMESTAMP=%DATE:~0,4%%DATE:~5,2%%DATE:~8,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "TIMESTAMP=%TIMESTAMP: =0%"
set "BACKUP_DIR=..\backup_3d_project_%TIMESTAMP%"

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
xcopy /E /I /Y "." "%BACKUP_DIR%\" >nul
echo [OK] 3D Project backed up to: %BACKUP_DIR%

echo [2/2] Launching 3D Game...
set "GODOT_EXE="

:: 1. Check parent folder (e.g. Desktop when project folder is on Desktop)
if not defined GODOT_EXE if exist "%~dp0..\Godot_v4.7.2-stable_win64.exe" if not exist "%~dp0..\Godot_v4.7.2-stable_win64.exe\*" set "GODOT_EXE=%~dp0..\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT_EXE if exist "%~dp0..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" set "GODOT_EXE=%~dp0..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT_EXE if exist "%~dp0..\Godot.exe" set "GODOT_EXE=%~dp0..\Godot.exe"

:: 2. Check current user's Desktop
if not defined GODOT_EXE if exist "%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe" if not exist "%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe\*" set "GODOT_EXE=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT_EXE if exist "%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" set "GODOT_EXE=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"

:: 3. Check OneDrive Desktop
if not defined GODOT_EXE if exist "%USERPROFILE%\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe" if not exist "%USERPROFILE%\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe\*" set "GODOT_EXE=%USERPROFILE%\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT_EXE if exist "%USERPROFILE%\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" set "GODOT_EXE=%USERPROFILE%\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"

:: 4. Fallback fixed paths
if not defined GODOT_EXE if exist "C:\Users\Playdata\Desktop\Godot_v4.7.2-stable_win64.exe" if not exist "C:\Users\Playdata\Desktop\Godot_v4.7.2-stable_win64.exe\*" set "GODOT_EXE=C:\Users\Playdata\Desktop\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT_EXE if exist "C:\Users\kingd\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" set "GODOT_EXE=C:\Users\kingd\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT_EXE if exist "C:\Users\kingd\Desktop\Godot_v4.7.2-stable_win64.exe" if not exist "C:\Users\kingd\Desktop\Godot_v4.7.2-stable_win64.exe\*" set "GODOT_EXE=C:\Users\kingd\Desktop\Godot_v4.7.2-stable_win64.exe"

if defined GODOT_EXE (
    start "" "%GODOT_EXE%" --path "%CD%" --resolution 1600x960 "res://scenes/NodeverseWorld.tscn"
)
