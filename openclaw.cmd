@echo off
setlocal

set "ROOT=%~dp0"
set "APP_DIR=%ROOT%app"
set "CORE_DIR=%APP_DIR%\core"
set "DATA_DIR=%ROOT%data"
set "STATE_DIR=%DATA_DIR%\.openclaw"
set "NODE_BIN=%APP_DIR%\runtime\node-win-x64\node.exe"
set "OPENCLAW_MJS=%CORE_DIR%\node_modules\openclaw\openclaw.mjs"

if not exist "%NODE_BIN%" (
    echo Node.js runtime not found: %NODE_BIN%
    exit /b 1
)

if not exist "%OPENCLAW_MJS%" (
    echo OpenClaw entrypoint not found: %OPENCLAW_MJS%
    exit /b 1
)

set "OPENCLAW_HOME=%DATA_DIR%"
set "OPENCLAW_STATE_DIR=%STATE_DIR%"
set "OPENCLAW_CONFIG_PATH=%STATE_DIR%\openclaw.json"
set "PATH=%APP_DIR%\runtime\node-win-x64;%PATH%"

"%NODE_BIN%" "%OPENCLAW_MJS%" %*
exit /b %errorlevel%
