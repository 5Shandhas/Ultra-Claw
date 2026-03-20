$ErrorActionPreference = "Stop"

$ROOT = $PSScriptRoot
$APP_DIR = Join-Path $ROOT "app"
$CORE_DIR = Join-Path $APP_DIR "core"
$DATA_DIR = Join-Path $ROOT "data"
$STATE_DIR = Join-Path $DATA_DIR ".openclaw"
$NODE_BIN = Join-Path $APP_DIR "runtime\node-win-x64\node.exe"
$OPENCLAW_MJS = Join-Path $CORE_DIR "node_modules\openclaw\openclaw.mjs"

if (-not (Test-Path $NODE_BIN)) {
    Write-Host "Node.js runtime not found: $NODE_BIN" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $OPENCLAW_MJS)) {
    Write-Host "OpenClaw entrypoint not found: $OPENCLAW_MJS" -ForegroundColor Red
    exit 1
}

$env:OPENCLAW_HOME = $DATA_DIR
$env:OPENCLAW_STATE_DIR = $STATE_DIR
$env:OPENCLAW_CONFIG_PATH = Join-Path $STATE_DIR "openclaw.json"
if ($env:PATH -notlike "*$($APP_DIR)\runtime\node-win-x64*") {
    $env:PATH = "$(Join-Path $APP_DIR 'runtime\node-win-x64');$env:PATH"
}

& $NODE_BIN $OPENCLAW_MJS @args
exit $LASTEXITCODE
