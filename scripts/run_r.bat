@echo off
rem ============================================================================
rem run_r.bat — Windows wrapper around Rscript.exe.
rem
rem Usage:
rem   scripts\run_r.bat <path\to\file.R> [<log\path.log>]
rem ============================================================================

setlocal enabledelayedexpansion

if "%~1"=="" (
  echo usage: scripts\run_r.bat ^<path\to\file.R^> [^<log\path.log^>]
  exit /b 1
)

set "RFILE=%~1"
set "LOG_PATH=%~2"

if not exist "%RFILE%" (
  echo error: R script not found: %RFILE%
  exit /b 3
)

rem --- Derive log path if not given -------------------------------------------
if "%LOG_PATH%"=="" (
  set "REL=%RFILE%"
  set "REL=!REL:R\=!"
  set "REL=!REL:.R=!"
  set "REL=!REL:\=_!"
  set "LOG_PATH=logs\!REL!.log"
)

rem --- Ensure log directory exists --------------------------------------------
for %%I in ("%LOG_PATH%") do set "LOG_DIR=%%~dpI"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

rem --- Locate Rscript ---------------------------------------------------------
where Rscript.exe >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
  echo error: Rscript.exe not found on PATH
  echo        install R or add its bin\ directory to PATH; see CLAUDE.md prerequisites.
  exit /b 2
)

set "R_EXTRA_LOG=%LOG_PATH:.log=_console.log%"

echo [run_r] script:    %RFILE%
echo [run_r] log:       %LOG_PATH%
echo [run_r] console:   %R_EXTRA_LOG%
echo [run_r] starting:  %DATE% %TIME%

Rscript.exe --no-save --no-restore "%RFILE%" > "%R_EXTRA_LOG%" 2>&1
set "RC=%ERRORLEVEL%"

echo [run_r] exit:      %RC%
echo [run_r] finished:  %DATE% %TIME%

if %RC% NEQ 0 (
  echo [run_r] --- last 30 lines of %LOG_PATH% ---
  if exist "%LOG_PATH%" (
    powershell -NoProfile -Command "Get-Content -Path '%LOG_PATH%' -Tail 30"
  ) else (
    echo [run_r] (start_log() log not produced; see %R_EXTRA_LOG%)
    powershell -NoProfile -Command "Get-Content -Path '%R_EXTRA_LOG%' -Tail 30"
  )
)

exit /b %RC%
