$OutputEncoding = [System.Text.Encoding]::UTF8
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
}
$ErrorActionPreference = 'Continue'

Write-Host "`n ========================================" -ForegroundColor Cyan
Write-Host "   Ultra-Claw v1.1 - Portable AI Agent (PS)" -ForegroundColor Cyan
Write-Host " ========================================`n" -ForegroundColor Cyan

$UCLAW_DIR = $PSScriptRoot
$APP_DIR = Join-Path $UCLAW_DIR 'app'
$CORE_DIR = Join-Path $APP_DIR 'core'
$DATA_DIR = Join-Path $UCLAW_DIR 'data'
$STATE_DIR = Join-Path $DATA_DIR '.openclaw'
$NODE_DIR = Join-Path $APP_DIR 'runtime\node-win-x64'
$NODE_BIN = Join-Path $NODE_DIR 'node.exe'
$NPM_BIN = Join-Path $NODE_DIR 'npm.cmd'

$env:OPENCLAW_HOME = $DATA_DIR
$env:OPENCLAW_STATE_DIR = $STATE_DIR
$env:OPENCLAW_CONFIG_PATH = Join-Path $STATE_DIR 'openclaw.json'
$env:PATH = "$NODE_DIR;$($NODE_DIR)\node_modules\.bin;$env:PATH"

if ((Test-Path "$APP_DIR\core-win") -and (-not (Test-Path $CORE_DIR))) {
    Rename-Item "$APP_DIR\core-win" 'core'
}

if (-not (Test-Path $NODE_BIN)) {
    Write-Host "[ERROR] Node.js runtime not found at $NODE_BIN" -ForegroundColor Red
    Pause
    exit 1
}

$NODE_VER = & $NODE_BIN --version
Write-Host "   Node.js: $NODE_VER"

$dirs = @($DATA_DIR, $STATE_DIR, "$DATA_DIR\memory", "$DATA_DIR\backups", "$DATA_DIR\logs")
foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}

$configPath = $env:OPENCLAW_CONFIG_PATH
if (-not (Test-Path $configPath)) {
    Write-Host "   First run - creating default config..."
    $defaultConfig = @{ gateway = @{ mode = 'local'; auth = @{ token = 'goodforstart'; mode = 'token' } } }
    $defaultConfig | ConvertTo-Json -Depth 20 | Set-Content $configPath -Encoding UTF8
    Write-Host "   Config created`n"
}

if (-not (Test-Path "$CORE_DIR\node_modules")) {
    Write-Host "   First run - installing dependencies..."
    Write-Host "   Using China mirror, please wait...`n"
    Set-Location $CORE_DIR
    & $NPM_BIN install --registry=https://registry.npmmirror.com
    Write-Host "`n   Dependencies installed!`n"
}

$PORT = 18789
while ($true) {
    $portUsed = Get-NetTCPConnection -LocalPort $PORT -ErrorAction SilentlyContinue
    if (-not $portUsed) { break }
    Write-Host "   Port $PORT in use, trying next..."
    $PORT++
    if ($PORT -gt 18799) {
        Write-Host 'No available port 18789-18799' -ForegroundColor Red
        Pause
        exit 1
    }
}

$TOKEN = 'goodforstart'
$HAS_MODEL = $false
try {
    if (Test-Path $configPath) {
        $configJson = Get-Content $configPath -Raw | ConvertFrom-Json
        if ($configJson.gateway -and $configJson.gateway.auth -and $configJson.gateway.auth.token) {
            $TOKEN = [string]$configJson.gateway.auth.token
        }
        if ($configJson.agents -and $configJson.agents.defaults -and $configJson.agents.defaults.model -and $configJson.agents.defaults.model.primary) {
            $HAS_MODEL = $true
        } elseif ($configJson.models -and $configJson.models.providers -and $configJson.models.providers.PSObject.Properties.Count -gt 0) {
            $HAS_MODEL = $true
        }
    }
} catch {
    $TOKEN = 'goodforstart'
}

Write-Host "   Starting OpenClaw on port $PORT..."
Write-Host "   DO NOT close this window while using Ultra-Claw!`n"
if (-not $HAS_MODEL) {
    Write-Host '   No model config detected yet.' -ForegroundColor Yellow
    Write-Host '   Please run uclaw-console.ps1 to finish initialization.' -ForegroundColor Yellow
    Write-Host ''
}

if ($HAS_MODEL) {
    Start-Job -ScriptBlock {
        param($p, $t)
        Start-Sleep -Seconds 3
        $url = "http://127.0.0.1:$p/#token=$t"
        Start-Process $url
    } -ArgumentList $PORT, $TOKEN | Out-Null
}

Set-Location $CORE_DIR
$OPENCLAW_MJS = Join-Path $CORE_DIR 'node_modules\openclaw\openclaw.mjs'
$logPath = Join-Path $DATA_DIR 'logs\gateway.log'
Write-Host "   Log: $logPath"

& $NODE_BIN "$OPENCLAW_MJS" gateway run --allow-unconfigured --force --port $PORT 2>&1 | ForEach-Object {
    if ($_ -is [System.Management.Automation.ErrorRecord]) {
        Write-Host $_.Exception.Message -ForegroundColor Gray
        $_.Exception.Message | Out-File -FilePath $logPath -Append
    } else {
        Write-Host $_
        $_ | Out-File -FilePath $logPath -Append
    }
}

Write-Host "`n   OpenClaw stopped."
Pause