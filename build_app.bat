@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================
rem CONFIG — adjust if needed
rem ============================
set "MODULE_NAME=JGUIBatchTranslator"
set "MAIN_CLASS=JGUIBatchTranslator.runtime.Main"                 rem default; script will auto-detect lower-case too
set "SRC_ROOT=src"
set "MODULE_DIR=src\JGUIBatchTranslator"
set "MODULE_INFO=%MODULE_DIR%\module-info.java"
set "OUT_DIR=out"

rem Python worker artifacts
set "WORKER_RELEASE_DIR=release\worker"
set "WORKER_STAGE_DIR=worker"

rem ============================
rem (Re)build worker if needed
rem ============================
if /i "%~1"=="/rebuild" goto :rebuild_worker
if not exist "%WORKER_RELEASE_DIR%\InstallWorker.cmd" goto :rebuild_worker
if not exist "%WORKER_RELEASE_DIR%\translator_worker_payload.zip" goto :rebuild_worker
if not exist "%WORKER_RELEASE_DIR%\VERSION.txt" goto :rebuild_worker
goto :stage_worker

:rebuild_worker
echo [WORKER] Building Python worker...
call build_worker.bat
if errorlevel 1 (
  echo [ERROR] build_worker.bat failed
  exit /b 1
)

:stage_worker
echo [STAGE] Preparing worker payload...
if not exist "%WORKER_STAGE_DIR%" mkdir "%WORKER_STAGE_DIR%"
for %%F in (InstallWorker.cmd translator_worker_payload.zip VERSION.txt) do (
  if exist "%WORKER_RELEASE_DIR%\%%F" (
    copy /y "%WORKER_RELEASE_DIR%\%%F" "%WORKER_STAGE_DIR%\" >nul
  ) else (
    echo [WARN] Missing "%WORKER_RELEASE_DIR%\%%F"
  )
)

rem ============================
rem Modular compile (JPMS)
rem ============================
if not exist "%MODULE_INFO%" (
  echo [ERROR] %MODULE_INFO% not found. Expected JPMS layout:
  echo         src\JGUIBatchTranslator\module-info.java
  echo         src\JGUIBatchTranslator\runtime\*.java
  exit /b 1
)

if exist "%OUT_DIR%" rmdir /s /q "%OUT_DIR%"
mkdir "%OUT_DIR%"

set "SRCLIST=%OUT_DIR%\sources.txt"
if exist "%SRCLIST%" del "%SRCLIST%" >nul 2>&1

rem Collect all sources under the module (exclude module-info.java)
for /r "%MODULE_DIR%" %%F in (*.java) do (
  if /i not "%%~nxF"=="module-info.java" echo %%F>>"%SRCLIST%"
)

if not exist "%SRCLIST%" (
  echo [ERROR] No Java sources found under %MODULE_DIR%
  exit /b 1
)

echo [JAVAC] Compiling module to %OUT_DIR% ...
javac -encoding UTF-8 ^
  --module-source-path "%SRC_ROOT%" ^
  -d "%OUT_DIR%" ^
  "%MODULE_INFO%" @"%SRCLIST%"

if errorlevel 1 (
  echo [ERROR] javac failed.
  exit /b 1
)

rem ============================
rem Auto-detect main class case (Main vs main)
rem ============================
set "DETECTED_MAIN=%MAIN_CLASS%"
if exist "%OUT_DIR%\%MODULE_NAME%\runtime\Main.class" set "DETECTED_MAIN=runtime.Main"
if exist "%OUT_DIR%\%MODULE_NAME%\runtime\main.class" set "DETECTED_MAIN=runtime.main"

echo [RUN] java --module-path "%OUT_DIR%" -m %MODULE_NAME%/%DETECTED_MAIN%
echo.
java --module-path "%OUT_DIR%" -m %MODULE_NAME%/%DETECTED_MAIN%

endlocal
