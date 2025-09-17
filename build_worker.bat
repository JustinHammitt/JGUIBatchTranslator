@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM =======================
REM CONFIG
REM =======================
set APP_NAME=translator_worker
set APP_VERSION=1.0.0
set PYI=pyinstaller.exe
set PYTHON=python
REM Where worker will be installed on end-user machines:
set INSTALL_SUBDIR=GUIBatchTranslator\translator_worker

REM =======================
REM CLEAN
REM =======================
echo [CLEAN] Removing old build artifacts...
if exist build rmdir /s /q build
if exist dist rmdir /s /q dist
if exist release\worker rmdir /s /q release\worker
mkdir release\worker

REM =======================
REM BUILD (ONEDIR) — lean worker, no GUI libs
REM =======================
echo [BUILD] PyInstaller ONEDIR: %APP_NAME%.py
%PYI% ^
  %APP_NAME%.py ^
  --name "%APP_NAME%" ^
  --onedir ^
  --noconsole ^
  --clean ^
  --noupx ^
  --exclude-module PyQt5 ^
  --exclude-module PyQt6 ^
  --exclude-module PySide2 ^
  --exclude-module PySide6 ^
  --collect-submodules argostranslate ^
  --collect-submodules argos_translate_files ^
  --collect-data sentencepiece ^
  --collect-binaries ctranslate2

if ERRORLEVEL 1 (
  echo [ERROR] PyInstaller build failed.
  exit /b 1
)

if not exist "dist\%APP_NAME%\%APP_NAME%.exe" (
  echo [ERROR] dist\%APP_NAME%\%APP_NAME%.exe not found.
  exit /b 1
)

REM =======================
REM MODELS — copy from repo root into ONEDIR
REM Expect your repo has: .\Models\*.argosmodel
REM =======================
if not exist "dist\%APP_NAME%\Models" mkdir "dist\%APP_NAME%\Models"

if exist "Models\" (
  echo [MODELS] Copying repo Models\ -> dist\%APP_NAME%\Models\
  robocopy "Models" "dist\%APP_NAME%\Models" /E /NFL /NDL /NJH /NJS >nul
) else (
  echo [WARN] No repo .\Models\ folder found. Worker will build without models.
)

for %%F in (*.argosmodel) do (
  echo [MODELS] Adding loose model %%F -> dist\%APP_NAME%\Models\
  copy /y "%%F" "dist\%APP_NAME%\Models\" >nul
)

REM =======================
REM PACK — create single ZIP payload
REM =======================
echo [PACK] Creating ZIP payload...
powershell -NoProfile -Command ^
  "Compress-Archive -Path 'dist\%APP_NAME%\*' -DestinationPath 'release\worker\%APP_NAME%_payload.zip' -Force"
if ERRORLEVEL 1 (
  echo [ERROR] Compress-Archive failed.
  exit /b 1
)

REM =======================
REM INSTALL SCRIPT — expands once to LocalAppData and writes .version
REM =======================
echo [EMIT] Writing release\worker\InstallWorker.cmd
(
  echo @echo off
  echo setlocal
  echo set "APP=%APP_NAME%"
  echo set "VERSION=%APP_VERSION%"
  echo set "INSTALL=%%LOCALAPPDATA%%\%INSTALL_SUBDIR%"
  echo set "ZIP=%%~dp0%APP_NAME%_payload.zip"
  echo set "EXE=%%INSTALL%%\%APP%.exe"
  echo set "VERFILE=%%INSTALL%%\.version"
  echo.
  echo if exist "%%EXE%%" if exist "%%VERFILE%%" ^
    for /f "usebackq delims=" %%%%V in ("%%VERFILE%%") do ^
      if /i "%%%%V"=="%%VERSION%%" goto run
  echo.
  echo echo [INSTALL] Extracting payload to "%%INSTALL%%"...
  echo rmdir /s /q "%%INSTALL%%" 2^>nul
  echo mkdir "%%INSTALL%%" 2^>nul
  echo powershell -NoProfile -ExecutionPolicy Bypass ^
  echo ^  -Command "Expand-Archive -LiteralPath '%%ZIP%%' -DestinationPath '%%INSTALL%%' -Force"
  echo if ERRORLEVEL 1 (
  echo   echo [ERROR] Extraction failed.
  echo   exit /b 1
  echo )
  echo > "%%VERFILE%%" echo %%VERSION%%
  echo.
  echo :run
  echo echo [RUN] Starting %%EXE%%
  echo start "" "%%EXE%%"
  echo endlocal
) > "release\worker\InstallWorker.cmd"

REM (Optional) checksum
where certutil >nul 2>&1
if %ERRORLEVEL%==0 (
  certutil -hashfile "release\worker\%APP_NAME%_payload.zip" SHA256 > "release\worker\%APP_NAME%_payload.sha256.txt"
  certutil -hashfile "release\worker\InstallWorker.cmd" SHA256 > "release\worker\InstallWorker.sha256.txt"
)

echo.
echo [DONE]
echo Ship these two files to install the Python worker:
echo   release\worker\InstallWorker.cmd
echo   release\worker\%APP_NAME%_payload.zip
echo.
echo Java should run InstallWorker.cmd once (if worker not found), then execute:
echo   %%LOCALAPPDATA%%\%INSTALL_SUBDIR%\%APP_NAME%.exe
echo.
pause
endlocal
