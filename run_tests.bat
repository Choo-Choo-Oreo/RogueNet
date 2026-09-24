@echo off
rem Runs every test in test/. Needs a Godot console exe in .godot-local\ (gitignored, see test/README.md).
cd /d "%~dp0"
for %%f in (.godot-local\Godot*_console.exe) do set GODOT=%%f
if not defined GODOT (echo No Godot console exe in .godot-local\ & exit /b 2)
"%GODOT%" --headless --import >nul 2>&1
"%GODOT%" --headless -s res://addons/gut/gut_cmdln.gd
exit /b %errorlevel%
