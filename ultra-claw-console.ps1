$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$SCRIPT_ROOT = $PSScriptRoot
$PORTABLE_ROOT = $SCRIPT_ROOT
$PORTABLE_APP_DIR = Join-Path $PORTABLE_ROOT "app"
$PORTABLE_CORE_DIR = Join-Path $PORTABLE_APP_DIR "core"
$PORTABLE_NODE_DIR = Join-Path $PORTABLE_APP_DIR "runtime\node-win-x64"
$PORTABLE_NODE_BIN = Join-Path $PORTABLE_NODE_DIR "node.exe"
$PORTABLE_OPENCLAW_MJS = Join-Path $PORTABLE_CORE_DIR "node_modules\openclaw\openclaw.mjs"
$PORTABLE_START_SCRIPT = Join-Path $PORTABLE_ROOT "windows-start.ps1"
$PORTABLE_DIAGNOSE_SCRIPT = Join-Path $PORTABLE_ROOT "Windows-Diagnose.bat"

$MODE_CONTEXT = $null

$MODEL_TEMPLATES = @(
    [ordered]@{ Key = "1"; Name = "DeepSeek"; ProviderKey = "deepseek"; FullModel = "deepseek/deepseek-chat"; BaseUrl = "https://api.deepseek.com/v1" }
    [ordered]@{ Key = "2"; Name = "Kimi"; ProviderKey = "moonshot"; FullModel = "moonshot/moonshot-v1-auto"; BaseUrl = "https://api.moonshot.cn/v1" }
    [ordered]@{ Key = "3"; Name = "Qwen"; ProviderKey = "qwen"; FullModel = "qwen/qwen-plus"; BaseUrl = "https://dashscope.aliyuncs.com/compatible-mode/v1" }
    [ordered]@{ Key = "4"; Name = "GLM"; ProviderKey = "glm"; FullModel = "glm/glm-4-plus"; BaseUrl = "https://open.bigmodel.cn/api/paas/v4" }
    [ordered]@{ Key = "5"; Name = "MiniMax"; ProviderKey = "minimax"; FullModel = "minimax/MiniMax-Text-01"; BaseUrl = "https://api.minimax.chat/v1" }
    [ordered]@{ Key = "6"; Name = "Doubao"; ProviderKey = "doubao"; FullModel = "doubao/doubao-pro-32k"; BaseUrl = "https://ark.cn-beijing.volces.com/api/v3" }
    [ordered]@{ Key = "7"; Name = "SiliconFlow"; ProviderKey = "siliconflow"; FullModel = "siliconflow/deepseek-ai/DeepSeek-V3"; BaseUrl = "https://api.siliconflow.cn/v1" }
    [ordered]@{ Key = "8"; Name = "Claude"; ProviderKey = "anthropic"; FullModel = "anthropic/claude-3-5-sonnet-20240620" }
    [ordered]@{ Key = "9"; Name = "GPT"; ProviderKey = "openai"; FullModel = "openai/gpt-4o"; BaseUrl = "https://api.openai.com/v1" }
    [ordered]@{ Key = "10"; Name = "Ollama (Local)"; ProviderKey = "custom"; FullModel = "custom/llama3.2"; BaseUrl = "http://127.0.0.1:11434/v1"; FixedApiKey = "ollama" }
    [ordered]@{ Key = "11"; Name = "Custom OpenAI-Compatible"; ProviderKey = "custom"; FullModel = "custom/gpt-4o-mini"; BaseUrl = "https://openrouter.ai/api/v1"; IsCustom = $true }
)

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host ("=" * 44) -ForegroundColor Cyan
    Write-Host ("  " + $Text) -ForegroundColor Cyan
    Write-Host ("=" * 44) -ForegroundColor Cyan
}

function Show-Msg {
    param([string]$Text, [string]$Color = "Cyan")
    Write-Host ""
    Write-Host (">> " + $Text) -ForegroundColor $Color
}

function Pause-Return {
    Read-Host "`n按回车键继续" | Out-Null
}

function Ensure-Directory {
    param([string]$PathValue)
    if (-not (Test-Path $PathValue)) {
        New-Item -ItemType Directory -Path $PathValue -Force | Out-Null
    }
}

function Ensure-MapValue {
    param([hashtable]$Map, [string]$Key)
    if (-not $Map.ContainsKey($Key) -or $null -eq $Map[$Key] -or $Map[$Key] -isnot [System.Collections.IDictionary]) {
        $Map[$Key] = @{}
    }
    return [hashtable]$Map[$Key]
}

function ConvertTo-HashtableCompat {
    param([object]$Value)

    if ($null -eq $Value) { return $null }

    if ($Value -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $Value.Keys) {
            $result[$key] = ConvertTo-HashtableCompat $Value[$key]
        }
        return $result
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = @()
        foreach ($item in $Value) {
            $items += ,(ConvertTo-HashtableCompat $item)
        }
        return $items
    }

    if ($Value.PSObject -and $Value.PSObject.Properties.Count -gt 0 -and $Value -isnot [string]) {
        $result = @{}
        foreach ($property in $Value.PSObject.Properties) {
            $result[$property.Name] = ConvertTo-HashtableCompat $property.Value
        }
        return $result
    }

    return $Value
}

function New-ModeContext {
    param([ValidateSet('portable','installed')] [string]$Mode)

    if ($Mode -eq 'portable') {
        return [ordered]@{
            ModeName = 'Portable'
            Label = 'Portable (Current Directory)'
            RootDir = $PORTABLE_ROOT
            DataDir = Join-Path $PORTABLE_ROOT 'data'
            StateDir = Join-Path (Join-Path $PORTABLE_ROOT 'data') '.openclaw'
            ConfigPath = Join-Path (Join-Path (Join-Path $PORTABLE_ROOT 'data') '.openclaw') 'openclaw.json'
            BackupDir = Join-Path (Join-Path $PORTABLE_ROOT 'data') 'backups'
            LogPath = Join-Path (Join-Path (Join-Path $PORTABLE_ROOT 'data') 'logs') 'gateway.log'
            WorkspaceDefault = Join-Path (Join-Path $PORTABLE_ROOT 'data') 'workspace'
            StartScript = $PORTABLE_START_SCRIPT
            DiagnoseScript = $PORTABLE_DIAGNOSE_SCRIPT
            NodeDir = $PORTABLE_NODE_DIR
            NodeBin = $PORTABLE_NODE_BIN
            OpenClawMjs = $PORTABLE_OPENCLAW_MJS
            CoreDir = $PORTABLE_CORE_DIR
        }
    }

    $userHome = $env:USERPROFILE
    $installedStateDir = Join-Path $userHome '.openclaw'
    return [ordered]@{
        ModeName = 'Installed'
        Label = 'Installed (User Profile)'
        RootDir = $userHome
        DataDir = $installedStateDir
        StateDir = $installedStateDir
        ConfigPath = Join-Path $installedStateDir 'openclaw.json'
        BackupDir = Join-Path $installedStateDir 'backups'
        LogPath = Join-Path $installedStateDir 'logs\gateway.log'
        WorkspaceDefault = Join-Path $installedStateDir 'workspace'
        StartScript = $PORTABLE_START_SCRIPT
        DiagnoseScript = $PORTABLE_DIAGNOSE_SCRIPT
        NodeDir = $PORTABLE_NODE_DIR
        NodeBin = $PORTABLE_NODE_BIN
        OpenClawMjs = $PORTABLE_OPENCLAW_MJS
        CoreDir = $PORTABLE_CORE_DIR
    }
}

function Test-PortableRuntimeOrExit {
    $required = @(
        $PORTABLE_NODE_BIN,
        $PORTABLE_OPENCLAW_MJS,
        $PORTABLE_START_SCRIPT
    )

    $missing = @($required | Where-Object { -not (Test-Path $_) })
    if ($missing.Count -gt 0) {
        Write-Host "" 
        Write-Host "当前目录中的便携版运行环境不完整。" -ForegroundColor Red
        Write-Host "缺少文件：" -ForegroundColor Red
        foreach ($item in $missing) {
            Write-Host (" - {0}" -f $item) -ForegroundColor Red
        }
        exit 1
    }
}

function Set-ModeContext {
    param([hashtable]$Context)
    $script:MODE_CONTEXT = $Context
    $env:OPENCLAW_HOME = $Context.DataDir
    $env:OPENCLAW_STATE_DIR = $Context.StateDir
    $env:OPENCLAW_CONFIG_PATH = $Context.ConfigPath
    if ($env:PATH -notlike "*$($Context.NodeDir)*") {
        $env:PATH = "$($Context.NodeDir);$env:PATH"
    }
}

function Select-Mode {
    while ($true) {
        Clear-Host
        Write-Section '选择模式'
        Write-Host ' [1] 便携版 - 当前目录'
        Write-Host ' [2] 安装版 - 用户目录'
        Write-Host ' [0] 退出'
        $choice = Read-Host "`n请选择模式"
        switch ($choice) {
            '1' { return New-ModeContext 'portable' }
            '2' { return New-ModeContext 'installed' }
            '0' { exit 0 }
            default { }
        }
    }
}

function New-DefaultConfig {
    $ctx = $script:MODE_CONTEXT
    return [ordered]@{
        gateway = [ordered]@{
            mode = 'local'
            auth = [ordered]@{
                mode = 'token'
                token = 'goodforstart'
            }
        }
        models = [ordered]@{
            mode = 'merge'
            providers = @{}
        }
        agents = [ordered]@{
            defaults = [ordered]@{
                model = [ordered]@{}
                models = @{}
                workspace = $ctx.WorkspaceDefault
            }
        }
        channels = @{}
        tools = [ordered]@{
            profile = 'full'
        }
    }
}

function Ensure-ConfigShape {
    param([hashtable]$Config)

    $ctx = $script:MODE_CONTEXT
    $gateway = Ensure-MapValue $Config 'gateway'
    $auth = Ensure-MapValue $gateway 'auth'
    if (-not $auth['mode']) { $auth['mode'] = 'token' }
    if (-not $auth['token']) { $auth['token'] = 'goodforstart' }
    if (-not $gateway['mode']) { $gateway['mode'] = 'local' }

    $models = Ensure-MapValue $Config 'models'
    if (-not $models['mode']) { $models['mode'] = 'merge' }
    $providers = Ensure-MapValue $models 'providers'

    $agents = Ensure-MapValue $Config 'agents'
    $defaults = Ensure-MapValue $agents 'defaults'
    $defaultModel = Ensure-MapValue $defaults 'model'
    $defaultModels = Ensure-MapValue $defaults 'models'
    if (-not $defaults['workspace']) { $defaults['workspace'] = $ctx.WorkspaceDefault }

    [void](Ensure-MapValue $Config 'channels')
    $tools = Ensure-MapValue $Config 'tools'
    if (-not $tools['profile']) { $tools['profile'] = 'full' }

    if ($Config.ContainsKey('agent') -and $Config['agent'] -is [System.Collections.IDictionary]) {
        $legacyAgent = [hashtable]$Config['agent']
        if ($legacyAgent['model'] -and -not $defaultModel['primary']) {
            $defaultModel['primary'] = [string]$legacyAgent['model']
            $defaultModels[[string]$legacyAgent['model']] = [ordered]@{
                alias = [string]$legacyAgent['model']
            }
        }
        if ($legacyAgent['workspace'] -and -not $defaults['workspace']) {
            $defaults['workspace'] = [string]$legacyAgent['workspace']
        }
        if ($legacyAgent['name'] -and -not $defaults['name']) {
            $defaults['name'] = [string]$legacyAgent['name']
        }
        if ($legacyAgent['systemPrompt'] -and -not $defaults['systemPrompt']) {
            $defaults['systemPrompt'] = [string]$legacyAgent['systemPrompt']
        }
        if ($legacyAgent['providers'] -is [System.Collections.IDictionary]) {
            foreach ($providerKey in $legacyAgent['providers'].Keys) {
                if (-not $providers.ContainsKey($providerKey)) {
                    $providers[$providerKey] = ConvertTo-HashtableCompat $legacyAgent['providers'][$providerKey]
                }
            }
        }
        $Config.Remove('agent')
    }

    return $Config
}

function Get-Config {
    $ctx = $script:MODE_CONTEXT
    Ensure-Directory $ctx.StateDir
    Ensure-Directory $ctx.BackupDir
    Ensure-Directory (Split-Path $ctx.LogPath -Parent)

    if (Test-Path $ctx.ConfigPath) {
        try {
            $raw = Get-Content $ctx.ConfigPath -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                return Ensure-ConfigShape (ConvertTo-HashtableCompat ($raw | ConvertFrom-Json))
            }
        } catch {
            Show-Msg '读取配置失败，已回退到默认配置。' 'Yellow'
        }
    }

    return Ensure-ConfigShape (New-DefaultConfig)
}

function Save-Config {
    param([hashtable]$Config)
    $ctx = $script:MODE_CONTEXT
    Ensure-Directory $ctx.StateDir
    (Ensure-ConfigShape $Config) | ConvertTo-Json -Depth 100 | Set-Content -Path $ctx.ConfigPath -Encoding UTF8
}

function Backup-ConfigFile {
    param([string]$Reason = 'manual')
    $ctx = $script:MODE_CONTEXT
    Ensure-Directory $ctx.BackupDir
    if (-not (Test-Path $ctx.ConfigPath)) { return $null }
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupPath = Join-Path $ctx.BackupDir ("openclaw_{0}_{1}.json" -f $Reason, $timestamp)
    Copy-Item -Path $ctx.ConfigPath -Destination $backupPath -Force
    return $backupPath
}

function Get-GatewayToken {
    $cfg = Get-Config
    if ($cfg.gateway -and $cfg.gateway.auth -and $cfg.gateway.auth.token) { return [string]$cfg.gateway.auth.token }
    return 'goodforstart'
}

function Get-ConfiguredModel {
    param([hashtable]$Config)
    if ($Config.agents -and $Config.agents.defaults -and $Config.agents.defaults.model -and $Config.agents.defaults.model.primary) {
        return [string]$Config.agents.defaults.model.primary
    }
    return 'Not configured'
}

function Read-TextWithDefault {
    param([string]$Prompt, [string]$Default = '')
    if ([string]::IsNullOrEmpty($Default)) {
        return (Read-Host $Prompt).Trim()
    }
    $value = Read-Host ("{0} [当前/默认: {1}]" -f $Prompt, $Default)
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value.Trim()
}

function Read-OptionalText {
    param([string]$Prompt, [string]$Default = '')
    $value = Read-TextWithDefault $Prompt $Default
    if ([string]::IsNullOrWhiteSpace($value)) { return '' }
    return $value
}

function Test-RuntimeReady {
    $ctx = $script:MODE_CONTEXT
    if (-not (Test-Path $ctx.NodeBin)) {
        Show-Msg '当前目录中找不到 Node.js 运行时。' 'Red'
        return $false
    }
    if (-not (Test-Path $ctx.OpenClawMjs)) {
        Show-Msg '当前目录中找不到 OpenClaw 入口文件。' 'Red'
        return $false
    }
    return $true
}

function Get-GatewayPort {
    foreach ($port in 18789..18799) {
        try {
            $conn = Get-NetTCPConnection -LocalPort $port -ErrorAction Stop | Select-Object -First 1
            if ($conn) { return $port }
        } catch {
        }
    }
    return $null
}

function Try-ReloadGateway {
    if (-not (Test-RuntimeReady)) { return }
    if (-not (Get-GatewayPort)) { return }
    try {
        & $script:MODE_CONTEXT.NodeBin $script:MODE_CONTEXT.OpenClawMjs gateway restart *> $null
        Show-Msg '已尝试重载 Gateway 应用新配置。' 'DarkGray'
    } catch {
        Show-Msg '配置已保存；如未立即生效，请手动重启 Gateway。' 'Yellow'
    }
}

function Set-ModelConfig {
    Write-Section '配置 AI 模型'
    foreach ($template in $MODEL_TEMPLATES) {
        Write-Host (" [{0}] {1}" -f $template.Key, $template.Name)
    }
    Write-Host ' [0] 返回'

    $choice = Read-Host "`n请选择模型编号"
    if ($choice -eq '0') { return }

    $template = $MODEL_TEMPLATES | Where-Object { $_.Key -eq $choice } | Select-Object -First 1
    if ($null -eq $template) {
        Show-Msg '无效选择。' 'Yellow'
        Pause-Return
        return
    }

    $providerKey = [string]$template.ProviderKey
    $fullModel = [string]$template.FullModel
    $baseUrl = [string]$template.BaseUrl

    if ($template.IsCustom) {
        $providerKey = Read-TextWithDefault 'Provider 名称' 'custom'
        $modelId = Read-TextWithDefault '模型 ID' 'gpt-4o-mini'
        $baseUrl = Read-TextWithDefault 'Base URL' $baseUrl
        $fullModel = "{0}/{1}" -f $providerKey, $modelId
    }

    $apiKey = if ($template.FixedApiKey) { [string]$template.FixedApiKey } else { Read-Host '请输入 API Key' }
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        Show-Msg 'API Key 不能为空。' 'Red'
        Pause-Return
        return
    }

    $cfg = Get-Config
    [void](Backup-ConfigFile 'before-model')
    $models = Ensure-MapValue $cfg 'models'
    $providers = Ensure-MapValue $models 'providers'
    $agents = Ensure-MapValue $cfg 'agents'
    $defaults = Ensure-MapValue $agents 'defaults'
    $defaultModel = Ensure-MapValue $defaults 'model'
    $defaultModels = Ensure-MapValue $defaults 'models'
    $providerConfig = [ordered]@{ apiKey = $apiKey }
    if (-not [string]::IsNullOrWhiteSpace($baseUrl)) {
        $providerConfig['baseUrl'] = $baseUrl
    }
    if ($providerKey -eq 'ollama') {
        $providerConfig['api'] = 'ollama'
    } elseif ($providerKey -ne 'anthropic') {
        $providerConfig['api'] = 'openai-completions'
    }
    $modelId = $fullModel.Substring($fullModel.IndexOf('/') + 1)
    $providerConfig['models'] = @(
        [ordered]@{
            id = $modelId
            name = $template.Name
        }
    )
    $providers[$providerKey] = $providerConfig
    $defaultModel['primary'] = $fullModel
    $defaultModels[$fullModel] = [ordered]@{
        alias = $template.Name
    }

    Save-Config $cfg
    Try-ReloadGateway
    Show-Msg ("模型已保存：{0}" -f $fullModel) 'Green'
    Pause-Return
}

function Set-PersonaConfig {
    $cfg = Get-Config
    $agents = Ensure-MapValue $cfg 'agents'
    $defaults = Ensure-MapValue $agents 'defaults'

    Write-Section '配置 AI 人设'
    $currentName = [string]$defaults['name']
    $currentPrompt = [string]$defaults['systemPrompt']
    $name = Read-OptionalText 'AI 名称' $currentName
    $prompt = Read-OptionalText '系统提示词' $currentPrompt

    if ([string]::IsNullOrWhiteSpace($name)) { $defaults.Remove('name') } else { $defaults['name'] = $name }
    if ([string]::IsNullOrWhiteSpace($prompt)) { $defaults.Remove('systemPrompt') } else { $defaults['systemPrompt'] = $prompt }

    Save-Config $cfg
    Try-ReloadGateway
    Show-Msg 'AI 人设已保存。' 'Green'
    Pause-Return
}

function Show-ChannelSummary {
    param([hashtable]$Channels)
    if ($Channels.Count -eq 0) {
        Write-Host ' 当前通信工具：无' -ForegroundColor DarkGray
        return
    }
    Write-Host ' 当前通信工具:' -ForegroundColor Gray
    foreach ($name in $Channels.Keys | Sort-Object) {
        Write-Host ("  - {0}" -f $name) -ForegroundColor Gray
    }
}

function Set-ChannelConfig {
    $cfg = Get-Config
    $channels = Ensure-MapValue $cfg 'channels'

    Write-Section '配置通信工具'
    Show-ChannelSummary $channels
    Write-Host ''
    Write-Host ' [1] QQ Bot'
    Write-Host ' [2] 飞书 Feishu'
    Write-Host ' [3] Telegram'
    Write-Host ' [4] Discord'
    Write-Host ' [0] 返回'

    $choice = Read-Host "`n请选择平台"
    if ($choice -eq '0') { return }

    switch ($choice) {
        '1' {
            $existing = if ($channels.ContainsKey('qqbot')) { [hashtable]$channels['qqbot'] } else { @{} }
            $existingToken = [string]$existing['token']
            $existingAppId = ''
            $existingSecret = ''
            if (-not [string]::IsNullOrWhiteSpace($existingToken) -and $existingToken.Contains(':')) {
                $parts = $existingToken.Split(':', 2)
                $existingAppId = $parts[0]
                $existingSecret = $parts[1]
            }
            $appId = Read-OptionalText 'QQ AppID' $existingAppId
            $appSecret = Read-OptionalText 'QQ AppSecret' $existingSecret
            $allowFrom = Read-OptionalText 'Allowed QQ number (blank means unrestricted)' ([string]$existing['allowFrom'])
            if ([string]::IsNullOrWhiteSpace($appId) -or [string]::IsNullOrWhiteSpace($appSecret)) {
                Show-Msg 'QQ 配置未保存：AppID 和 AppSecret 必填。' 'Red'
            } else {
                $channels['qqbot'] = [ordered]@{ token = "{0}:{1}" -f $appId, $appSecret }
                if (-not [string]::IsNullOrWhiteSpace($allowFrom)) { $channels['qqbot']['allowFrom'] = $allowFrom }
                Save-Config $cfg
                Try-ReloadGateway
                Show-Msg 'QQ 配置已保存。' 'Green'
            }
        }
        '2' {
            $existing = if ($channels.ContainsKey('feishu')) { [hashtable]$channels['feishu'] } else { @{} }
            $accounts = if ($existing.ContainsKey('accounts') -and $existing['accounts'] -is [System.Collections.IDictionary]) { [hashtable]$existing['accounts'] } else { @{} }
            $mainAccount = if ($accounts.ContainsKey('main') -and $accounts['main'] -is [System.Collections.IDictionary]) { [hashtable]$accounts['main'] } else { @{} }
            $appId = Read-OptionalText 'Feishu App ID' ([string]$mainAccount['appId'])
            $appSecret = Read-OptionalText 'Feishu App Secret' ([string]$mainAccount['appSecret'])
            $botName = Read-OptionalText 'Bot Name' ([string]$mainAccount['botName'])
            if ([string]::IsNullOrWhiteSpace($appId) -or [string]::IsNullOrWhiteSpace($appSecret)) {
                Show-Msg '飞书配置未保存：App ID 和 App Secret 必填。' 'Red'
            } else {
                $channels['feishu'] = [ordered]@{
                    enabled = $true
                    dmPolicy = 'pairing'
                    accounts = [ordered]@{
                        main = [ordered]@{
                            appId = $appId
                            appSecret = $appSecret
                        }
                    }
                }
                if (-not [string]::IsNullOrWhiteSpace($botName)) {
                    $channels['feishu']['accounts']['main']['botName'] = $botName
                }
                Save-Config $cfg
                Try-ReloadGateway
                Show-Msg '飞书配置已保存。' 'Green'
            }
        }
        '3' {
            $existing = if ($channels.ContainsKey('telegram')) { [hashtable]$channels['telegram'] } else { @{} }
            $token = Read-OptionalText 'Telegram Bot Token' ([string]$existing['botToken'])
            $allowFrom = Read-OptionalText 'Allowed user/chat ID (blank means unrestricted)' ([string]$existing['allowFrom'])
            if ([string]::IsNullOrWhiteSpace($token)) {
                Show-Msg 'Telegram 配置未保存：Token 必填。' 'Red'
            } else {
                $channels['telegram'] = [ordered]@{
                    enabled = $true
                    botToken = $token
                    dmPolicy = 'pairing'
                    groups = [ordered]@{
                        '*' = [ordered]@{
                            requireMention = $true
                        }
                    }
                }
                if (-not [string]::IsNullOrWhiteSpace($allowFrom)) { $channels['telegram']['allowFrom'] = $allowFrom }
                Save-Config $cfg
                Try-ReloadGateway
                Show-Msg 'Telegram 配置已保存。' 'Green'
            }
        }
        '4' {
            $existing = if ($channels.ContainsKey('discord')) { [hashtable]$channels['discord'] } else { @{} }
            $token = Read-OptionalText 'Discord Bot Token' ([string]$existing['token'])
            if ([string]::IsNullOrWhiteSpace($token)) {
                Show-Msg 'Discord 配置未保存：Token 必填。' 'Red'
            } else {
                $channels['discord'] = [ordered]@{
                    enabled = $true
                    token = $token
                    dmPolicy = 'pairing'
                }
                Save-Config $cfg
                Try-ReloadGateway
                Show-Msg 'Discord 配置已保存。' 'Green'
            }
        }
        default {
            Show-Msg '无效选择。' 'Yellow'
        }
    }

    Pause-Return
}

function Remove-ChannelConfig {
    $cfg = Get-Config
    $channels = Ensure-MapValue $cfg 'channels'

    Write-Section '移除通信工具'
    if ($channels.Count -eq 0) {
        Show-Msg '当前没有已配置的通信工具。' 'Yellow'
        Pause-Return
        return
    }

    $keys = @($channels.Keys | Sort-Object)
    for ($i = 0; $i -lt $keys.Count; $i++) {
        Write-Host (" [{0}] {1}" -f ($i + 1), $keys[$i])
    }
    Write-Host ' [0] 返回'

    $choice = Read-Host "`n请选择要移除的通信工具"
    if ($choice -eq '0') { return }

    $index = 0
    if (-not [int]::TryParse($choice, [ref]$index) -or $index -lt 1 -or $index -gt $keys.Count) {
        Show-Msg '无效选择。' 'Yellow'
        Pause-Return
        return
    }

    $target = $keys[$index - 1]
    $channels.Remove($target)
    Save-Config $cfg
    Try-ReloadGateway
    Show-Msg ("已移除通信工具：{0}" -f $target) 'Green'
    Pause-Return
}

function Show-CurrentStatus {
    $ctx = $script:MODE_CONTEXT
    $cfg = Get-Config
    $channels = Ensure-MapValue $cfg 'channels'
    $token = Get-GatewayToken
    $port = Get-GatewayPort

    Write-Section '当前状态'
    Write-Host (" 当前模式: {0}" -f $ctx.Label) -ForegroundColor White
    Write-Host (" 配置路径: {0}" -f $ctx.ConfigPath) -ForegroundColor Gray
    Write-Host (" 当前模型: {0}" -f (Get-ConfiguredModel $cfg)) -ForegroundColor White
    Write-Host (" Gateway Token: {0}" -f $token) -ForegroundColor Gray
    if ($port) {
        Write-Host (" Gateway: 运行中 (端口 {0})" -f $port) -ForegroundColor Green
        Write-Host (" Dashboard: http://127.0.0.1:{0}/#token={1}" -f $port, $token) -ForegroundColor Gray
    } else {
        Write-Host ' Gateway: 未运行' -ForegroundColor Yellow
    }
    Show-ChannelSummary $channels
    Pause-Return
}

function Start-UClawGateway {
    $ctx = $script:MODE_CONTEXT
    if (-not (Test-Path $ctx.StartScript)) {
        Show-Msg '当前目录中找不到 windows-start.ps1。' 'Red'
        return
    }
    Show-Msg ("当前模式将使用配置文件: {0}" -f $ctx.ConfigPath) 'DarkGray'
    Start-Process powershell.exe -ArgumentList @('-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', "`$env:OPENCLAW_HOME='$($ctx.DataDir)'; `$env:OPENCLAW_STATE_DIR='$($ctx.StateDir)'; `$env:OPENCLAW_CONFIG_PATH='$($ctx.ConfigPath)'; if (`$env:PATH -notlike '*$($ctx.NodeDir)*') { `$env:PATH='$($ctx.NodeDir);' + `$env:PATH }; & '$($ctx.StartScript)'" )
    Show-Msg '已在新窗口启动 Ultra-Claw。' 'Green'
}

function Stop-UClawGateway {
    if (-not (Test-RuntimeReady)) { return }
    & $script:MODE_CONTEXT.NodeBin $script:MODE_CONTEXT.OpenClawMjs gateway stop
    if ($LASTEXITCODE -eq 0) { Show-Msg '停止命令执行完成。' 'Green' } else { Show-Msg '停止命令返回了非零状态。' 'Yellow' }
}

function Restart-UClawGateway {
    if (-not (Test-RuntimeReady)) { return }
    try {
        & $script:MODE_CONTEXT.NodeBin $script:MODE_CONTEXT.OpenClawMjs gateway restart
        if ($LASTEXITCODE -eq 0) {
            Show-Msg '重启命令执行完成。' 'Green'
            return
        }
    } catch {
    }
    Show-Msg '重启失败，正在回退到停止后重新启动。' 'Yellow'
    try { & $script:MODE_CONTEXT.NodeBin $script:MODE_CONTEXT.OpenClawMjs gateway stop *> $null } catch {}
    Start-Sleep -Seconds 2
    Start-UClawGateway
}

function Show-GatewayStatus {
    if (-not (Test-RuntimeReady)) { Pause-Return; return }
    Write-Section 'Gateway 状态'
    Write-Host ''
    & $script:MODE_CONTEXT.NodeBin $script:MODE_CONTEXT.OpenClawMjs gateway status
    Pause-Return
}

function Open-Dashboard {
    $port = Get-GatewayPort
    if (-not $port) {
        Show-Msg '未检测到 Gateway，正在先启动 Ultra-Claw。' 'Yellow'
        Start-UClawGateway
        Start-Sleep -Seconds 4
        $port = Get-GatewayPort
        if (-not $port) {
            Show-Msg 'Gateway 仍在启动中，请稍后再试。' 'Yellow'
            return
        }
    }
    $url = "http://127.0.0.1:{0}/#token={1}" -f $port, (Get-GatewayToken)
    Start-Process $url
    Show-Msg ("已打开 Dashboard: {0}" -f $url) 'Green'
}

function Open-Tui {
    if (-not (Test-RuntimeReady)) { return }
    $command = "`$env:OPENCLAW_HOME='$($script:MODE_CONTEXT.DataDir)'; `$env:OPENCLAW_STATE_DIR='$($script:MODE_CONTEXT.StateDir)'; `$env:OPENCLAW_CONFIG_PATH='$($script:MODE_CONTEXT.ConfigPath)'; & '$($script:MODE_CONTEXT.NodeBin)' '$($script:MODE_CONTEXT.OpenClawMjs)' tui"
    Start-Process powershell.exe -ArgumentList @('-NoExit', '-Command', $command) -WorkingDirectory $script:MODE_CONTEXT.CoreDir
    Show-Msg '已在新窗口打开 OpenClaw TUI。' 'Green'
}

function Run-Doctor {
    if (-not (Test-RuntimeReady)) { Pause-Return; return }
    Write-Section 'OpenClaw 诊断'
    Write-Host ''
    & $script:MODE_CONTEXT.NodeBin $script:MODE_CONTEXT.OpenClawMjs doctor
    Pause-Return
}

function View-GatewayLog {
    $ctx = $script:MODE_CONTEXT
    Write-Section '查看日志'
    if (-not (Test-Path $ctx.LogPath)) {
        Show-Msg '暂时还没有找到 gateway.log。' 'Yellow'
        Pause-Return
        return
    }

    Write-Host ' [1] 查看最后 60 行'
    Write-Host ' [2] 用记事本打开'
    Write-Host ' [0] 返回'
    $choice = Read-Host "`n请选择"

    switch ($choice) {
        '1' {
            Write-Host ''
            Get-Content -Path $ctx.LogPath -Tail 60
            Pause-Return
        }
        '2' {
            Start-Process notepad.exe $ctx.LogPath
        }
        default {
        }
    }
}

function Reset-DefaultConfig {
    Write-Section '恢复默认配置'
    $confirm = Read-Host '输入 YES 确认恢复默认配置'
    if ($confirm -ne 'YES') {
        Show-Msg '已取消。' 'Yellow'
        Pause-Return
        return
    }

    [void](Backup-ConfigFile 'before-reset')
    $cfg = New-DefaultConfig
    Save-Config $cfg
    Try-ReloadGateway
    Show-Msg '默认配置已恢复。' 'Green'
    Pause-Return
}

function Open-Diagnostics {
    $ctx = $script:MODE_CONTEXT
    if (-not (Test-Path $ctx.DiagnoseScript)) {
        Show-Msg '当前目录中找不到 Windows-Diagnose.bat。' 'Red'
        return
    }
    Start-Process $ctx.DiagnoseScript
    Show-Msg '已打开诊断脚本。' 'Green'
}

Test-PortableRuntimeOrExit
Set-ModeContext (Select-Mode)

if (-not (Test-Path $script:MODE_CONTEXT.ConfigPath)) {
    Save-Config (New-DefaultConfig)
} else {
    Save-Config (Get-Config)
}

while ($true) {
    Clear-Host
    $ctx = $script:MODE_CONTEXT
    $port = Get-GatewayPort

    Write-Host ''
    Write-Host '============================================' -ForegroundColor Cyan
    Write-Host '  Ultra-Claw Console' -ForegroundColor Cyan
    Write-Host '============================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host (" 当前模式: {0}" -f $ctx.Label) -ForegroundColor White
    Write-Host (" 配置路径: {0}" -f $ctx.ConfigPath) -ForegroundColor Gray
    if ($port) {
        Write-Host (" Gateway: 运行中 (端口 {0})" -f $port) -ForegroundColor Green
    } else {
        Write-Host ' Gateway: 未运行' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host ' [1] 查看当前状态'
    Write-Host ' [2] 配置 AI 模型'
    Write-Host ' [3] 配置 AI 人设'
    Write-Host ' [4] 配置通信工具'
    Write-Host ' [5] Remove channels'
    Write-Host ' [6] 备份当前配置'
    Write-Host ' [7] Start Ultra-Claw'
    Write-Host ' [8] Stop Ultra-Claw'
    Write-Host ' [9] Restart Ultra-Claw'
    Write-Host ' [10] 查看 Gateway 状态'
    Write-Host ' [11] 打开 Dashboard'
    Write-Host ' [12] 打开 TUI'
    Write-Host ' [13] 运行 Doctor'
    Write-Host ' [14] 查看日志'
    Write-Host ' [15] 恢复默认配置'
    Write-Host ' [16] 打开诊断脚本'
    Write-Host ' [17] 切换模式'
    Write-Host ' [0] 退出'

    $choice = Read-Host "`n请选择操作"
    switch ($choice) {
        '1' { Show-CurrentStatus }
        '2' { Set-ModelConfig }
        '3' { Set-PersonaConfig }
        '4' { Set-ChannelConfig }
        '5' { Remove-ChannelConfig }
        '6' {
            $backup = Backup-ConfigFile 'manual'
            if ($backup) { Show-Msg ("备份已创建: {0}" -f $backup) 'Green' } else { Show-Msg '当前没有可备份的配置。' 'Yellow' }
            Pause-Return
        }
        '7' { Start-UClawGateway; Pause-Return }
        '8' { Stop-UClawGateway; Pause-Return }
        '9' { Restart-UClawGateway; Pause-Return }
        '10' { Show-GatewayStatus }
        '11' { Open-Dashboard; Pause-Return }
        '12' { Open-Tui; Pause-Return }
        '13' { Run-Doctor }
        '14' { View-GatewayLog }
        '15' { Reset-DefaultConfig }
        '16' { Open-Diagnostics; Pause-Return }
        '17' {
            Set-ModeContext (Select-Mode)
            if (-not (Test-Path $script:MODE_CONTEXT.ConfigPath)) {
                Save-Config (New-DefaultConfig)
            } else {
                Save-Config (Get-Config)
            }
        }
        '0' { break }
        default {
            Show-Msg '无效选择。' 'Yellow'
            Pause-Return
        }
    }
}
