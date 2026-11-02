@echo off
rem Runs the given command inside the MSVC x64 developer environment, e.g.
rem   msvc.cmd cmake --preset default
rem Needed because the build uses Ninja + cl (REAPER requires the MSVC ABI).
setlocal
where cl >nul 2>nul
if not errorlevel 1 goto run
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VSDIR_FILE=%TEMP%\reaper_mobile_mixer_vsdir.txt"
"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath > "%VSDIR_FILE%"
set /p VSDIR=<"%VSDIR_FILE%"
del "%VSDIR_FILE%"
call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat" >nul 2>nul
:run
%*
