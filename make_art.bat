@echo off
rem Double-click this while Forge is open (started with --api). It makes the game's sprites into art\generated\.
cd /d "%~dp0"
set "PY="

rem 1. a path saved from an earlier run
if exist "tools\art\python_path.txt" set /p PY=<"tools\art\python_path.txt"
if defined PY if exist "%PY%" goto run
set "PY="

rem 2. Forge's own Python, in the usual places (and one folder deeper)
for %%D in ("%USERPROFILE%\Downloads" "%USERPROFILE%\Desktop" "%OneDrive%\Desktop" "%USERPROFILE%\Documents" "%OneDrive%\Documents" "%USERPROFILE%" "C:\" "D:\" "E:\") do (
  for /d %%A in ("%%~D\webui_forge*") do if exist "%%~A\system\python\python.exe" set "PY=%%~A\system\python\python.exe"
  for /d %%B in ("%%~D\*") do for /d %%A in ("%%~B\webui_forge*") do if exist "%%~A\system\python\python.exe" set "PY=%%~A\system\python\python.exe"
)
if defined PY goto save

rem 3. search the whole user folder (takes a moment)
echo Looking for Forge's Python...
for /f "delims=" %%P in ('where /r "%USERPROFILE%" python.exe 2^>nul ^| findstr /i "webui_forge" ^| findstr /i "system\\python\\python.exe"') do if not defined PY set "PY=%%P"
if defined PY goto save

rem 4. ask
echo.
echo Could not find Forge's Python. Open your Forge folder, go into "system" then "python",
echo drag python.exe into this window and press Enter:
set /p PY=
set PY=%PY:"=%
if not exist "%PY%" (
  echo That file does not exist: %PY%
  pause
  exit /b 1
)

:save
> "tools\art\python_path.txt" echo %PY%

:run
echo Using %PY%
"%PY%" tools\art\forge_batch.py %*
echo.
pause
