<#
.SYNOPSIS
    註冊「登入時自動執行 02-Start-Services.ps1」的排程工作

.使用說明
    - 不需修改變數（會自動使用目前使用者與同資料夾的 02 腳本）。
    - 以一般使用者權限（Limited）註冊，不需 IT / 系統管理員密碼。
    - 執行： powershell -ExecutionPolicy Bypass -File .\03-Register-StartupTask.ps1
    - 移除： Unregister-ScheduledTask -TaskName WebTerminalServices -Confirm:$false
#>

$ErrorActionPreference = 'Stop'
$TaskName = 'WebTerminalServices'

try {
    $script = Join-Path $PSScriptRoot '02-Start-Services.ps1'
    if (-not (Test-Path $script)) { throw "找不到 $script" }

    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""

    # 僅在目前使用者登入時觸發，延遲 20 秒等網路就緒
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
    $trigger.Delay = 'PT20S'

    # -Hidden：盡可能隱藏；筆電電池下也允許執行
    $settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)

    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Force | Out-Null

    Write-Host "[完成] 已註冊排程工作 $TaskName（使用者 $user，登入時執行）"
    Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State
} catch {
    Write-Error "註冊失敗：$($_.Exception.Message)"
    exit 1
}
