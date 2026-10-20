# 手動檢查清單

> 現況與完整說明見 README.md。目前 tunnel 為 `webterminal-new`；密碼改放 `secrets\ttyd-password.txt`，不再編輯 `02` 腳本。以下為首次建置用清單。

## 本機（使用者權限）
- [ ] `01-Setup-Environment.ps1` 執行完成，ttyd / cloudflared 版本有顯示
- [ ] `cloudflared.exe tunnel login`（瀏覽器授權網域）
- [ ] `cloudflared.exe tunnel create webterminal`，記下 Tunnel ID
- [ ] 編輯 `config.yml`：替換 `<YOUR_TUNNEL_ID>`、`shell.andycheng.men`
- [ ] `cloudflared.exe tunnel route dns webterminal shell.andycheng.men`
- [ ] 編輯 `02-Start-Services.ps1`：改 `$TtydPass`
- [ ] 執行 `02`，確認 `logs\` 無錯誤；執行 `03` 註冊登入啟動

## Cloudflare Zero Trust Dashboard（需手動）
- [ ] 網域 DNS 已託管在 Cloudflare（且有 Zero Trust 帳號，免費方案即可）
- [ ] Zero Trust → Settings → Authentication：確認 **One-time PIN** 已啟用
- [ ] Access → Applications → Add → **Self-hosted**
  - Application domain：`shell.andycheng.men`
  - Session duration：建議 1~24 小時
- [ ] 建立 Policy：Action = **Allow**，Include = **Emails**，只填你自己的 Email
- [ ] （建議）加上 Policy 條件：Require 國家/地區，或 Session 過期時間縮短
- [ ] 手機開啟 `https://shell.andycheng.men`：先收 Email OTP，再輸入 ttyd 帳密，進入終端機

## 安全提醒
- 此終端機等於完整的電腦控制權，務必確認 Access Policy 只允許你本人
- 若公司政策禁止對外穿透，請先向 IT 確認

