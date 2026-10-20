@echo off
rem 雙擊啟動 Web Terminal（ttyd + cloudflared，背景隱藏執行）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp002-Start-Services.ps1"
echo.
pause
