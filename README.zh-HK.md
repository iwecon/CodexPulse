# Codex Pulse

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.zh-CN.md">简体中文</a> ·
  <strong>繁體中文（香港）</strong> ·
  <a href="README.zh-TW.md">繁體中文（台灣）</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ko.md">한국어</a>
</p>

Codex Pulse 是以 SwiftUI 與 AppKit 製作的 macOS 桌面輔助程式。Dock 旁的**用量概覽面板**和**任務活動面板**會顯示本機 Codex Token 用量、每週限額及近期任務狀態。所有資料只從 Mac 讀取，絕不上載。

<p align="center">
  <a href="https://iwecon.github.io/CodexPulse/">
    <img src="docs/assets/codex-pulse-preview.jpg" alt="Codex Pulse 產品預覽：用量概覽面板與任務活動面板位於 macOS Dock 兩旁" width="1200">
  </a>
</p>

<p align="center">
  <a href="https://iwecon.github.io/CodexPulse/">產品網頁</a>
  ·
  <a href="https://github.com/iwecon/CodexPulse/releases/latest">下載最新版本</a>
  ·
  <a href="https://github.com/iwecon/CodexPulse">檢視原始碼</a>
</p>

在桌面瀏覽器中，產品網頁提供互動式 macOS 桌面示範，包含主題選單、可拖曳視窗、Activity Monitor 即時指標、與程式一致的 Dock 面板控制項，以及配合明暗主題的真實系統程式圖示。寬度 760px 或以下時則沿用直向流動版面。

## 安裝

Codex Pulse 需要 macOS 26 或以上版本。GitHub Actions 會分別為 Apple 晶片（arm64）及 Intel 晶片（x86_64）建立 DMG，並隨版本發佈至 [GitHub Releases](https://github.com/iwecon/CodexPulse/releases/latest)。

### AI 輔助安裝

請將以下提示完整交給你的編程助手：

```text
From https://iwecon.github.io/CodexPulse/ to Install CodexPulse. Try Homebrew first, then npm, and finally download and install via the GitHub Release Page.
```

### Homebrew

此儲存庫亦作為自訂 Tap：

```bash
brew tap iwecon/codex-pulse https://github.com/iwecon/CodexPulse
brew install --cask iwecon/codex-pulse/codex-pulse
```

### npm

npm 套件提供明確的安裝 CLI，不會在 `npm install` 時暗中掛載 DMG 或修改「應用程式」資料夾：

```bash
npm install -g github:iwecon/CodexPulse
codex-pulse install
```

預設安裝位置是 `~/Applications/Codex Pulse.app`。重新安裝可使用 `codex-pulse install --force`，安裝後可執行 `codex-pulse open`。儲存庫設定 npm 發佈憑證後，亦可使用 `npm install -g @iwecon/codex-pulse`。

### 簽署說明

目前公開版本採用臨時簽署，尚未使用 Apple Developer ID 簽署及公證。首次開啟下載版本時，macOS 可能顯示來源確認提示。設定 Developer ID 和公證憑證後，可將發佈工作流程升級為完整簽署及公證。

## 面板術語

- **用量概覽面板（Usage Overview Panel）**：Dock 位於畫面底部時顯示在左邊，摘要最近 14 日的 Token 用量趨勢及 Codex 每週限額。
- **任務活動面板（Task Activity Panel）**：Dock 位於畫面底部時顯示在右邊，依專案和工作階段顯示執行中及近期完成的 Codex 任務。

兩者按職責命名，是文件、需求及程式碼討論中的正式名稱。Dock 位於左邊或右邊時，用量概覽面板移至上方、任務活動面板移至下方，名稱不會隨位置改變。

## 功能

- 目前只啟用 Codex Token 用量統計。Claude Code 及 OpenCode 掃描器仍保留但預設停用，日後可透過 `UsageSourcePolicy.enabledTools` 重新啟用。
- 顯示最近 14 日用量趨勢，並在今日日期旁顯示今日 Token 消耗。
- 顯示 Codex 每週限額、剩餘百分比、重設時間、按剩餘時長分級的倒數（最後一分鐘顯示秒數），以及按精確剩餘時間換算的每日可用百分比。
- 任務活動面板按可見內容動態調整高度，通常最高 120px；從底部開始依專案和工作階段顯示所有執行中及最近 10 分鐘完成的任務。執行中任務不受 10 分鐘限制且必須全部顯示，必要時面板可超過 120px；餘下空間再按完成時間由新至舊放入已完成任務。執行中任務使用帶漸變拖尾的旋轉圓環；新增和移除任務有短暫過場並遵從「減少動態效果」設定。完成超過 3 分鐘的訊息會降低對比度，超過 10 分鐘便移除；最新用戶訊息按實際一至兩行緊湊顯示。
- 自動配合位於底部、左邊或右邊的 Dock 調整位置。
- 兩個主面板的內容、工作階段標題及專案標題統一使用白字與單一輕微黑影，主要和次要文字仍保留亮度層級。面板完全透明、不擷取畫面，亦不需要「螢幕錄製」權限。
- 兩個面板各自取樣下方桌面牆紙區域，為其他語意外觀元素選擇明暗狀態。系統外觀切換時會立即套用後備語意外觀，待牆紙過場完成後清除快取並恢復個別區域取樣。切換 Space、喚醒螢幕或恢復登入時會重新檢查牆紙檔案和顯示選項，只在狀態改變時重新取樣。
- 面板位於桌面圖示之上、一般程式視窗之下，不會遮蓋目前使用中的程式。
- 指標在任何面板內靜止 0.5 秒後，內側縮放邊緣會顯示橫跨內容寬度的統一 Liquid Glass 橫向控制組；移動指標會重新計時。兩個面板使用相同淡入動畫。玻璃表面採連續圓角；34px 縮放區段位於內容內側，在左面板靠右、右面板靠左，並與操作按鈕一樣回應 6px 外圍內距。其餘按鈕平均填滿操作區。左面板固定左邊緣並從右邊縮放，右面板相反；底部 Dock 較高時，互動區會向上延伸。指標離開面板和控制組的聯合範圍後，控制組等待 1 秒才淡出；返回或拖曳時保持顯示。
- 指標進入 34px 縮放區段時，其他按鈕會在 0.34 秒內縮至 0.98 並淡出。外層 Liquid Glass 背景維持完整寬度，只把 6px 內距向內收縮、圓角轉為 10px，然後淡至透明。動畫完成後互動視窗才縮至縮放區段，避免透明區攔截點按。離開縮放區段不會復原；只有進入實際操作按鈕範圍才反向恢復。拖曳期間只保留縮放區段，直至放開指標。
- 左右移動按鈕永遠可用，可把面板移到另一邏輯側；移動後按鈕方向反轉。兩個面板同側時另有上下交換按鈕。底部 Dock 的邏輯側是左右，垂直 Dock 則是上下。位置和各面板寬度會持久保存，重新啟動時復原，並按目前畫面、Dock 和可用空間限制以免重疊。用量概覽面板位於邏輯右側時，趨勢及限額版面會鏡像並靠右。
- 任務活動面板控制組的文字對齊按鈕會循環切換自動、靠左及靠右，圖示和選擇均同步並持久保存。自動模式在邏輯左側靠左、右側靠右；靠右時，時長移至狀態圖示之前。
- 用量概覽面板控制組提供語言按鈕，按下後以原生 AppKit 直向滾輪選擇器取代操作區。可點按語言、按住上下拖曳，或用滑鼠滾輪及觸控板即時切換。支援中國大陸簡體中文、香港繁體中文、台灣繁體中文、日文、韓文和英文；選擇套用至兩個面板、日期格式、AppKit 輔助使用標籤和工具提示，並只儲存在本機 `UserDefaults`。首次啟動預設為中國大陸簡體中文。
- 一般面板內容保持點按穿透且不啟用程式。任務活動面板的工作階段標題可點按，並在 ChatGPT 開啟相應 Codex 對話；獨立的 Liquid Glass 控制組仍可接收指標輸入。
- 非 Debug `.app` 首次啟動時會設定登入時啟動。

Codex 限額以工作階段日誌中事件時間最新的 `rate_limits` 快照為準，避免舊工作階段覆蓋目前限額；只有日誌實際包含該欄位時才會顯示。

## 資源使用

- 首次啟動會讀取現有歷史資料。JSONL 以固定大小分段逐行解析，不會把整個日誌同時展開成 `Data` 和 `String`。
- Codex 解析結果按檔案快取，之後只重新解析新增或變更的檔案。已停用的 Claude Code 及 OpenCode 仍保留各自的檔案及資料庫/WAL/SHM 快取，重新啟用後繼續增量掃描。
- Codex 任務日誌按位元組游標增量讀取；任務索引查詢會短暫快取，避免每次輪詢 SQLite。
- 用戶工作階段鎖定或螢幕休眠時，會暫停用量和任務重新整理，並凍結執行中任務動畫；解鎖及喚醒後立即恢復。
- 相同資料不會重複發佈 SwiftUI 狀態。倒數、任務時長和活動指示只更新所需的小型葉節點檢視，避免整個面板高頻重繪。

大量本機歷史資料仍可能令冷啟動短暫出現記憶體高峰，但首次掃描後應回到穩定狀態；週期重新整理不應再完整掃描所有歷史檔案。

## 系統要求

- macOS 26+
- Xcode 26+ / Swift 6.2+
- SQLite 3

## 執行

```bash
swift run "Codex Pulse"
```

程式以 accessory 模式執行，不顯示 Dock 圖示。`swift run`、其他原始可執行檔及 Debug 版本都不會讀取、寫入或設定登入項目。只有非 Debug `.app` 會使用 macOS `SMAppService` 設定登入時啟動。

若用戶在「系統設定」停用登入項目，程式日後正常啟動時不會強制重新啟用。

## 發佈

推送如 `v0.1.0` 的標籤會觸發 `.github/workflows/release.yml`，在 GitHub 託管的 macOS 26 arm64 及 Intel 執行器上分別建立：

- `Codex-Pulse-arm64.dmg`
- `Codex-Pulse-x86_64.dmg`
- `SHA256SUMS`

工作流程隨後建立或更新相應 GitHub Release。若設定儲存庫變數 `PUBLISH_NPM=true` 及 npm 憑證 `NPM_TOKEN`，同一版本亦會發佈為 `@iwecon/codex-pulse`。

## 測試

```bash
swift test
```

測試涵蓋日誌解析、日期處理、最新 Codex 限額選擇、任務狀態、緊湊數字格式、登入啟動資格、Dock 面板排列和控制組幾何、視窗層級、牆紙座標映射與外觀選擇、牆紙快取失效，以及鎖定和休眠時的重新整理狀態切換。

## 資料來源

- Codex 用量（已啟用）：`~/.codex/sessions/**/*.jsonl`
- Codex 任務索引：`~/.codex/state_*.sqlite`
- Claude Code（已停用，保留入口）：`~/.claude/projects/**/*.jsonl`
- OpenCode（已停用，保留入口）：`~/.local/share/opencode/opencode.db`

已啟用的資料來源不存在或無法讀取時，只會影響相應工具。Codex Pulse 不會上載資料或修改原始工作階段記錄；已停用來源不會存取其本機檔案。
