<#
.SYNOPSIS
    啟動 ttyd 與 cloudflared（背景隱藏執行）

.使用說明
    執行前請修改「設定區」：
      - $TtydUser / $TtydPass ：ttyd 基本認證（第二層保護），請改成強密碼
      - config.yml 內的 <YOUR_TUNNEL_ID> 與網域
    執行： powershell -ExecutionPolicy Bypass -File .\02-Start-Services.ps1
    ttyd 僅綁定 127.0.0.1，只有 cloudflared 能連到它。
#>

# ===================== 設定區 =====================
$TtydUser   = 'andy'
$TtydPass   = '<CHANGE_ME_STRONG_PASSWORD>'
# 密碼不進 Git：若存在 secrets\ttyd-password.txt，優先讀取該檔（單行純文字）
$SecretFile = Join-Path $PSScriptRoot 'secrets\ttyd-password.txt'
if (Test-Path $SecretFile) { $TtydPass = (Get-Content $SecretFile -Raw).Trim() }
$TtydPort   = 8080
$WorkDir    = $env:USERPROFILE
$ConfigFile = Join-Path $PSScriptRoot 'config.yml'
# ==================================================

$ErrorActionPreference = 'Stop'
$LogDir = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

try {
    $tdFile   = Join-Path $PSScriptRoot 'toolsdir.txt'
    $ToolsDir = if (Test-Path $tdFile) { (Get-Content $tdFile -Raw).Trim() } else { 'C:\Tools' }
    $ttyd = Join-Path $ToolsDir 'ttyd.exe'
    $cfd  = Join-Path $ToolsDir 'cloudflared.exe'

    foreach ($f in $ttyd, $cfd, $ConfigFile) {
        if (-not (Test-Path $f)) { throw "找不到檔案：$f（請先執行 01 腳本／確認 config.yml）" }
    }
    if ($TtydPass -like '<*') { throw '請先修改 $TtydPass 為實際密碼' }
    if ((Get-Content $ConfigFile -Raw) -match '<YOUR_TUNNEL_ID>') { throw 'config.yml 尚未替換 <YOUR_TUNNEL_ID>' }

    # 優先使用 pwsh（PowerShell 7），不存在則退回 powershell.exe
    $shell = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { 'pwsh.exe' } else { 'powershell.exe' }

    # 避免重複啟動：先停止由 Tools 目錄啟動的舊程序
    foreach ($p in 'ttyd', 'cloudflared') {
        Get-Process $p -ErrorAction SilentlyContinue |
            Where-Object { $_.Path -like "$ToolsDir*" } |
            ForEach-Object { Stop-Process -Id $_.Id -Force }
    }
    Start-Sleep -Seconds 1

    # 啟動 ttyd：-W 可寫入、-w 起始目錄（Windows 必要）、-i 只綁本機
    Start-Process -FilePath $ttyd -WindowStyle Hidden `
        -ArgumentList '-W', '-w', $WorkDir, '-p', $TtydPort, '-i', '127.0.0.1', '-c', "${TtydUser}:${TtydPass}", $shell `
        -RedirectStandardError (Join-Path $LogDir 'ttyd.log')

    # 啟動 cloudflared
    Start-Process -FilePath $cfd -WindowStyle Hidden `
        -ArgumentList '--config', "`"$ConfigFile`"", 'tunnel', 'run' `
        -RedirectStandardError (Join-Path $LogDir 'cloudflared.log')

    Start-Sleep -Seconds 3
    foreach ($p in 'ttyd', 'cloudflared') {
        if (Get-Process $p -ErrorAction SilentlyContinue) { Write-Host "[OK] $p 執行中" }
        else { Write-Warning "$p 未在執行，請查看 $LogDir" }
    }
} catch {
    Write-Error "啟動失敗：$($_.Exception.Message)"
    exit 1
}
