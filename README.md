# Web Terminal：用手機瀏覽器操作 Windows PowerShell（含 Copilot CLI）

> 語言：繁體中文。給人類與 AI 快速接手用。細節與踩坑紀錄見 [HANDOFF.md](HANDOFF.md)，Cloudflare 後台清單見 [CHECKLIST.md](CHECKLIST.md)。

## 1. 這個專案在做什麼（30 秒版）

公司筆電的防火牆只放行 HTTPS/443、擋 SSH。本專案讓使用者在手機瀏覽器開 `https://shell.andycheng.men`，通過驗證後就能操作這台筆電的 PowerShell，並執行 `copilot`（GitHub Copilot CLI）。

本專案**不是應用程式**，只是一組 PowerShell 腳本加設定檔，負責把兩個現成工具串起來：

- **ttyd**：把本機 `pwsh` 變成網頁終端機。
- **cloudflared**：用 Cloudflare Tunnel 把本機服務安全地公開到網際網路，不需開防火牆或對外開埠。

## 2. 架構

```
手機瀏覽器
   │ HTTPS (443)
   ▼
Cloudflare Access  ← 第 1 層驗證：Email One-time PIN（僅允許指定 Email）
   │
Cloudflare Tunnel（cloudflared 主動對外連線，protocol: http2，走 443）
   │
cloudflared（本機）
   │ http://localhost:8080
   ▼
ttyd（只綁 127.0.0.1:8080） ← 第 2 層驗證：HTTP Basic Auth（帳號 andy + 密碼）
   │
   ▼
pwsh（PowerShell 7，起始目錄 %USERPROFILE%）
```

重點：ttyd 只綁 `127.0.0.1`，外部只能經由 Tunnel 到達；Tunnel 前面有 Access，所以要連續過兩關。

## 3. 重要資訊

| 項目 | 值 |
|---|---|
| 對外網址 | `https://shell.andycheng.men`（網域託管於 Cloudflare） |
| Tunnel 名稱 / ID | `webterminal-new` / `a49c136b-d3c2-4471-a39d-8f1a6e5bf2f5` |
| 舊 Tunnel | `webterminal`（舊電腦建立，名稱被占用，已不使用，可自行刪除） |
| 不要動的 Tunnel | `Company-copilot`（屬於另一專案 `copilot-openai-proxy`） |
| Access 允許的 Email | `swps9940902@gmail.com`（One-time PIN） |
| ttyd 帳號 | `andy` |
| ttyd 密碼 | 在本機 `secrets\ttyd-password.txt`（單行純文字，**不在 Git**） |
| 本機 ttyd | `http://127.0.0.1:8080` |
| cloudflared 狀態 | `http://127.0.0.1:20241/ready`（看 `readyConnections`） |
| 工具位置 | `C:\Tools\`（無權限則 `%USERPROFILE%\Tools`，路徑記錄於 `toolsdir.txt`） |

## 4. 檔案說明

| 檔案 | 用途 |
|---|---|
| `01-Setup-Environment.ps1` | 下載 ttyd、cloudflared 到 `C:\Tools\`（已存在則跳過）。可設定 `$LocalTtydSource/$LocalCfdSource` 使用本機現有檔，空字串則從 GitHub 下載 |
| `02-Start-Services.ps1` | 讀取密碼，先停掉舊程序，再以隱藏視窗啟動 ttyd 與 cloudflared，日誌寫到 `logs\` |
| `03-Register-StartupTask.ps1` | 選配：註冊登入時自動啟動的排程（Limited 權限）。目前未註冊 |
| `Start-WebTerminal.bat` / `Stop-WebTerminal.bat` | 雙擊啟動／停止 |
| `config.yml` | cloudflared 設定：tunnel ID、憑證路徑、`protocol: http2`、ingress 指向 `http://localhost:8080` |
| `CHECKLIST.md` | Cloudflare 後台手動設定清單 |
| `HANDOFF.md` | 交接文件：限制、踩坑、重建步驟 |
| `secrets\` `logs\` `*.json` `*.pem` | 本機機密與日誌，皆在 `.gitignore`，**不可進 Git** |

## 5. 日常使用

- **啟動**：雙擊 `Start-WebTerminal.bat`（等同執行 `02-Start-Services.ps1`）。
- **停止**：雙擊 `Stop-WebTerminal.bat`。不用時建議關閉。
- **手機使用**：開 `https://shell.andycheng.men` → 輸入 Email → 輸入信箱收到的 OTP → 輸入 ttyd 帳密 → 進入 PowerShell → 執行 `copilot`。

### 本機驗證

```powershell
# ttyd 應回 200
$pw = (Get-Content secrets\ttyd-password.txt -Raw).Trim()
curl.exe -u "andy:$pw" -o NUL -w "%{http_code}" http://127.0.0.1:8080/

# cloudflared 應顯示 readyConnections >= 1
curl.exe http://127.0.0.1:20241/ready

# 程序與日誌
Get-Process ttyd,cloudflared
Get-Content logs\cloudflared.log -Tail 10
```

未通過 Access 時，公網網址回應 `401` 或 Access 登入頁都屬正常。

### 更換 ttyd 密碼

1. 改 `secrets\ttyd-password.txt`（單行，無多餘空白）。
2. 執行 `Stop-WebTerminal.bat`，再執行 `Start-WebTerminal.bat`。

## 6. 在新電腦重建

1. Clone 本 repo；安裝 PowerShell 7（`pwsh`）與 Copilot CLI。
2. 執行 `01-Setup-Environment.ps1`（本機來源路徑留空即走下載）。
3. 建立 tunnel：
   ```powershell
   C:\Tools\cloudflared.exe tunnel login
   C:\Tools\cloudflared.exe tunnel create <名稱>
   C:\Tools\cloudflared.exe tunnel route dns --overwrite-dns <名稱> shell.andycheng.men
   ```
   名稱若已被占用就換一個。把新 ID 填入 `config.yml` 的 `tunnel` 與 `credentials-file`（`%USERPROFILE%\.cloudflared\<ID>.json`）。
4. 建立 `secrets\ttyd-password.txt`（單行強密碼，例如 24 字元隨機英數）。
5. 雙擊 `Start-WebTerminal.bat` 並做上述本機驗證。
6. Cloudflare Zero Trust 的 Access 設定（網域與 Email 不變時通常已存在，不必重做）：
   - Settings → Authentication：啟用 One-time PIN。
   - Access → Applications → Self-hosted，網域 `shell.andycheng.men`，Login methods 只勾 One-time PIN。
   - Policy：Allow，Include → Emails → 本人 Email。
   - 建議加 Require → Country → Taiwan，Session 1～8 小時。

## 7. 安全模型與注意事項

- 這個終端機等於這台電腦的完整控制權，務必保持兩層驗證。
- 第 1 層強度取決於該 Gmail 的安全，請開兩步驟驗證。
- 密碼、`cert.pem`、tunnel 憑證 `*.json` 絕對不可進 Git。曾在對話或畫面中出現的密碼視為外洩，需更換。
- 不使用時請停止服務；使用者層級安裝，不需系統管理員權限，也不需 IT 密碼。
- 公司 IT 已同意對外 Tunnel。

## 8. 踩過的坑（精簡）

- **路徑含空格**（如 `OneDrive - LITE-ON ...`）：傳給 cloudflared 的 `--config` 必須加引號，`02` 已處理。
- **ttyd on Windows**：必須加 `-W`（否則唯讀）與 `-w <目錄>`（否則 `CreateProcessW failed with error 267`）。
- **`.ps1` 必須是 UTF-8 with BOM**，否則 Windows PowerShell 5.1 會把中文註解讀成亂碼而語法錯誤。編輯後請保持 BOM。
- **x509 unknown authority**：公司 SSL 攔截造成，cloudflared 會重試，通常其他連線仍會成功註冊。必要時用 `--origin-ca-pool`。
- **tunnel 名稱已存在**：`tunnel create` 會失敗，換新名稱即可，不要刪別人在用的 tunnel。
- **Zscaler**：舊文件說連公網網址會被擋 403，但在目前網路實測正常（回 401 表示通路 OK）。若真被擋，改用手機行動網路測試。
- 結束程序一律用 `Stop-Process -Id <PID>`。

## 9. 目前狀態

- 本機服務、Tunnel、DNS、Cloudflare Access 皆已完成，手機實測可進入終端機。
- 選配未做：`03-Register-StartupTask.ps1`（開機自動啟動）。
- 待辦建議：更換曾外露的 ttyd 密碼；Policy 加國家限制。

## 10. 給 AI 的接手指引

- 使用者語言：繁體中文；Windows 路徑用反斜線；指令用 PowerShell。
- 不要把任何機密寫進 repo 或貼到對話。
- 修改 `.ps1` 要保留 UTF-8 BOM。
- 不要動 `Company-copilot` tunnel，也不要擅自刪除 tunnel 或 DNS 記錄。
- Cloudflare 後台（Zero Trust）無法由腳本完成，需指導使用者手動操作。
