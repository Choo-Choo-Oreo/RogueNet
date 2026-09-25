@echo off
rem Headless playtest of the development biome; see test/sim/README.md. Pass seconds and cell names through.
cd /d "%~dp0"
for %%f in (.godot-local\Godot*_console.exe) do set GODOT=%%f
if not defined GODOT (echo No Godot console exe in .godot-local\ & exit /b 2)
"%GODOT%" --headless --fixed-fps 60 -s res://test/sim/dev_sim.gd -- %*
exit /b %errorlevel%
