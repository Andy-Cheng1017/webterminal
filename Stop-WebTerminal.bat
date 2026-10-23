@echo off
rem 雙擊停止 Web Terminal
powershell -NoProfile -Command "Get-Process ttyd,cloudflared,sshd-lite -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'C:\Tools*' } | ForEach-Object { Stop-Process -Id $_.Id -Force }; 'stopped'"
pause
