# Web Terminal 專案交接文件（給下一個 Copilot / 未來的我）

> 若你是接手的 Copilot：請先完整讀完本檔，再開始動作。使用者語言：**繁體中文**。

## 1. 專案目標
在公司筆電（防火牆擋 SSH/22，只放行 HTTPS/443）上，讓使用者**用手機瀏覽器開網頁就能進入 PowerShell，並執行 Copilot CLI**。

架構：`手機瀏覽器 → Cloudflare Access (Email OTP) → Cloudflare Tunnel → cloudflared → ttyd(127.0.0.1:8080) → pwsh`

## 2. 限制與偏好（重要）
- **不可安裝到全機／不可要 IT 密碼**：所有工具放使用者層級（`C:\Tools\`，不行則 `%USERPROFILE%\Tools`），排程以 Limited 權限註冊。
- 公司 IT **已同意**對外 Tunnel。
- 公司筆電有 **Zscaler**：用公司電腦直接連自己的公網網址會被 Zscaler 擋（403），測試公網請用手機（行動網路）。
- 使用者希望：Windows 開機後**雙擊 `Start-WebTerminal.bat` 手動啟動**，不一定要開機自動執行（03 腳本為選配，從未註冊）。
- 使用者要求以 Windows 路徑（反斜線）與 PowerShell 操作。

## 3. 已知資訊
- 網域：`andycheng.men`（託管於 Cloudflare），對外主機名：`shell.andycheng.men`
- 目前使用的 Tunnel：`webterminal-new`，ID：`a49c136b-d3c2-4471-a39d-8f1a6e5bf2f5`（新電腦建立；舊的 `webterminal`，ID `b3794d5d-…` 已不使用）
- 手機登入 Email（OTP）：`swps9940902@gmail.com`
- ttyd 基本認證帳號：`andy`；**密碼不在 Git 中**，放在本機 `secrets\ttyd-password.txt`（被 .gitignore 排除）。新電腦請重新產生。
- 舊電腦另有一個 tunnel `Company-copilot`（屬於 `copilot-openai-proxy` 專案，與本專案無關，勿動）。

## 4. 檔案說明
| 檔案 | 用途 |
|---|---|
| `01-Setup-Environment.ps1` | 取得 ttyd / cloudflared 到 `C:\Tools\`（優先複製本機來源，否則從 GitHub 下載；已存在則跳過）。**本機來源路徑是舊電腦的，新電腦需改 `$LocalTtydSource/$LocalCfdSource` 或清空以走下載** |
| `config.yml` | cloudflared 設定：tunnel ID、credentials-file、`protocol: http2`（走 443）、ingress 指向 `http://localhost:8080` |
| `02-Start-Services.ps1` | 隱藏啟動 ttyd 與 cloudflared；會檢查未替換的佔位符；密碼讀 `secrets\ttyd-password.txt` |
| `03-Register-StartupTask.ps1` | 選配：註冊登入時自動執行的排程（Limited 權限） |
| `Start-WebTerminal.bat` / `Stop-WebTerminal.bat` | 雙擊啟動／停止 |
| `CHECKLIST.md` | Cloudflare 後台需手動完成的清單 |

注意：`.ps1` 必須是 **UTF-8 with BOM**，否則 Windows PowerShell 5.1 會把中文註解讀成亂碼導致語法錯誤。編輯後請保持 BOM。

## 5. 目前進度
已完成（舊電腦）：
- [x] 腳本與設定檔完成並實測
- [x] `cloudflared tunnel login`、`tunnel create webterminal`、`tunnel route dns webterminal shell.andycheng.men`
- [x] ttyd 本機回應 200；cloudflared 4 條連線註冊成功（`/ready` 回 200）

**新電腦已完成：** 工具安裝、新 tunnel（`webterminal-new`）、DNS 改指新 tunnel、新 ttyd 密碼、Cloudflare Access（One-time PIN + Email policy）、手機實測成功。完整說明見 README.md。

**以下為舊電腦時期的歷史紀錄（已完成）：**
- [x] **Cloudflare Zero Trust 後台的 Access 設定**：
  1. 確認 One-time PIN 已啟用（Zero Trust → Settings → Authentication）
  2. Access → Applications → Add → Self-hosted，Domain = `shell.andycheng.men`
  3. Policy：Allow，Include → Emails → `swps9940902@gmail.com`
  4. **完成前網址僅有 ttyd 帳密保護，請勿長期對外開放**
- [x] 用手機實測完整流程（Email OTP → ttyd 帳密 → PowerShell → 執行 `copilot`）
- [ ] （選配）執行 03 註冊登入自動啟動

## 6. 新電腦重建步驟
1. Clone 本 repo。安裝 PowerShell 7（`pwsh`）與 Copilot CLI。
2. 編輯 `01-Setup-Environment.ps1` 的本機來源路徑（或設為空字串走下載），執行它。
3. 取得 Tunnel 憑證，二選一：
   - **A. 建立新 tunnel（建議）**：`C:\Tools\cloudflared.exe tunnel login` → `tunnel create webterminal` → 把新 ID 填入 `config.yml` 的 `tunnel` 與 `credentials-file`（路徑改為新電腦的 `%USERPROFILE%\.cloudflared\<ID>.json`）→ `tunnel route dns --overwrite-dns webterminal shell.andycheng.men`。
   - B. 沿用舊 tunnel：需把舊電腦的 `~\.cloudflared\b3794d5d-....json` 安全地搬過來（該檔是機密，**不可進 Git**）。
4. 建立 `secrets\ttyd-password.txt`（單行強密碼）。
5. 雙擊 `Start-WebTerminal.bat`；本機驗證：`curl -u andy:<密碼> http://127.0.0.1:8080/` 應回 200；`curl http://127.0.0.1:20241/ready` 應顯示 `readyConnections`。
6. 完成第 5 節的 Cloudflare Access 設定，再用手機測試。

## 7. 踩過的坑
- ttyd 在 Windows：必須加 `-W`（否則唯讀）與 `-w <工作目錄>`（否則 `CreateProcessW failed with error 267`）；程式名拼錯會是 error 2。
- cloudflared 不支援讀 Windows 系統憑證庫；若公司 SSL 攔截造成 `x509: certificate signed by unknown authority`，會自動重試，通常其他連線仍會成功註冊（本專案實測成功）。需要時可用 `--origin-ca-pool`。
- 用 `Stop-Process` 時一律用 `-Id`。

## 8. 機密管理（不可進 Git）
`secrets/`、`logs/`、`*.json`（tunnel 憑證）、`*.pem`（`cert.pem`）皆已列入 `.gitignore`。曾在對話中出現的舊 ttyd 密碼**視為已外洩，新電腦請換新密碼**。
