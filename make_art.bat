@echo off
rem Double-click this while Forge is open (started with --api). It makes the game's sprites into art\generated\.
cd /d "%~dp0"
set "PY="
for %%D in ("%USERPROFILE%\Downloads" "%USERPROFILE%\Desktop" "%USERPROFILE%\Documents" "%USERPROFILE%" "C:\" "D:\") do (
  if not defined PY if exist "%%~D\webui_forge_cu121_torch231\system\python\python.exe" set "PY=%%~D\webui_forge_cu121_torch231\system\python\python.exe"
)
if not defined PY where py >nul 2>nul && set "PY=py"
if not defined PY where python >nul 2>nul && set "PY=python"
if not defined PY (
  echo Could not find Python. Drag python.exe from your Forge folder ^(system\python^) into this window and press Enter:
  set /p PY=
)
"%PY%" tools\art\forge_batch.py %*
echo.
pause
