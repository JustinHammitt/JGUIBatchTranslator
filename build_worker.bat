@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM =======================
REM CONFIG
REM =======================
set APP_NAME=translator_worker
set "APP_VERSION=1.0.1"
for /f "tokens=1-3 delims=/- " %%a in ("%date%") do set "YYYY=%%c" & set "MM=00%%a" & set "DD=00%%b"
set "MM=%MM:~-2%" & set "DD=%DD:~-2%"
for /f "tokens=1-3 delims=:." %%h in ("%time%") do set "HH=0%%h" & set "NN=0%%i" & set "SS=0%%j"
set "HH=%HH:~-2%" & set "NN=%NN:~-2%" & set "SS=%SS:~-2%"
> release\worker\VERSION.txt echo %APP_VERSION%+%YYYY%%MM%%DD%-%HH%%NN%%SS%

set WORKER_SRC=python\translator_worker.py
set PYI=pyinstaller.exe
set PYTHON=python
REM Where the worker will live on user machines:
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
REM BUILD (ONEDIR)
REM =======================
if not exist "%WORKER_SRC%" (
  echo [ERROR] %WORKER_SRC% not found.
  exit /b 1
)
echo [BUILD] PyInstaller ONEDIR: %WORKER_SRC%
%PYI% ^
  "%WORKER_SRC%" ^
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
REM MODELS — copy from repo 'Models\' OR 'python\Models\'
REM =======================
if not exist "dist\%APP_NAME%\Models" mkdir "dist\%APP_NAME%\Models"

if exist "Models\" (
  echo [MODELS] Copying .\Models\ -> dist\%APP_NAME%\Models\
  robocopy "Models" "dist\%APP_NAME%\Models" /E /NFL /NDL /NJH /NJS >nul
) else if exist "python\Models\" (
  echo [MODELS] Copying .\python\Models\ -> dist\%APP_NAME%\Models\
  robocopy "python\Models" "dist\%APP_NAME%\Models" /E /NFL /NDL /NJH /NJS >nul
) else (
  echo [WARN] No Models\ folder found in repo root or python\.
)

for %%F in (*.argosmodel) do (
  echo [MODELS] Adding loose model %%F -> dist\%APP_NAME%\Models\
  copy /y "%%F" "dist\%APP_NAME%\Models\" >nul
)

REM =======================
REM PACK — create single ZIP payload
REM =======================
echo %APP_VERSION%> release\worker\VERSION.txt

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
> "release\worker\InstallWorker.cmd" echo @echo off
>> "release\worker\InstallWorker.cmd" echo setlocal EnableExtensions
>> "release\worker\InstallWorker.cmd" echo set "APP_DIR=%%LOCALAPPDATA%%\%INSTALL_SUBDIR%"
>> "release\worker\InstallWorker.cmd" echo set "PAYLOAD=%%~dp0%APP_NAME%_payload.zip"
>> "release\worker\InstallWorker.cmd" echo set "VERFILE=%%APP_DIR%%\.version"
>> "release\worker\InstallWorker.cmd" echo set "EXE=%%APP_DIR%%\translator_worker.exe"
>> "release\worker\InstallWorker.cmd" echo set "VERSION_FILE=%%~dp0VERSION.txt"
>> "release\worker\InstallWorker.cmd" echo for /f "usebackq delims=" %%%%V in ("%%VERSION_FILE%%") do set "EXPECTED_VERSION=%%%%V"
>> "release\worker\InstallWorker.cmd" echo if exist "%%EXE%%" if exist "%%VERFILE%%" for /f "usebackq delims=" %%%%V in ("%%VERFILE%%") do if /i "%%%%V"=="%%EXPECTED_VERSION%%" goto :run
>> "release\worker\InstallWorker.cmd" echo echo [INSTALL] Extracting payload to "%%APP_DIR%%"...
>> "release\worker\InstallWorker.cmd" echo rmdir /s /q "%%APP_DIR%%" 2^>nul
>> "release\worker\InstallWorker.cmd" echo mkdir "%%APP_DIR%%" 2^>nul
>> "release\worker\InstallWorker.cmd" echo powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%%PAYLOAD%%' -DestinationPath '%%APP_DIR%%' -Force"
>> "release\worker\InstallWorker.cmd" echo if ERRORLEVEL 1 ^( echo [ERROR] Extraction failed. ^& exit /b 1 ^)
>> "release\worker\InstallWorker.cmd" echo echo %%EXPECTED_VERSION%%^> "%%VERFILE%%"
>> "release\worker\InstallWorker.cmd" echo :run
>> "release\worker\InstallWorker.cmd" echo echo [RUN] Starting %%EXE%%
>> "release\worker\InstallWorker.cmd" echo start "" "%%EXE%%"
>> "release\worker\InstallWorker.cmd" echo endlocal


REM (Optional) checksums
where certutil >nul 2>&1
if %ERRORLEVEL%==0 (
  certutil -hashfile "release\worker\%APP_NAME%_payload.zip" SHA256 > "release\worker\%APP_NAME%_payload.sha256.txt"
  certutil -hashfile "release\worker\InstallWorker.cmd" SHA256 > "release\worker\InstallWorker.sha256.txt"
)

echo.
echo [DONE]
echo Ship these to install the Python worker:
echo   release\worker\InstallWorker.cmd
echo   release\worker\%APP_NAME%_payload.zip
echo   release\worker\VERSION.txt
echo.
echo Java should ensure the worker is installed, then spawn:
echo   %%LOCALAPPDATA%%\%INSTALL_SUBDIR%\%APP_NAME%.exe
echo.
pause
endlocal
