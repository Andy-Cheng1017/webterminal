<#
.SYNOPSIS
    環境準備：把 ttyd 與 cloudflared 放到 C:\Tools\

.使用說明
    1. 不需要系統管理員權限（C:\Tools 若無法建立，會自動改用 %USERPROFILE%\Tools）。
    2. 可修改下方「設定區」的本機來源路徑；若來源不存在，會自動從 GitHub 下載最新版。
    3. 執行： powershell -ExecutionPolicy Bypass -File .\01-Setup-Environment.ps1
    4. 已存在的檔案會自動跳過。
#>

# ===================== 設定區 =====================
$ToolsDir        = 'C:\Tools'
$LocalTtydSource = ''
$LocalCfdSource  = ''
# ==================================================

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 建立目錄（失敗則退回使用者目錄，避免需要 IT 密碼）
try {
    if (-not (Test-Path $ToolsDir)) { New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null }
    $probe = Join-Path $ToolsDir '.write-test'
    New-Item -ItemType File -Path $probe -Force | Out-Null
    Remove-Item $probe -Force
} catch {
    $ToolsDir = Join-Path $env:USERPROFILE 'Tools'
    Write-Warning "無法使用 C:\Tools，改用 $ToolsDir"
    New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
}
# 記錄實際使用的目錄，供其他腳本讀取
Set-Content -Path (Join-Path $PSScriptRoot 'toolsdir.txt') -Value $ToolsDir -Encoding UTF8

function Get-Tool {
    param(
        [string]$Name,          # 目標檔名
        [string]$LocalSource,   # 本機來源（優先）
        [string]$Repo,          # GitHub owner/repo
        [string]$AssetPattern   # 下載資產名稱（regex）
    )
    $dest = Join-Path $ToolsDir $Name
    if (Test-Path $dest) { Write-Host "[略過] $Name 已存在：$dest"; return }

    if ($LocalSource -and (Test-Path $LocalSource)) {
        Copy-Item $LocalSource $dest -Force
        Write-Host "[完成] 已從本機複製 $Name"
        return
    }

    try {
        Write-Host "[下載] 查詢 $Repo 最新版本..."
        $rel   = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ 'User-Agent' = 'ps-setup' }
        $asset = $rel.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1
        if (-not $asset) { throw "找不到符合 $AssetPattern 的資產" }

        $tmp = Join-Path $env:TEMP $asset.name
        Invoke-WebRequest $asset.browser_download_url -OutFile $tmp -UseBasicParsing
        if ($tmp -like '*.zip') {
            $x = Join-Path $env:TEMP "$Name-extract"
            Expand-Archive $tmp $x -Force
            $exe = Get-ChildItem $x -Filter *.exe -Recurse | Select-Object -First 1
            Copy-Item $exe.FullName $dest -Force
            Remove-Item $x -Recurse -Force
        } else {
            Copy-Item $tmp $dest -Force   # 單一 exe，直接重新命名
        }
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        Write-Host "[完成] 已下載 $Name"
    } catch {
        Write-Error "取得 $Name 失敗：$($_.Exception.Message)"
    }
}

Get-Tool -Name 'ttyd.exe'        -LocalSource $LocalTtydSource -Repo 'tsl0922/ttyd'          -AssetPattern '^ttyd\.win32\.exe$'
Get-Tool -Name 'cloudflared.exe' -LocalSource $LocalCfdSource  -Repo 'cloudflare/cloudflared' -AssetPattern '^cloudflared-windows-amd64\.exe$'

Write-Host "`n版本檢查："
foreach ($n in 'ttyd.exe', 'cloudflared.exe') {
    $p = Join-Path $ToolsDir $n
    if (Test-Path $p) { Write-Host " $n -> $(& $p --version 2>&1 | Select-Object -First 1)" }
    else { Write-Warning " $n 不存在" }
}
