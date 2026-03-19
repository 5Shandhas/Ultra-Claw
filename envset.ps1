# 设置编码防乱码
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 1. 动态获取路径
# $env:USERPROFILE 会自动解析为 C:\Users\你的当前用户名
$UCLAW_HOME = Join-Path $env:USERPROFILE ".uclaw"

# 自动定位 Node.js 目录 (假设脚本在 U 盘根目录，node 在 runtime\node-win-x64)
# 如果你的层级不同，请微调这里的 "runtime\node-win-x64"
$NODE_DIR = Join-Path $PSScriptRoot "runtime\node-win-x64"
$NODE_EXE = Join-Path $NODE_DIR "node.exe"

# 检查 Node 是否存在
if (-not (Test-Path $NODE_EXE)) {
    Write-Host "`n [!] 错误: 找不到 Node.js 运行环境！" -ForegroundColor Red
    Write-Host " 期望路径: $NODE_DIR" -ForegroundColor Gray
    Read-Host " 按回车键退出..."
    exit
}

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Ultra-Claw 环境配置与启动助手" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 检测到配置文件目录: $UCLAW_HOME" -ForegroundColor Gray
Write-Host " 检测到 Node.js 目录: $NODE_DIR" -ForegroundColor Gray
Write-Host "----------------------------------------"
Write-Host " [1] 临时运行 (便携模式：关闭窗口后环境失效，不留痕迹)"
Write-Host " [2] 永久安装 (本地模式：写入系统环境变量，以后可随处使用命令)"
Write-Host " [0] 退出"
Write-Host "----------------------------------------"

$choice = Read-Host " 请选择运行模式"

switch ($choice) {
    "1" {
        Write-Host "`n >> 正在应用临时环境变量..." -ForegroundColor Yellow
        # 仅修改当前进程 (Process) 的 PATH
        $env:PATH = "$NODE_DIR;$env:PATH"
        $env:OPENCLAW_HOME = $UCLAW_HOME
        Write-Host " >> 临时环境就绪！" -ForegroundColor Green
    }
    "2" {
        Write-Host "`n >> 正在写入系统用户环境变量..." -ForegroundColor Yellow
        
        # 获取当前用户的永久 PATH
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        
        # 检查是否已经存在，避免重复添加
        if ($userPath -notmatch [regex]::Escape($NODE_DIR)) {
            $newPath = $userPath
            if (-not $newPath.EndsWith(";")) { $newPath += ";" }
            $newPath += $NODE_DIR
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
            Write-Host " [+] Node.js 路径已永久加入用户 PATH" -ForegroundColor Green
        } else {
            Write-Host " [-] Node.js 路径已存在于环境变量中，无需重复添加" -ForegroundColor Gray
        }

        # 永久写入 OPENCLAW_HOME
        [Environment]::SetEnvironmentVariable("OPENCLAW_HOME", $UCLAW_HOME, "User")
        Write-Host " [+] OPENCLAW_HOME 已永久写入" -ForegroundColor Green

        # 为了让当前窗口立刻能用，也同步更新临时变量
        $env:PATH = "$NODE_DIR;$env:PATH"
        $env:OPENCLAW_HOME = $UCLAW_HOME
        
        Write-Host "`n 注意：永久环境变量已生效！" -ForegroundColor Cyan
        Write-Host " 如果要在其他新的 cmd 或 PowerShell 窗口中使用，请确保新建窗口。" -ForegroundColor Gray
    }
    "0" { exit }
    Default { 
        Write-Host " 无效选择，脚本退出。" -ForegroundColor Red
        exit 
    }
}

# --- 测试与启动逻辑 ---
Write-Host "`n----------------------------------------"
$nodeVer = node -v
Write-Host " 当前 Node.js 版本: $nodeVer" -ForegroundColor Green

# 启动 OpenClaw 网关的逻辑 (请根据你的实际 openclaw.mjs 位置调整)
$ENTRY = Join-Path $PSScriptRoot "core\node_modules\openclaw\openclaw.mjs"

if (Test-Path $ENTRY) {
    Write-Host " 正在启动 OpenClaw..." -ForegroundColor Yellow
    # 这里的参数你可以根据需要修改
    node "$ENTRY" gateway run --allow-unconfigured
} else {
    Write-Host " [!] 未找到 OpenClaw 入口文件，已为您保留命令行窗口。" -ForegroundColor Yellow
    Write-Host " 您现在可以直接输入 node 或 openclaw 等命令。" -ForegroundColor Gray
    powershell # 停留在当前配置好环境的 PS 窗口
}