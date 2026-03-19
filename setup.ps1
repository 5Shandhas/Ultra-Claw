# Ultra-Claw Portable Setup for Windows
# 创建完全自包含的便携版本

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Ultra-Claw Complete Portable Setup" -ForegroundColor Cyan
Write-Host "  创建完全便携版本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 设置目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$appDir = Join-Path $scriptDir "app"
$coreDir = Join-Path $appDir "core"
$runtimeDir = Join-Path $appDir "runtime"
$nodeTarget = Join-Path $runtimeDir "node-win-x64"
$dataDir = Join-Path $scriptDir "data"

# 镜像设置
$mirror = "https://registry.npmmirror.com"
$nodeMirror = "https://npmmirror.com/mirrors/node"
$nodeVersion = "v24.14.0"

# [1] 创建目录结构
Write-Host "[1/6] 创建目录结构..." -ForegroundColor Yellow
if (Test-Path $appDir) {
    Write-Host "  删除旧的app目录..." -ForegroundColor Gray
    Remove-Item -Path $appDir -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $appDir -Force | Out-Null
New-Item -ItemType Directory -Path $coreDir -Force | Out-Null
New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
New-Item -ItemType Directory -Path $nodeTarget -Force | Out-Null
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
Write-Host "  目录结构创建完成" -ForegroundColor Green

# [2] 下载Node.js运行时
Write-Host ""
Write-Host "[2/6] 下载Node.js运行时 ($nodeVersion)..." -ForegroundColor Yellow
$zipName = "node-$nodeVersion-win-x64.zip"
$nodeUrl = "$nodeMirror/$nodeVersion/$zipName"
$tempZip = Join-Path $env:TEMP $zipName

Write-Host "  下载地址: $nodeUrl" -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri $nodeUrl -OutFile $tempZip -ErrorAction Stop
    Write-Host "  下载成功" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: 下载失败 - $_" -ForegroundColor Red
    exit 1
}

# [3] 解压Node.js
Write-Host "  解压中..." -ForegroundColor Gray
try {
    Expand-Archive -Path $tempZip -DestinationPath "$env:TEMP\node-extract" -Force
    $extractDir = Join-Path "$env:TEMP\node-extract" "node-$nodeVersion-win-x64"
    Copy-Item -Path "$extractDir\*" -Destination $nodeTarget -Recurse -Force
    Remove-Item -Path "$env:TEMP\node-extract" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
    Write-Host "  解压完成" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: 解压失败 - $_" -ForegroundColor Red
    exit 1
}

# 验证Node.js
if (Test-Path (Join-Path $nodeTarget "node.exe")) {
    Write-Host "  Node.js运行时安装成功！" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Node.js文件缺失" -ForegroundColor Red
    exit 1
}

# [4] 创建OpenClaw配置文件
Write-Host ""
Write-Host "[3/6] 创建OpenClaw配置文件..." -ForegroundColor Yellow
$packageJson = @"
{
  "name": "ultra-claw-core",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "openclaw": "latest"
  }
}
"@
$packageJson | Out-File -FilePath (Join-Path $coreDir "package.json") -Encoding UTF8
Write-Host "  配置文件创建完成" -ForegroundColor Green

# [5] 安装OpenClaw
Write-Host ""
Write-Host "[4/6] 安装OpenClaw核心依赖..." -ForegroundColor Yellow
$nodeBin = Join-Path $nodeTarget "node.exe"
$npmBin = Join-Path $nodeTarget "npm.cmd"

Set-Location $coreDir
Write-Host "  使用国内镜像安装，请稍候..." -ForegroundColor Gray

$env:Path = "$nodeTarget;$env:Path"
& $npmBin install --registry=$mirror --loglevel=error

if (Test-Path (Join-Path $coreDir "node_modules\openclaw\openclaw.mjs")) {
    Write-Host "  OpenClaw安装成功！" -ForegroundColor Green
} else {
    Write-Host "  ERROR: OpenClaw安装失败" -ForegroundColor Red
    exit 1
}

# [6] 安装QQ插件（可选）
Write-Host ""
Write-Host "[5/6] 安装QQ插件（可选）..." -ForegroundColor Yellow
& $npmBin install @sliverp/qqbot@latest --registry=$mirror --loglevel=error 2>$null
Write-Host "  QQ插件安装完成（如失败可忽略）" -ForegroundColor Green

# [7] 复制中国优化技能
Write-Host ""
Write-Host "[6/6] 复制中国优化技能..." -ForegroundColor Yellow
$skillsCn = Join-Path $scriptDir "skills-cn"
$skillsTarget = Join-Path $coreDir "node_modules\openclaw\skills"

if (Test-Path $skillsCn -PathType Container) {
    if (Test-Path $skillsTarget -PathType Container) {
        $skillCount = 0
        Get-ChildItem -Path $skillsCn -Directory | ForEach-Object {
            $skillName = $_.Name
            $targetPath = Join-Path $skillsTarget $skillName
            if (-not (Test-Path $targetPath)) {
                Copy-Item -Path $_.FullName -Destination $targetPath -Recurse -Force
                $skillCount++
            }
        }
        Write-Host "  复制了$skillCount个中国优化技能" -ForegroundColor Green
    }
}

# 创建数据目录结构
Write-Host ""
Write-Host "创建数据目录结构..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path (Join-Path $dataDir ".openclaw") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $dataDir "memory") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $dataDir "backups") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $dataDir "logs") -Force | Out-Null

# 创建默认配置文件
$defaultConfig = @'
{"gateway":{"mode":"local","auth":{"token":"goodforstart"}}}
'@
$defaultConfig | Out-File -FilePath (Join-Path $dataDir ".openclaw\openclaw.json") -Encoding UTF8
Write-Host "  默认配置文件创建完成" -ForegroundColor Green

# 显示完成信息
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  安装完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 计算文件大小
$totalSize = (Get-ChildItem -Path $appDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
$sizeMB = [math]::Round($totalSize / 1MB, 2)

Write-Host "目录结构:" -ForegroundColor Cyan
Write-Host "  $appDir\core\" -ForegroundColor Gray
Write-Host "  $appDir\runtime\" -ForegroundColor Gray
Write-Host "  $dataDir\" -ForegroundColor Gray
Write-Host ""
Write-Host "文件大小: ${sizeMB}MB" -ForegroundColor Cyan
Write-Host ""
Write-Host "启动方式:" -ForegroundColor Cyan
Write-Host "  1. 双击 Windows-Start.bat" -ForegroundColor Gray
Write-Host "  2. 或运行: Windows-Start.bat" -ForegroundColor Gray
Write-Host ""
Write-Host "首次运行时会:" -ForegroundColor Cyan
Write-Host "  - 启动OpenClaw网关" -ForegroundColor Gray
Write-Host "  - 如果已配置模型，将自动打开 Dashboard" -ForegroundColor Gray
Write-Host "  - 如果还没配置模型，请运行 uclaw-console.ps1 完成初始化" -ForegroundColor Gray
Write-Host ""
Write-Host "注意: 请勿关闭启动窗口，否则服务会停止" -ForegroundColor Yellow

# 询问是否启动
Write-Host ""
$start = Read-Host "现在启动Ultra-Claw便携版？(y/n)"
if ($start -eq 'y') {
    Write-Host "启动Ultra-Claw便携版..." -ForegroundColor Green
    Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $scriptDir "windows-start.ps1")
    )
}

Write-Host ""
Write-Host "安装完成！按任意键退出..." -ForegroundColor Gray
pause
