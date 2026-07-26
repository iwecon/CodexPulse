const translations = {
  "zh-CN": {
    skip: "跳到主要内容", brandHome: "Codex Pulse 首页", navigation: "主要导航",
    navFeatures: "功能", navPrivacy: "隐私", navStart: "开始使用",
    themeLabel: "主题", themeAuto: "自动", themeLight: "浅色", themeDark: "深色", languageLabel: "语言",
    menuInstall: "安装", installMenuLabel: "安装 Codex Pulse", installAI: "使用 AI 安装",
    installAIDetail: "复制安装提示词", copyAction: "复制", copySuccess: "已复制", copyFailure: "复制失败",
    dmgArchitectures: "Apple 芯片与 Intel 版本", featuresMenuLabel: "Codex Pulse 功能",
    menuUsageTitle: "用量概览", menuUsageDetail: "Codex、Claude Code 与 OpenCode 的 14 天 Token 趋势与 Codex 周额度",
    menuTasksTitle: "任务活动", menuTasksDetail: "按项目与会话查看三款工具运行中及近期任务",
    menuAdaptiveTitle: "自适应文字颜色", menuAdaptiveDetail: "按壁纸自动选择深浅文字，工具配色可自定义",
    menuDockTitle: "贴近 Dock", menuDockDetail: "支持底部、左侧与右侧 Dock 布局",
    menuHintTitle: "操作提醒", menuHintDetail: "鼠标指针移动至面板上静止 0.5s 可唤醒操作菜单",
    menuPrivacyNote: "只读本机 Codex / Claude Code / OpenCode 数据 · 无需屏幕录制权限", themeMenuLabel: "选择主题",
    title: "Codex Pulse — 让 Codex 的每一次脉动，都留在桌面上",
    description: "Codex Pulse 是一款贴着 macOS Dock 展示 Codex、Claude Code 与 OpenCode Token 用量、Codex 周额度与任务状态的本地桌面配件。",
    heroTitle: "让 Codex 的每一次脉动，<br>都留在桌面上。",
    heroBody: "贴着 Dock 查看 Codex、Claude Code 与 OpenCode 的 Token 用量、周额度与任务状态。只读本机数据，不打断当前工作。",
    viewGithub: "在 GitHub 查看", quickStart: "快速开始", previewLabel: "Codex Pulse 界面示意",
    menuFile: "文件", menuEdit: "编辑", menuWindow: "窗口",
    usagePanelLabel: "用量概览面板示意", taskPanelLabel: "任务活动面板示意",
    panelLast14: "近 14 天", panelToday: "今日",
    panelWeekly: "周限额", panelUsed: "已用 32%", panelRemaining: "剩余 68%",
    panelResetAt: "7月27日 08:00 重置", panelDaily: "日均可用 17%", panelCountdown: "3 天 14 小时后重置",
    panelSession: "# 打磨公开发布体验", panelSession2: "# 同步落地页文案", panelSession3: "# 发布前检查",
    panelTask1: "像素级复刻两个 Dock 面板", panelTask3: "运行完整测试", panelTask4: "同步 v1.0.0 之后的功能变化",
    mockupNote: "HTML/CSS 界面复刻 · 演示数据",
    featuresTitle: "专注写代码，<br>其余交给桌面。",
    featuresBody: "两个透明、非激活面板安静地贴在 Dock 两侧。需要时扫一眼，不需要时它们留在应用窗口之后。",
    featureUsageTitle: "用量一眼看清", featureUsageBody: "Codex、Claude Code 与 OpenCode 的 14 天 Token 趋势按工具分色堆叠，配合今日消耗、Codex 周额度与重置倒计时，安静地待在 Dock 一侧。",
    trendLast14: "最近 14 天", trendToday: "今日 1.42M",
    featureTasksTitle: "任务状态，贴着 Dock 发生", featureTasksBody: "按项目与会话查看 Codex、Claude Code 与 OpenCode 的执行中和最近完成任务，状态图标按工具着色，Codex 会话标题可直接回到 ChatGPT。",
    miniSession: "发布落地页", miniTask1: "验证桌面与移动端视觉", miniTask2: "运行完整测试", miniTask4: "同步 v1.0.0 之后的功能变化",
    featurePlacementTitle: "跟着你的桌面走", featurePlacementBody: "支持 Dock 位于底部、左侧或右侧，面板位置、宽度与文字对齐均可调整并保存。",
    featureAdaptiveTitle: "文字颜色，跟着壁纸走",
    featureAdaptiveBody: "面板取样下方壁纸，以 APCA 感知对比度自动选择深浅文字，并在 OKLCh 中延续壁纸色相；每个工具的用量条颜色也可以自定义。",
    privacyTitle: "你的数据，<br>不离开这台 Mac。",
    privacyBody: "Codex Pulse 只读扫描本机 Codex、Claude Code 与 OpenCode 的会话记录与任务索引，不上传用量数据，也不会修改原始记录。",
    privacy1: "只读 Codex、Claude Code 与 OpenCode 本机数据", privacy2: "无需屏幕录制权限", privacy3: "休眠或锁屏时暂停刷新",
    codexWindowLabel: "Codex 窗口示意", codexNewTask: "新任务", codexThread1: "完善发布体验",
    codexThread2: "优化面板布局", codexThread3: "验证用量扫描",
    codexPrompt: "把落地页的预览做得和真实应用一致，并提供双架构安装包。",
    codexReply: "已完成面板复刻、主题切换与发布配置。", codexComposer: "继续向 Codex 提问…",
    codexRecent: "最近", codexStep1: "按源码规格重建两个 Dock 面板", codexStep2: "校准文字阴影与状态图标", codexStep3: "运行完整测试",
    startTitle: "选择安装方式。", startBody: "需要 macOS 26+。GitHub Release 会分别提供 Apple 芯片与 Intel 芯片版本。",
    installDmg: "下载 DMG", downloadLatest: "下载最新版", footerTagline: "本地、克制，贴着 Dock 发生。"
  },
  "zh-HK": {
    skip: "跳至主要內容", brandHome: "Codex Pulse 首頁", navigation: "主要導覽",
    navFeatures: "功能", navPrivacy: "私隱", navStart: "開始使用",
    themeLabel: "主題", themeAuto: "自動", themeLight: "淺色", themeDark: "深色", languageLabel: "語言",
    menuInstall: "安裝", installMenuLabel: "安裝 Codex Pulse", installAI: "使用 AI 安裝",
    installAIDetail: "複製安裝提示詞", copyAction: "複製", copySuccess: "已複製", copyFailure: "複製失敗",
    dmgArchitectures: "Apple 晶片與 Intel 版本", featuresMenuLabel: "Codex Pulse 功能",
    menuUsageTitle: "用量概覽", menuUsageDetail: "Codex、Claude Code 與 OpenCode 的 14 日 Token 趨勢與 Codex 每週限額",
    menuTasksTitle: "任務活動", menuTasksDetail: "按專案與工作階段查看三款工具進行中及近期任務",
    menuAdaptiveTitle: "自適應文字顏色", menuAdaptiveDetail: "按牆紙自動選擇深淺文字，工具配色可自訂",
    menuDockTitle: "貼近 Dock", menuDockDetail: "支援底部、左側與右側 Dock 佈局",
    menuHintTitle: "操作提示", menuHintDetail: "將滑鼠指標移至面板上並靜止 0.5 秒，即可喚醒操作選單",
    menuPrivacyNote: "唯讀本機 Codex / Claude Code / OpenCode 資料 · 毋須螢幕錄影權限", themeMenuLabel: "選擇主題",
    title: "Codex Pulse — 讓 Codex 的每一次脈動，都留在桌面上",
    description: "Codex Pulse 是一款貼近 macOS Dock，顯示 Codex、Claude Code 與 OpenCode Token 用量、Codex 每週限額與任務狀態的本機桌面工具。",
    heroTitle: "讓 Codex 的每一次脈動，<br>都留在桌面上。",
    heroBody: "貼近 Dock 查看 Codex、Claude Code 與 OpenCode 的 Token 用量、每週限額與任務狀態。唯讀本機資料，不打斷當前工作。",
    viewGithub: "在 GitHub 查看", quickStart: "快速開始", previewLabel: "Codex Pulse 介面示意",
    menuFile: "檔案", menuEdit: "編輯", menuWindow: "視窗",
    usagePanelLabel: "用量概覽面板示意", taskPanelLabel: "任務活動面板示意",
    panelLast14: "近 14 日", panelToday: "今日",
    panelWeekly: "每週限額", panelUsed: "已用 32%", panelRemaining: "剩餘 68%",
    panelResetAt: "7月27日 08:00 重設", panelDaily: "每日可用 17%", panelCountdown: "3 日 14 小時後重設",
    panelSession: "# 完善公開發佈體驗", panelSession2: "# 同步落地頁文案", panelSession3: "# 發佈前檢查",
    panelTask1: "像素級重現兩個 Dock 面板", panelTask3: "執行完整測試", panelTask4: "同步 v1.0.0 之後的功能變化",
    mockupNote: "HTML/CSS 介面重現 · 示範資料",
    featuresTitle: "專注寫程式，<br>其餘交給桌面。",
    featuresBody: "兩個透明、非啟用面板安靜地貼在 Dock 兩側。需要時看一眼，不需要時留在應用程式視窗之後。",
    featureUsageTitle: "用量一目了然", featureUsageBody: "Codex、Claude Code 與 OpenCode 的 14 日 Token 趨勢按工具分色堆疊，配合今日消耗、Codex 每週限額與重設倒數，安靜地留在 Dock 一側。",
    trendLast14: "最近 14 日", trendToday: "今日 1.42M",
    featureTasksTitle: "任務狀態，貼近 Dock 發生", featureTasksBody: "按專案與工作階段查看 Codex、Claude Code 與 OpenCode 進行中及最近完成的任務，狀態圖示按工具著色，Codex 工作階段標題可直接返回 ChatGPT。",
    miniSession: "發佈落地頁", miniTask1: "驗證桌面與流動版畫面", miniTask2: "執行完整測試", miniTask4: "同步 v1.0.0 之後的功能變化",
    featurePlacementTitle: "跟隨你的桌面", featurePlacementBody: "支援 Dock 位於底部、左側或右側；面板位置、寬度和文字對齊均可調整並儲存。",
    featureAdaptiveTitle: "文字顏色，跟著牆紙走",
    featureAdaptiveBody: "面板會取樣下方牆紙，以 APCA 感知對比度自動選擇深淺文字，並在 OKLCh 中延續牆紙色相；每款工具的用量條顏色亦可自訂。",
    privacyTitle: "你的資料，<br>不會離開這部 Mac。",
    privacyBody: "Codex Pulse 只會以唯讀方式掃描本機 Codex、Claude Code 與 OpenCode 的工作階段記錄與任務索引，不會上載用量資料或修改原始記錄。",
    privacy1: "唯讀 Codex、Claude Code 與 OpenCode 本機資料", privacy2: "毋須螢幕錄影權限", privacy3: "睡眠或鎖定時暫停更新",
    codexWindowLabel: "Codex 視窗示意", codexNewTask: "新任務", codexThread1: "完善發佈體驗",
    codexThread2: "優化面板佈局", codexThread3: "驗證用量掃描",
    codexPrompt: "讓落地頁預覽與真實應用程式一致，並提供雙架構安裝套件。",
    codexReply: "已完成面板重現、主題切換與發佈設定。", codexComposer: "繼續向 Codex 提問…",
    codexRecent: "最近", codexStep1: "按原始碼規格重建兩個 Dock 面板", codexStep2: "校準文字陰影與狀態圖示", codexStep3: "執行完整測試",
    startTitle: "選擇安裝方式。", startBody: "需要 macOS 26+。GitHub Release 分別提供 Apple 晶片與 Intel 晶片版本。",
    installDmg: "下載 DMG", downloadLatest: "下載最新版本", footerTagline: "本機、克制，貼近 Dock 發生。"
  },
  "zh-TW": {
    skip: "跳到主要內容", brandHome: "Codex Pulse 首頁", navigation: "主要導覽",
    navFeatures: "功能", navPrivacy: "隱私", navStart: "開始使用",
    themeLabel: "主題", themeAuto: "自動", themeLight: "淺色", themeDark: "深色", languageLabel: "語言",
    menuInstall: "安裝", installMenuLabel: "安裝 Codex Pulse", installAI: "使用 AI 安裝",
    installAIDetail: "複製安裝提示詞", copyAction: "複製", copySuccess: "已複製", copyFailure: "複製失敗",
    dmgArchitectures: "Apple 晶片與 Intel 版本", featuresMenuLabel: "Codex Pulse 功能",
    menuUsageTitle: "用量概覽", menuUsageDetail: "Codex、Claude Code 與 OpenCode 的 14 天 Token 趨勢與 Codex 每週限額",
    menuTasksTitle: "任務活動", menuTasksDetail: "依專案與工作階段查看三款工具執行中及近期任務",
    menuAdaptiveTitle: "自適應文字顏色", menuAdaptiveDetail: "依桌布自動選擇深淺文字，工具配色可自訂",
    menuDockTitle: "貼近 Dock", menuDockDetail: "支援底部、左側與右側 Dock 配置",
    menuHintTitle: "操作提醒", menuHintDetail: "將滑鼠游標移至面板並靜止 0.5 秒，即可喚醒操作選單",
    menuPrivacyNote: "唯讀本機 Codex / Claude Code / OpenCode 資料 · 不需螢幕錄影權限", themeMenuLabel: "選擇主題",
    title: "Codex Pulse — 讓 Codex 的每一次脈動，都留在桌面上",
    description: "Codex Pulse 是一款貼著 macOS Dock 顯示 Codex、Claude Code 與 OpenCode Token 用量、Codex 每週限額與任務狀態的本機桌面工具。",
    heroTitle: "讓 Codex 的每一次脈動，<br>都留在桌面上。",
    heroBody: "貼著 Dock 查看 Codex、Claude Code 與 OpenCode 的 Token 用量、每週限額與任務狀態。唯讀本機資料，不打斷目前工作。",
    viewGithub: "在 GitHub 查看", quickStart: "快速開始", previewLabel: "Codex Pulse 介面示意",
    menuFile: "檔案", menuEdit: "編輯", menuWindow: "視窗",
    usagePanelLabel: "用量概覽面板示意", taskPanelLabel: "任務活動面板示意",
    panelLast14: "近 14 天", panelToday: "今日",
    panelWeekly: "每週限額", panelUsed: "已用 32%", panelRemaining: "剩餘 68%",
    panelResetAt: "7月27日 08:00 重設", panelDaily: "日均可用 17%", panelCountdown: "3 天 14 小時後重設",
    panelSession: "# 打磨公開發布體驗", panelSession2: "# 同步落地頁文案", panelSession3: "# 發布前檢查",
    panelTask1: "像素級重現兩個 Dock 面板", panelTask3: "執行完整測試", panelTask4: "同步 v1.0.0 之後的功能變化",
    mockupNote: "HTML/CSS 介面重現 · 示範資料",
    featuresTitle: "專注寫程式，<br>其餘交給桌面。",
    featuresBody: "兩個透明、非啟用面板安靜地貼在 Dock 兩側。需要時看一眼，不需要時留在應用程式視窗之後。",
    featureUsageTitle: "用量一目瞭然", featureUsageBody: "Codex、Claude Code 與 OpenCode 的 14 天 Token 趨勢依工具分色堆疊，搭配今日消耗、Codex 每週限額與重設倒數，安靜地待在 Dock 一側。",
    trendLast14: "最近 14 天", trendToday: "今日 1.42M",
    featureTasksTitle: "任務狀態，貼著 Dock 發生", featureTasksBody: "依專案與工作階段查看 Codex、Claude Code 與 OpenCode 執行中及最近完成的任務，狀態圖示依工具著色，Codex 工作階段標題可直接回到 ChatGPT。",
    miniSession: "發布落地頁", miniTask1: "驗證桌面與行動版畫面", miniTask2: "執行完整測試", miniTask4: "同步 v1.0.0 之後的功能變化",
    featurePlacementTitle: "跟著你的桌面走", featurePlacementBody: "支援 Dock 位於底部、左側或右側；面板位置、寬度與文字對齊都能調整並儲存。",
    featureAdaptiveTitle: "文字顏色，跟著桌布走",
    featureAdaptiveBody: "面板會取樣下方桌布，以 APCA 感知對比度自動選擇深淺文字，並在 OKLCh 中延續桌布色相；每款工具的用量條顏色也可以自訂。",
    privacyTitle: "你的資料，<br>不會離開這台 Mac。",
    privacyBody: "Codex Pulse 只會以唯讀方式掃描本機 Codex、Claude Code 與 OpenCode 的工作階段記錄與任務索引，不會上傳用量資料或修改原始記錄。",
    privacy1: "唯讀 Codex、Claude Code 與 OpenCode 本機資料", privacy2: "不需螢幕錄影權限", privacy3: "睡眠或鎖定時暫停更新",
    codexWindowLabel: "Codex 視窗示意", codexNewTask: "新任務", codexThread1: "完善發布體驗",
    codexThread2: "最佳化面板配置", codexThread3: "驗證用量掃描",
    codexPrompt: "讓落地頁預覽與真實應用程式一致，並提供雙架構安裝套件。",
    codexReply: "已完成面板重現、主題切換與發布設定。", codexComposer: "繼續向 Codex 提問…",
    codexRecent: "最近", codexStep1: "依原始碼規格重建兩個 Dock 面板", codexStep2: "校準文字陰影與狀態圖示", codexStep3: "執行完整測試",
    startTitle: "選擇安裝方式。", startBody: "需要 macOS 26+。GitHub Release 分別提供 Apple 晶片與 Intel 晶片版本。",
    installDmg: "下載 DMG", downloadLatest: "下載最新版本", footerTagline: "本機、克制，貼著 Dock 發生。"
  },
  ja: {
    skip: "メインコンテンツへ移動", brandHome: "Codex Pulse ホーム", navigation: "メインナビゲーション",
    navFeatures: "機能", navPrivacy: "プライバシー", navStart: "はじめる",
    themeLabel: "テーマ", themeAuto: "自動", themeLight: "ライト", themeDark: "ダーク", languageLabel: "言語",
    menuInstall: "インストール", installMenuLabel: "Codex Pulse をインストール", installAI: "AI でインストール",
    installAIDetail: "インストール用プロンプトをコピー", copyAction: "コピー", copySuccess: "コピー済み", copyFailure: "コピー失敗",
    dmgArchitectures: "Apple Silicon / Intel 版", featuresMenuLabel: "Codex Pulse の機能",
    menuUsageTitle: "使用量概要", menuUsageDetail: "Codex・Claude Code・OpenCode の14日間 Token 推移と Codex 週間上限",
    menuTasksTitle: "タスクアクティビティ", menuTasksDetail: "3つのツールの実行中・最近のタスクをプロジェクトとセッション別に表示",
    menuAdaptiveTitle: "壁紙に適応する文字色", menuAdaptiveDetail: "壁紙に合わせて文字の明暗を自動選択、ツールの色はカスタマイズ可能",
    menuDockTitle: "Dock に沿って配置", menuDockDetail: "Dock の下・左・右配置に対応",
    menuHintTitle: "操作のヒント", menuHintDetail: "ポインタをパネル上で 0.5 秒静止すると操作メニューが表示されます",
    menuPrivacyNote: "ローカルの Codex / Claude Code / OpenCode データを読み取り専用で使用 · 画面収録権限不要", themeMenuLabel: "テーマを選択",
    title: "Codex Pulse — Codex の鼓動をデスクトップに",
    description: "Codex Pulse は macOS Dock の横に Codex・Claude Code・OpenCode の Token 使用量、Codex の週間上限、タスク状態を表示するローカルデスクトップアクセサリです。",
    heroTitle: "Codex の鼓動を、<br>デスクトップに。",
    heroBody: "Dock の横で Codex・Claude Code・OpenCode の Token 使用量、週間上限、タスク状態を確認。ローカルデータを読み取るだけで、作業を妨げません。",
    viewGithub: "GitHub で見る", quickStart: "クイックスタート", previewLabel: "Codex Pulse インターフェースのプレビュー",
    menuFile: "ファイル", menuEdit: "編集", menuWindow: "ウインドウ",
    usagePanelLabel: "使用量概要パネルのプレビュー", taskPanelLabel: "タスクアクティビティパネルのプレビュー",
    panelLast14: "過去14日", panelToday: "本日",
    panelWeekly: "週間上限", panelUsed: "使用済み 32%", panelRemaining: "残り 68%",
    panelResetAt: "7月27日 08:00 リセット", panelDaily: "1日平均 17%", panelCountdown: "3日14時間後にリセット",
    panelSession: "# 公開リリースを仕上げる", panelSession2: "# ランディングページの文言を同期", panelSession3: "# リリース前チェック",
    panelTask1: "2つの Dock パネルを忠実に再現", panelTask3: "全テストを実行", panelTask4: "v1.0.0 以降の変更を反映",
    mockupNote: "HTML/CSS による再現 · デモデータ",
    featuresTitle: "コードに集中。<br>あとはデスクトップへ。",
    featuresBody: "透明な2つの非アクティブパネルが Dock の両側に静かに常駐。必要なときだけ目に入り、普段はアプリの後ろに留まります。",
    featureUsageTitle: "使用量をひと目で", featureUsageBody: "Codex・Claude Code・OpenCode の14日間 Token 推移をツール別の色で積み上げ表示。今日の使用量、Codex 週間上限、リセットまでの時間も Dock の横に。",
    trendLast14: "過去14日", trendToday: "今日 1.42M",
    featureTasksTitle: "タスクの動きを Dock のそばに", featureTasksBody: "プロジェクトとセッション別に Codex・Claude Code・OpenCode のタスクを確認。状態アイコンはツールごとに色分けされ、Codex のセッションタイトルから ChatGPT に戻れます。",
    miniSession: "ランディングページを公開", miniTask1: "デスクトップとモバイル表示を確認", miniTask2: "全テストを実行", miniTask4: "v1.0.0 以降の変更を反映",
    featurePlacementTitle: "デスクトップに追従", featurePlacementBody: "Dock の下・左・右配置に対応。パネル位置、幅、文字揃えを調整して保存できます。",
    featureAdaptiveTitle: "文字色は、壁紙に寄り添う",
    featureAdaptiveBody: "パネルは下の壁紙をサンプリングし、APCA 知覚コントラストで文字の明暗を自動選択、OKLCh で壁紙の色相を引き継ぎます。ツールごとの使用量バーの色もカスタマイズできます。",
    privacyTitle: "データは、<br>この Mac の中だけ。",
    privacyBody: "Codex Pulse はローカルの Codex・Claude Code・OpenCode のセッション記録とタスクインデックスを読み取り専用で確認し、使用量の送信や元データの変更はしません。",
    privacy1: "Codex・Claude Code・OpenCode のローカルデータのみ読み取り", privacy2: "画面収録の権限は不要", privacy3: "スリープ・ロック中は更新を停止",
    codexWindowLabel: "Codex ウインドウのプレビュー", codexNewTask: "新しいタスク", codexThread1: "公開リリースを仕上げる",
    codexThread2: "パネル配置を最適化", codexThread3: "使用量スキャンを検証",
    codexPrompt: "ランディングページを実際のアプリに合わせ、2つのアーキテクチャ向けインストーラを用意してください。",
    codexReply: "パネルの再現、テーマ切替、リリース設定が完了しました。", codexComposer: "Codex に続けて質問…",
    codexRecent: "最近", codexStep1: "ソース仕様どおりに2つの Dock パネルを再構築", codexStep2: "文字の影と状態アイコンを調整", codexStep3: "全テストを実行",
    startTitle: "インストール方法を選択。", startBody: "macOS 26+ が必要です。GitHub Release では Apple Silicon 版と Intel 版を個別に提供します。",
    installDmg: "DMG をダウンロード", downloadLatest: "最新版をダウンロード", footerTagline: "ローカルで、控えめに、Dock のそばで。"
  },
  ko: {
    skip: "주요 콘텐츠로 이동", brandHome: "Codex Pulse 홈", navigation: "주요 탐색",
    navFeatures: "기능", navPrivacy: "개인정보", navStart: "시작하기",
    themeLabel: "테마", themeAuto: "자동", themeLight: "라이트", themeDark: "다크", languageLabel: "언어",
    menuInstall: "설치", installMenuLabel: "Codex Pulse 설치", installAI: "AI로 설치",
    installAIDetail: "설치 프롬프트 복사", copyAction: "복사", copySuccess: "복사됨", copyFailure: "복사 실패",
    dmgArchitectures: "Apple Silicon 및 Intel 버전", featuresMenuLabel: "Codex Pulse 기능",
    menuUsageTitle: "사용량 개요", menuUsageDetail: "Codex·Claude Code·OpenCode의 14일 Token 추이와 Codex 주간 한도",
    menuTasksTitle: "작업 활동", menuTasksDetail: "세 도구의 진행 중·최근 작업을 프로젝트와 세션별로 확인",
    menuAdaptiveTitle: "배경 화면 적응형 글자색", menuAdaptiveDetail: "배경 화면에 따라 글자 명암을 자동 선택, 도구 색상은 사용자화 가능",
    menuDockTitle: "Dock 옆에 배치", menuDockDetail: "Dock 하단·왼쪽·오른쪽 배치 지원",
    menuHintTitle: "조작 안내", menuHintDetail: "포인터를 패널 위에서 0.5초 멈추면 조작 메뉴가 표시됩니다",
    menuPrivacyNote: "로컬 Codex / Claude Code / OpenCode 데이터 읽기 전용 · 화면 기록 권한 불필요", themeMenuLabel: "테마 선택",
    title: "Codex Pulse — Codex의 모든 박동을 데스크톱에",
    description: "Codex Pulse는 macOS Dock 옆에 Codex·Claude Code·OpenCode Token 사용량, Codex 주간 한도와 작업 상태를 표시하는 로컬 데스크톱 도구입니다.",
    heroTitle: "Codex의 모든 박동을, <br>데스크톱에.",
    heroBody: "Dock 옆에서 Codex·Claude Code·OpenCode의 Token 사용량, 주간 한도와 작업 상태를 확인하세요. 로컬 데이터를 읽기만 하며 작업을 방해하지 않습니다.",
    viewGithub: "GitHub에서 보기", quickStart: "빠른 시작", previewLabel: "Codex Pulse 인터페이스 미리보기",
    menuFile: "파일", menuEdit: "편집", menuWindow: "윈도우",
    usagePanelLabel: "사용량 개요 패널 미리보기", taskPanelLabel: "작업 활동 패널 미리보기",
    panelLast14: "최근 14일", panelToday: "오늘",
    panelWeekly: "주간 한도", panelUsed: "사용 32%", panelRemaining: "남음 68%",
    panelResetAt: "7월 27일 08:00 초기화", panelDaily: "일평균 17%", panelCountdown: "3일 14시간 후 초기화",
    panelSession: "# 공개 배포 경험 다듬기", panelSession2: "# 랜딩 페이지 문구 동기화", panelSession3: "# 배포 전 점검",
    panelTask1: "두 Dock 패널을 픽셀 단위로 재현", panelTask3: "전체 테스트 실행", panelTask4: "v1.0.0 이후 변경 사항 반영",
    mockupNote: "HTML/CSS 인터페이스 재현 · 데모 데이터",
    featuresTitle: "코드에 집중하세요.<br>나머지는 데스크톱에.",
    featuresBody: "투명한 비활성 패널 두 개가 Dock 양옆에 조용히 머뭅니다. 필요할 때만 보고, 평소에는 앱 창 뒤에 남습니다.",
    featureUsageTitle: "사용량을 한눈에", featureUsageBody: "Codex·Claude Code·OpenCode의 14일 Token 추이를 도구별 색상으로 쌓아 보여 줍니다. 오늘 사용량, Codex 주간 한도와 초기화 카운트다운도 Dock 한쪽에서 확인합니다.",
    trendLast14: "최근 14일", trendToday: "오늘 1.42M",
    featureTasksTitle: "Dock 옆에서 흐르는 작업 상태", featureTasksBody: "프로젝트와 세션별로 Codex·Claude Code·OpenCode 작업을 확인합니다. 상태 아이콘은 도구별로 색이 다르며 Codex 세션 제목을 눌러 ChatGPT로 돌아갈 수 있습니다.",
    miniSession: "랜딩 페이지 배포", miniTask1: "데스크톱 및 모바일 화면 검증", miniTask2: "전체 테스트 실행", miniTask4: "v1.0.0 이후 변경 사항 반영",
    featurePlacementTitle: "데스크톱을 따라 이동", featurePlacementBody: "Dock의 하단·왼쪽·오른쪽 배치를 지원하며 패널 위치, 너비와 텍스트 정렬을 저장할 수 있습니다.",
    featureAdaptiveTitle: "글자색은 배경 화면을 따라갑니다",
    featureAdaptiveBody: "패널은 아래 배경 화면을 샘플링해 APCA 지각 대비로 글자 명암을 자동 선택하고 OKLCh에서 배경 화면의 색상을 이어갑니다. 도구별 사용량 막대 색상도 사용자화할 수 있습니다.",
    privacyTitle: "데이터는<br>이 Mac을 떠나지 않습니다.",
    privacyBody: "Codex Pulse는 로컬 Codex·Claude Code·OpenCode 세션 기록과 작업 인덱스를 읽기 전용으로 확인하며 사용량을 업로드하거나 원본 기록을 수정하지 않습니다.",
    privacy1: "Codex·Claude Code·OpenCode 로컬 데이터 읽기 전용", privacy2: "화면 기록 권한 불필요", privacy3: "잠자기·잠금 중 새로 고침 중지",
    codexWindowLabel: "Codex 창 미리보기", codexNewTask: "새 작업", codexThread1: "공개 배포 경험 다듬기",
    codexThread2: "패널 배치 최적화", codexThread3: "사용량 스캔 검증",
    codexPrompt: "랜딩 페이지 미리보기를 실제 앱과 같게 만들고 두 아키텍처용 설치 패키지를 제공해 주세요.",
    codexReply: "패널 재현, 테마 전환과 배포 구성을 완료했습니다.", codexComposer: "Codex에 계속 질문하기…",
    codexRecent: "최근", codexStep1: "소스 사양대로 두 Dock 패널 재구축", codexStep2: "텍스트 그림자와 상태 아이콘 보정", codexStep3: "전체 테스트 실행",
    startTitle: "설치 방법을 선택하세요.", startBody: "macOS 26+가 필요합니다. GitHub Release는 Apple Silicon과 Intel 버전을 각각 제공합니다.",
    installDmg: "DMG 다운로드", downloadLatest: "최신 버전 다운로드", footerTagline: "로컬에서, 절제되게, Dock 곁에서."
  },
  en: {
    skip: "Skip to main content", brandHome: "Codex Pulse home", navigation: "Main navigation",
    navFeatures: "Features", navPrivacy: "Privacy", navStart: "Get started",
    themeLabel: "Theme", themeAuto: "Auto", themeLight: "Light", themeDark: "Dark", languageLabel: "Language",
    menuInstall: "Install", installMenuLabel: "Install Codex Pulse", installAI: "Install with AI",
    installAIDetail: "Copy the installation prompt", copyAction: "Copy", copySuccess: "Copied", copyFailure: "Copy failed",
    dmgArchitectures: "Apple silicon and Intel builds", featuresMenuLabel: "Codex Pulse features",
    menuUsageTitle: "Usage overview", menuUsageDetail: "14-day token trend for Codex, Claude Code, and OpenCode, plus the Codex weekly limit",
    menuTasksTitle: "Task activity", menuTasksDetail: "Running and recent tasks from all three tools, grouped by project and session",
    menuAdaptiveTitle: "Wallpaper-adaptive text", menuAdaptiveDetail: "Text polarity follows your wallpaper; tool colors are customizable",
    menuDockTitle: "Beside the Dock", menuDockDetail: "Supports bottom, left, and right Dock layouts",
    menuHintTitle: "Interaction tip", menuHintDetail: "Rest the pointer over a panel for 0.5 seconds to reveal its controls",
    menuPrivacyNote: "Reads local Codex / Claude Code / OpenCode data only · No Screen Recording permission", themeMenuLabel: "Choose a theme",
    title: "Codex Pulse — Keep every Codex pulse on your desktop",
    description: "Codex Pulse is a local macOS desktop accessory that shows Codex, Claude Code, and OpenCode token usage, the Codex weekly limit, and task activity beside the Dock.",
    heroTitle: "Keep every Codex pulse <br>on your desktop.",
    heroBody: "See Codex, Claude Code, and OpenCode token usage, weekly limits, and task activity beside the Dock. It reads local data only and stays out of your way.",
    viewGithub: "View on GitHub", quickStart: "Quick start", previewLabel: "Codex Pulse interface preview",
    menuFile: "File", menuEdit: "Edit", menuWindow: "Window",
    usagePanelLabel: "Usage Overview Panel preview", taskPanelLabel: "Task Activity Panel preview",
    panelLast14: "Last 14 days", panelToday: "Today",
    panelWeekly: "Weekly limit", panelUsed: "Used 32%", panelRemaining: "68% left",
    panelResetAt: "Resets Jul 27, 08:00", panelDaily: "17% per day", panelCountdown: "Resets in 3d 14h",
    panelSession: "# Polish the public release", panelSession2: "# Sync the landing-page copy", panelSession3: "# Pre-release checks",
    panelTask1: "Recreate both Dock panels pixel-perfectly", panelTask3: "Run the full test suite", panelTask4: "Sync everything changed since v1.0.0",
    mockupNote: "HTML/CSS interface reproduction · Demo data",
    featuresTitle: "Stay in the code.<br>Leave the rest on the desktop.",
    featuresBody: "Two transparent, nonactivating panels sit quietly on either side of the Dock. Glance when needed; otherwise they remain behind app windows.",
    featureUsageTitle: "Usage at a glance", featureUsageBody: "A 14-day token trend stacks Codex, Claude Code, and OpenCode in per-tool colors, with today's usage, the Codex weekly limit, and a reset countdown beside the Dock.",
    trendLast14: "Last 14 days", trendToday: "Today 1.42M",
    featureTasksTitle: "Task activity, right beside the Dock", featureTasksBody: "See running and recently completed Codex, Claude Code, and OpenCode tasks by project and session. Status icons are colored per tool, and Codex session titles jump back to ChatGPT.",
    miniSession: "Publish landing page", miniTask1: "Verify desktop and mobile visuals", miniTask2: "Run the full test suite", miniTask4: "Sync everything changed since v1.0.0",
    featurePlacementTitle: "Moves with your desktop", featurePlacementBody: "Supports bottom, left, and right Dock positions. Panel placement, width, and text alignment can be adjusted and saved.",
    featureAdaptiveTitle: "Text that follows your wallpaper",
    featureAdaptiveBody: "Panels sample the wallpaper beneath them, pick dark or light text with APCA perceptual contrast, and continue the wallpaper's hue in OKLCh. Each tool's usage-bar color can also be customized.",
    privacyTitle: "Your data<br>stays on this Mac.",
    privacyBody: "Codex Pulse reads local Codex, Claude Code, and OpenCode session records and task indexes without uploading usage data or modifying the source records.",
    privacy1: "Reads only local Codex, Claude Code, and OpenCode data", privacy2: "No Screen Recording permission", privacy3: "Refresh pauses while asleep or locked",
    codexWindowLabel: "Codex window preview", codexNewTask: "New task", codexThread1: "Polish the public release",
    codexThread2: "Improve panel layout", codexThread3: "Verify usage scanning",
    codexPrompt: "Make the landing-page preview match the real app and provide installers for both architectures.",
    codexReply: "The panel reproduction, theme switching, and release setup are complete.", codexComposer: "Ask Codex anything…",
    codexRecent: "Recent", codexStep1: "Rebuild both Dock panels to the source spec", codexStep2: "Calibrate text shadows and status icons", codexStep3: "Run the full test suite",
    startTitle: "Choose how to install.", startBody: "Requires macOS 26+. GitHub Releases provide separate builds for Apple silicon and Intel Macs.",
    installDmg: "Download DMG", downloadLatest: "Download latest", footerTagline: "Local, restrained, and right beside the Dock."
  }
};

function readPreference(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writePreference(key, value) {
  try {
    localStorage.setItem(key, value);
  } catch {
    // file:// previews or strict privacy modes may disable persistent storage.
  }
}

const supportedLocales = Object.keys(translations);
const storedLocale = readPreference("codex-pulse-language");
const browserLocale = navigator.language;
const inferredLocale =
  browserLocale.startsWith("zh-HK") || browserLocale.startsWith("zh-MO") ? "zh-HK" :
  browserLocale.startsWith("zh-TW") ? "zh-TW" :
  browserLocale.startsWith("zh") ? "zh-CN" :
  browserLocale.startsWith("ja") ? "ja" :
  browserLocale.startsWith("ko") ? "ko" : "en";
let currentLocale = supportedLocales.includes(storedLocale) ? storedLocale : inferredLocale;

function applyLocale(locale) {
  const copy = translations[locale] || translations.en;
  currentLocale = locale;
  document.documentElement.lang = locale;
  document.title = copy.title;
  document.querySelector('meta[name="description"]')?.setAttribute("content", copy.description);
  for (const element of document.querySelectorAll("[data-i18n]")) {
    const value = copy[element.dataset.i18n];
    if (value) element.textContent = value;
  }
  for (const element of document.querySelectorAll("[data-i18n-html]")) {
    const value = copy[element.dataset.i18nHtml];
    if (value) element.innerHTML = value;
  }
  for (const element of document.querySelectorAll("[data-i18n-aria]")) {
    const value = copy[element.dataset.i18nAria];
    if (value) element.setAttribute("aria-label", value);
  }
  const languageSelect = document.querySelector("#language-select");
  if (languageSelect) languageSelect.value = locale;
  writePreference("codex-pulse-language", locale);
}

const themeSelect = document.querySelector("#theme-select");
const storedTheme = readPreference("codex-pulse-theme");
const initialTheme = ["auto", "light", "dark"].includes(storedTheme) ? storedTheme : "auto";
const systemTheme = window.matchMedia("(prefers-color-scheme: dark)");

function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
  const resolvedTheme = theme === "auto" ? (systemTheme.matches ? "dark" : "light") : theme;
  document.documentElement.dataset.resolvedTheme = resolvedTheme;
  for (const icon of document.querySelectorAll("[data-dock-codex-icon]")) {
    icon.src = `./assets/codex-icon-${resolvedTheme}.png`;
  }
  document.querySelector('meta[name="theme-color"]')?.setAttribute(
    "content",
    resolvedTheme === "dark" ? "#070b12" : "#f4f7fb"
  );
  for (const button of document.querySelectorAll("[data-desktop-theme]")) {
    button.setAttribute("aria-checked", String(button.dataset.desktopTheme === theme));
  }
}

applyTheme(initialTheme);
if (themeSelect) {
  themeSelect.value = initialTheme;
  themeSelect.addEventListener("change", () => {
    applyTheme(themeSelect.value);
    writePreference("codex-pulse-theme", themeSelect.value);
  });
}
systemTheme.addEventListener("change", () => {
  if (document.documentElement.dataset.theme === "auto") applyTheme("auto");
});

document.querySelector("#language-select")?.addEventListener("change", (event) => {
  applyLocale(event.target.value);
});
applyLocale(currentLocale);

const year = document.querySelector("#year");
if (year) year.textContent = String(new Date().getFullYear());

const revealItems = document.querySelectorAll(".reveal");
if ("IntersectionObserver" in window) {
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      }
    },
    { threshold: 0.12 }
  );

  for (const item of revealItems) observer.observe(item);
} else {
  for (const item of revealItems) item.classList.add("is-visible");
}

const desktopExperience = document.querySelector("#desktop-experience");

if (desktopExperience) {
  const desktop = document.querySelector("#mac-desktop");
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  const menuTriggers = [...document.querySelectorAll(".mac-menu-trigger")];
  const menuPopovers = [...document.querySelectorAll(".mac-popover")];

  function closeDesktopMenus({ restoreFocus = false } = {}) {
    const activeTrigger = menuTriggers.find((trigger) => trigger.getAttribute("aria-expanded") === "true");
    for (const trigger of menuTriggers) trigger.setAttribute("aria-expanded", "false");
    for (const popover of menuPopovers) popover.classList.remove("is-open");
    if (restoreFocus) activeTrigger?.focus();
  }

  function openDesktopMenu(trigger) {
    const popover = document.querySelector(`#${trigger.dataset.menu}`);
    const alreadyOpen = trigger.getAttribute("aria-expanded") === "true";
    closeDesktopMenus();
    if (alreadyOpen || !popover) return;
    trigger.setAttribute("aria-expanded", "true");
    popover.style.left = `${trigger.offsetLeft}px`;
    popover.classList.add("is-open");
  }

  for (const trigger of menuTriggers) {
    trigger.addEventListener("click", (event) => {
      event.stopPropagation();
      openDesktopMenu(trigger);
    });
    trigger.addEventListener("keydown", (event) => {
      if (!["ArrowDown", "Enter", " "].includes(event.key)) return;
      event.preventDefault();
      openDesktopMenu(trigger);
      document.querySelector(`#${trigger.dataset.menu} [role^="menuitem"]`)?.focus();
    });
  }

  desktopExperience.addEventListener("pointerdown", (event) => {
    if (!event.target.closest(".mac-popover, .mac-menu-trigger")) closeDesktopMenus();
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeDesktopMenus({ restoreFocus: true });
  });

  for (const button of document.querySelectorAll("[data-desktop-theme]")) {
    button.addEventListener("click", () => {
      const theme = button.dataset.desktopTheme;
      applyTheme(theme);
      writePreference("codex-pulse-theme", theme);
      if (themeSelect) themeSelect.value = theme;
      closeDesktopMenus({ restoreFocus: true });
      syncColorSettingsUI();
    });
  }

  function copyText(text) {
    if (navigator.clipboard?.writeText) return navigator.clipboard.writeText(text);
    const field = document.createElement("textarea");
    field.value = text;
    field.setAttribute("readonly", "");
    field.style.position = "fixed";
    field.style.opacity = "0";
    document.body.append(field);
    field.select();
    document.execCommand("copy");
    field.remove();
    return Promise.resolve();
  }

  for (const button of document.querySelectorAll(".copy-command")) {
    button.addEventListener("click", async () => {
      const status = button.querySelector(".copy-status");
      try {
        await copyText(button.dataset.copy);
        if (status) status.textContent = (translations[currentLocale] || translations.en).copySuccess;
      } catch {
        if (status) status.textContent = (translations[currentLocale] || translations.en).copyFailure;
      }
      window.setTimeout(() => {
        if (status) status.textContent = (translations[currentLocale] || translations.en).copyAction;
      }, 1600);
    });
  }

  function raiseWindow(windowElement) {
    if (!windowElement) return;
    for (const item of document.querySelectorAll(".mac-window")) {
      item.classList.remove("is-front");
      item.style.zIndex = "20";
    }
    windowElement.style.zIndex = "30";
    windowElement.classList.add("is-front");
  }

  for (const windowElement of document.querySelectorAll(".mac-window")) {
    windowElement.addEventListener("pointerdown", () => raiseWindow(windowElement));
    const handle = windowElement.querySelector("[data-drag-handle]");
    handle?.addEventListener("pointerdown", (event) => {
      if (event.button !== 0) return;
      event.preventDefault();
      raiseWindow(windowElement);
      const desktopRect = desktop.getBoundingClientRect();
      const windowRect = windowElement.getBoundingClientRect();
      const offsetX = event.clientX - windowRect.left;
      const offsetY = event.clientY - windowRect.top;
      windowElement.style.right = "auto";
      windowElement.classList.add("is-dragging");
      handle.setPointerCapture(event.pointerId);

      const moveWindow = (moveEvent) => {
        const maxX = Math.max(0, desktop.clientWidth - windowElement.offsetWidth);
        const maxY = Math.max(0, desktop.clientHeight - windowElement.offsetHeight);
        const left = Math.min(maxX, Math.max(0, moveEvent.clientX - desktopRect.left - offsetX));
        const top = Math.min(maxY, Math.max(0, moveEvent.clientY - desktopRect.top - offsetY));
        windowElement.style.left = `${left}px`;
        windowElement.style.top = `${top}px`;
      };

      const finishDrag = () => {
        windowElement.classList.remove("is-dragging");
        handle.removeEventListener("pointermove", moveWindow);
        handle.removeEventListener("pointerup", finishDrag);
        handle.removeEventListener("pointercancel", finishDrag);
        handle.removeEventListener("lostpointercapture", finishDrag);
        window.removeEventListener("mouseup", finishDrag);
        window.removeEventListener("blur", finishDrag);
      };

      handle.addEventListener("pointermove", moveWindow);
      handle.addEventListener("pointerup", finishDrag);
      handle.addEventListener("pointercancel", finishDrag);
      handle.addEventListener("lostpointercapture", finishDrag);
      window.addEventListener("mouseup", finishDrag);
      window.addEventListener("blur", finishDrag);
    });
  }

  document.querySelectorAll("[data-raise-codex]").forEach((button) => {
    button.addEventListener("click", () => raiseWindow(document.querySelector('[data-window="codex"]')));
  });
  document.querySelectorAll("[data-raise-activity]").forEach((button) => {
    button.addEventListener("click", () => raiseWindow(document.querySelector('[data-window="activity"]')));
  });

  const panelCopy = {
    "zh-CN": {
      "usage-title": "近 14 天",
      "usage-today": "今日",
      "quota-title": "周限额",
      "quota-used": "已用 32%",
      "quota-remaining": "剩余 68%",
      "quota-reset-at": "7月27日 08:00 重置",
      "quota-daily": "日均可用 17%",
      "quota-reset": "3 天 14 小时后重置",
      "colors-title": "用量配色",
      "colors-explain": "为每个产品选择用量趋势与图例使用的颜色。",
      "colors-reset": "恢复默认",
      "colors-reset-all": "全部恢复默认",
      "photo-title": "照片图库权限",
      "photo-explain": "当壁纸来自照片图库时，Codex Pulse 需要读取这张照片来计算面板文字颜色。不会上传或存储任何内容。",
      "photo-note": "当前壁纸不是照片图库壁纸，可以暂不授权。",
      "photo-ok": "好"
    },
    "zh-HK": {
      "usage-title": "近 14 日",
      "usage-today": "今日",
      "quota-title": "每週限額",
      "quota-used": "已用 32%",
      "quota-remaining": "剩餘 68%",
      "quota-reset-at": "7月27日 08:00 重設",
      "quota-daily": "每日可用 17%",
      "quota-reset": "3 日 14 小時後重設",
      "colors-title": "用量配色",
      "colors-explain": "為每個產品選擇用量趨勢與圖例使用的顏色。",
      "colors-reset": "還原預設",
      "colors-reset-all": "全部還原預設",
      "photo-title": "照片圖庫權限",
      "photo-explain": "當壁紙來自照片圖庫時，Codex Pulse 需要讀取這張照片來計算面板文字顏色。不會上載或儲存任何內容。",
      "photo-note": "目前壁紙不是照片圖庫壁紙，可以暫不授權。",
      "photo-ok": "好"
    },
    "zh-TW": {
      "usage-title": "近 14 天",
      "usage-today": "今日",
      "quota-title": "每週限額",
      "quota-used": "已用 32%",
      "quota-remaining": "剩餘 68%",
      "quota-reset-at": "7月27日 08:00 重設",
      "quota-daily": "每日可用 17%",
      "quota-reset": "3 天 14 小時後重設",
      "colors-title": "用量配色",
      "colors-explain": "為每個產品選擇用量趨勢與圖例使用的顏色。",
      "colors-reset": "還原預設",
      "colors-reset-all": "全部還原預設",
      "photo-title": "照片圖庫權限",
      "photo-explain": "當桌布來自照片圖庫時，Codex Pulse 需要讀取這張照片來計算面板文字顏色。不會上傳或儲存任何內容。",
      "photo-note": "目前桌布不是照片圖庫桌布，可以暫不授權。",
      "photo-ok": "好"
    },
    en: {
      "usage-title": "Last 14 days",
      "usage-today": "Today",
      "quota-title": "Weekly limit",
      "quota-used": "32% used",
      "quota-remaining": "68% left",
      "quota-reset-at": "Resets Jul 27, 08:00",
      "quota-daily": "17% daily",
      "quota-reset": "Resets in 3d 14h",
      "colors-title": "Usage Colors",
      "colors-explain": "Choose the color used by each product's usage trend and legend.",
      "colors-reset": "Reset",
      "colors-reset-all": "Reset All",
      "photo-title": "Photo Library Permission",
      "photo-explain": "When the wallpaper comes from your photo library, Codex Pulse reads that picture to compute the panel text color. Nothing is uploaded or stored.",
      "photo-note": "The current wallpaper is not a photo-library picture; you can skip authorization for now.",
      "photo-ok": "OK"
    },
    ja: {
      "usage-title": "過去14日",
      "usage-today": "本日",
      "quota-title": "週間上限",
      "quota-used": "使用済み 32%",
      "quota-remaining": "残り 68%",
      "quota-reset-at": "7月27日 08:00 リセット",
      "quota-daily": "1日平均 17%",
      "quota-reset": "3日14時間後にリセット",
      "colors-title": "使用量の配色",
      "colors-explain": "各プロダクトの使用量トレンドと凡例の色を選択します。",
      "colors-reset": "デフォルトに戻す",
      "colors-reset-all": "すべてデフォルトに戻す",
      "photo-title": "写真ライブラリの権限",
      "photo-explain": "壁紙が写真ライブラリの写真の場合、Codex Pulse はパネルの文字色を計算するためにその写真を読み取ります。アップロードや保存は行いません。",
      "photo-note": "現在の壁紙は写真ライブラリの写真ではないため、今は許可しなくてもかまいません。",
      "photo-ok": "OK"
    },
    ko: {
      "usage-title": "최근 14일",
      "usage-today": "오늘",
      "quota-title": "주간 한도",
      "quota-used": "32% 사용",
      "quota-remaining": "68% 남음",
      "quota-reset-at": "7월 27일 08:00 초기화",
      "quota-daily": "일일 17%",
      "quota-reset": "3일 14시간 후 초기화",
      "colors-title": "사용량 색상",
      "colors-explain": "각 제품의 사용량 추이와 범례에 사용할 색상을 선택합니다.",
      "colors-reset": "기본값 복원",
      "colors-reset-all": "모두 기본값 복원",
      "photo-title": "사진 보관함 권한",
      "photo-explain": "배경화면이 사진 보관함의 사진일 때 Codex Pulse는 패널 글자 색상을 계산하기 위해 해당 사진을 읽습니다. 업로드하거나 저장하지 않습니다.",
      "photo-note": "현재 배경화면은 사진 보관함의 사진이 아니므로 지금은 허용하지 않아도 됩니다.",
      "photo-ok": "확인"
    }
  };
  const panelLanguages = [
    { value: "zh-CN", label: "简体中文（中国大陆）" },
    { value: "zh-HK", label: "繁體中文（香港）" },
    { value: "zh-TW", label: "繁體中文（台灣）" },
    { value: "ja", label: "日本語" },
    { value: "ko", label: "한국어" },
    { value: "en", label: "English" }
  ];
  const panelLocations = ["bottom-left", "bottom-right"];
  const panels = [...document.querySelectorAll(".desktop-dock-panel")];
  const storedPanelLayout = (() => {
    try {
      return JSON.parse(readPreference("codex-pulse-desktop-panels-v5") || "{}");
    } catch {
      return {};
    }
  })();

  // App clamp: min 180, max = slot between screen-edge inset and the Dock
  // edge minus the 10px gap. While the desktop experience is hidden
  // (mobile-width load) there is no slot to measure — skip clamping so a
  // saved width is never destroyed.
  function panelMaxWidth() {
    if (!desktop.clientWidth) return Number.MAX_SAFE_INTEGER;
    const dock = document.querySelector(".mac-dock");
    const dockHalf = dock ? dock.offsetWidth / 2 : 5;
    return Math.max(180, Math.floor(desktop.clientWidth / 2 - dockHalf - 12));
  }

  function savePanelLayout() {
    const layout = {};
    for (const panel of panels) {
      layout[panel.dataset.panel] = {
        location: panel.dataset.location,
        width: panel.offsetWidth,
        align: panel.dataset.align,
        language: panel.dataset.language,
        stackOrder: panel.dataset.stackOrder,
        weeklyHidden: panel.classList.contains("weekly-hidden") || undefined
      };
    }
    writePreference("codex-pulse-desktop-panels-v5", JSON.stringify(layout));
  }

  function syncPanelPresentation() {
    const taskPanel = document.querySelector('[data-panel="task"]');
    if (taskPanel) {
      const resolvedAlignment = taskPanel.dataset.align === "auto"
        ? (taskPanel.dataset.location === "bottom-right" ? "right" : "left")
        : taskPanel.dataset.align;
      taskPanel.dataset.resolvedAlign = resolvedAlignment;
      const alignmentTargets = {
        auto: "左对齐",
        left: "右对齐",
        right: "自动对齐"
      };
      const alignmentButton = taskPanel.querySelector('[data-panel-action="align"]');
      const alignmentLabel = `切换任务文字为${alignmentTargets[taskPanel.dataset.align]}`;
      alignmentButton?.setAttribute("aria-label", alignmentLabel);
      alignmentButton?.setAttribute("title", alignmentLabel);
    }
    for (const panel of panels) {
      const target = panel.dataset.location === "bottom-left" ? "右侧" : "左侧";
      const moveButton = panel.querySelector('[data-panel-action="move"]');
      const moveLabel = `移动${panel.dataset.panel === "usage" ? "用量概览" : "任务活动"}面板到${target}`;
      moveButton?.setAttribute("aria-label", moveLabel);
      moveButton?.setAttribute("title", moveLabel);
    }
  }

  function syncPanelStack() {
    const usagePanel = document.querySelector('[data-panel="usage"]');
    const taskPanel = document.querySelector('[data-panel="task"]');
    const preferredUsageOrder = usagePanel?.dataset.stackOrder === "second" ? "second" : "first";
    for (const panel of panels) {
      delete panel.dataset.stackOrder;
      panel.style.bottom = "";
      const orderButton = panel.querySelector('[data-panel-action="order"]');
      if (orderButton) orderButton.disabled = true;
    }
    if (!usagePanel || !taskPanel) {
      syncPanelPresentation();
      return;
    }
    const colocated = usagePanel.dataset.location === taskPanel.dataset.location;
    if (colocated) {
      usagePanel.dataset.stackOrder = preferredUsageOrder;
      taskPanel.dataset.stackOrder = preferredUsageOrder === "first" ? "second" : "first";
      usagePanel.querySelector('[data-panel-action="order"]').disabled = false;
      taskPanel.querySelector('[data-panel-action="order"]').disabled = false;
      // App stacking: lower panel bottom-anchored (2px inset), upper panel
      // sits its real height + the 10px inter-panel gap above it. Measured
      // via getBoundingClientRect so the short-viewport scale(0.9) is
      // accounted for.
      const upper = usagePanel.dataset.stackOrder === "first" ? usagePanel : taskPanel;
      const lower = upper === usagePanel ? taskPanel : usagePanel;
      upper.style.bottom = `${Math.round(2 + lower.getBoundingClientRect().height + 10)}px`;
    }
    syncPanelPresentation();
  }

  function applyPanelLanguage(panel, languageValue) {
    const index = Math.max(0, panelLanguages.findIndex((item) => item.value === languageValue));
    const language = panelLanguages[index];
    const copy = panelCopy[language.value] || panelCopy["zh-CN"];
    panel.dataset.language = language.value;
    for (const element of panel.querySelectorAll("[data-panel-copy]")) {
      if (copy[element.dataset.panelCopy]) element.textContent = copy[element.dataset.panelCopy];
    }
    // The floating utility windows follow the usage panel's language.
    for (const element of document.querySelectorAll(".mac-utility-window [data-panel-copy]")) {
      if (copy[element.dataset.panelCopy]) element.textContent = copy[element.dataset.panelCopy];
    }
    const wheel = panel.querySelector("[data-panel-language-picker]");
    if (wheel) {
      const count = panelLanguages.length;
      const previous = panelLanguages[(index + count - 1) % count];
      const next = panelLanguages[(index + 1) % count];
      const prevRow = wheel.querySelector(".wheel-prev");
      const currentRow = wheel.querySelector(".wheel-current");
      const nextRow = wheel.querySelector(".wheel-next");
      if (prevRow) prevRow.textContent = previous.label;
      if (currentRow) currentRow.textContent = language.label;
      if (nextRow) nextRow.textContent = next.label;
      wheel.setAttribute("aria-valuetext", language.label);
    }
  }

  for (const panel of panels) {
    const saved = storedPanelLayout[panel.dataset.panel];
    if (panelLocations.includes(saved?.location)) panel.dataset.location = saved.location;
    if (Number.isFinite(saved?.width)) {
      const restoredWidth = Math.min(panelMaxWidth(), Math.max(180, saved.width));
      panel.style.setProperty("--panel-width", `${restoredWidth}px`);
      panel.querySelector("[data-panel-resize]")?.setAttribute("aria-valuenow", String(Math.round(restoredWidth)));
    }
    if (desktop.clientWidth) {
      panel.querySelector("[data-panel-resize]")?.setAttribute("aria-valuemax", String(panelMaxWidth()));
    }
    if (panel.dataset.panel === "task" && ["auto", "left", "right"].includes(saved?.align)) {
      panel.dataset.align = saved.align;
    }
    if (["first", "second"].includes(saved?.stackOrder)) panel.dataset.stackOrder = saved.stackOrder;
    if (panel.dataset.panel === "usage") {
      applyPanelLanguage(panel, panelCopy[saved?.language] ? saved.language : "zh-CN");
      if (saved?.weeklyHidden) {
        panel.classList.add("weekly-hidden");
        panel.querySelector('[data-panel-action="weekly"]')?.setAttribute("aria-pressed", "true");
      }
    }

    let dwellTimer;
    let hideTimer;
    let dwellPoint;
    const dismissPanelControls = () => {
      panel.classList.remove("controls-visible", "language-picker-visible", "resize-focused");
      panel.querySelector('[data-panel-action="language"]')?.setAttribute("aria-expanded", "false");
      const picker = panel.querySelector("[data-panel-language-picker]");
      if (picker) picker.hidden = true;
    };
    const beginDwell = (event) => {
      if (event.pointerType === "touch") return;
      window.clearTimeout(dwellTimer);
      window.clearTimeout(hideTimer);
      dwellPoint = { x: event.clientX, y: event.clientY };
      dwellTimer = window.setTimeout(() => panel.classList.add("controls-visible"), 500);
    };
    panel.addEventListener("pointerenter", (event) => {
      window.clearTimeout(hideTimer);
      if (!panel.classList.contains("controls-visible")) beginDwell(event);
    });
    panel.addEventListener("pointermove", (event) => {
      if (!dwellPoint || panel.classList.contains("controls-visible")) return;
      if (Math.hypot(event.clientX - dwellPoint.x, event.clientY - dwellPoint.y) > 3) beginDwell(event);
    });
    panel.addEventListener("pointerleave", () => {
      window.clearTimeout(dwellTimer);
      dwellPoint = null;
      hideTimer = window.setTimeout(() => {
        if (!panel.matches(":hover, :focus-within")) dismissPanelControls();
      }, 1000);
    });
    panel.addEventListener("focusin", () => window.clearTimeout(hideTimer));
    panel.addEventListener("focusout", () => {
      hideTimer = window.setTimeout(() => {
        if (!panel.matches(":hover, :focus-within")) dismissPanelControls();
      }, 1000);
    });
  }

  syncPanelStack();

  function cyclePanelLanguage(panel, offset) {
    const currentIndex = panelLanguages.findIndex((item) => item.value === panel.dataset.language);
    const nextIndex = (Math.max(0, currentIndex) + offset + panelLanguages.length) % panelLanguages.length;
    applyPanelLanguage(panel, panelLanguages[nextIndex].value);
    savePanelLayout();
  }

  document.querySelectorAll("[data-panel-language-picker]").forEach((picker) => {
    const panel = picker.closest("[data-panel]");
    let lastDragY;
    let accumulatedDrag = 0;
    let didDrag = false;
    // App wheel: clicking the neighbor rows steps to them; the center row is
    // a no-op. Scroll and press-drag step one language per 12–14px.
    picker.addEventListener("click", (event) => {
      if (didDrag) {
        didDrag = false;
        return;
      }
      const row = event.target.closest(".wheel-row");
      if (!row || row.classList.contains("wheel-current")) return;
      cyclePanelLanguage(panel, row.classList.contains("wheel-prev") ? -1 : 1);
    });
    picker.addEventListener("wheel", (event) => {
      event.preventDefault();
      cyclePanelLanguage(panel, event.deltaY > 0 ? 1 : -1);
    }, { passive: false });
    picker.addEventListener("keydown", (event) => {
      if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return;
      event.preventDefault();
      cyclePanelLanguage(panel, event.key === "ArrowDown" ? 1 : -1);
    });
    picker.addEventListener("pointerdown", (event) => {
      if (event.button !== 0) return;
      lastDragY = event.clientY;
      accumulatedDrag = 0;
      didDrag = false;
      picker.setPointerCapture(event.pointerId);
    });
    picker.addEventListener("pointermove", (event) => {
      if (lastDragY === undefined) return;
      accumulatedDrag += event.clientY - lastDragY;
      lastDragY = event.clientY;
      if (Math.abs(accumulatedDrag) < 14) return;
      cyclePanelLanguage(panel, accumulatedDrag > 0 ? 1 : -1);
      accumulatedDrag = 0;
      didDrag = true;
    });
    const finishLanguageDrag = () => {
      lastDragY = undefined;
      savePanelLayout();
    };
    picker.addEventListener("pointerup", finishLanguageDrag);
    picker.addEventListener("pointercancel", finishLanguageDrag);
    picker.addEventListener("lostpointercapture", finishLanguageDrag);
  });

  // ------- Floating utility windows (usage colors / photo permission) -------

  const desktopExperienceRoot = desktopExperience;
  const toolColorOverrides = {};

  function normalizeHexColor(value) {
    const trimmed = value.trim();
    if (/^#[0-9a-f]{6}$/i.test(trimmed)) return trimmed.toLowerCase();
    if (/^#[0-9a-f]{3}$/i.test(trimmed)) {
      return `#${[...trimmed.slice(1)].map((c) => c + c).join("")}`.toLowerCase();
    }
    return null;
  }

  function currentToolColor(tool) {
    return normalizeHexColor(
      getComputedStyle(desktopExperienceRoot).getPropertyValue(`--tool-${tool}`)
    ) || "#4144f5";
  }

  function syncColorSettingsUI() {
    for (const input of document.querySelectorAll("[data-color-tool]")) {
      input.value = currentToolColor(input.dataset.colorTool);
    }
    for (const button of document.querySelectorAll("[data-color-reset]")) {
      const target = button.dataset.colorReset;
      button.disabled = target === "all"
        ? Object.keys(toolColorOverrides).length === 0
        : !toolColorOverrides[target];
    }
  }

  function positionUtilityWindow(win, anchorPanel) {
    const panelRect = anchorPanel.getBoundingClientRect();
    const desktopRect = desktop.getBoundingClientRect();
    const width = win.offsetWidth || 320;
    // App: 10px above the usage panel; leading-aligned on the left half of
    // the screen, trailing-aligned on the right half; clamped on-screen.
    const midX = panelRect.left + panelRect.width / 2 - desktopRect.left;
    let left = midX > desktop.clientWidth / 2
      ? panelRect.right - desktopRect.left - width
      : panelRect.left - desktopRect.left;
    left = Math.min(Math.max(8, left), desktop.clientWidth - width - 8);
    let bottom = desktopRect.height - (panelRect.top - desktopRect.top) + 10;
    bottom = Math.min(bottom, desktop.clientHeight - win.offsetHeight - 8);
    win.style.left = `${left}px`;
    win.style.bottom = `${Math.max(8, bottom)}px`;
  }

  function openUtilityWindow(kind, anchorPanel) {
    const win = document.querySelector(`[data-utility="${kind}"]`);
    if (!win) return;
    if (kind === "colors") syncColorSettingsUI();
    win.hidden = false;
    positionUtilityWindow(win, anchorPanel);
  }

  document.querySelectorAll("[data-utility-close]").forEach((button) => {
    button.addEventListener("click", () => {
      const win = button.closest(".mac-utility-window");
      if (win) win.hidden = true;
    });
  });

  document.querySelectorAll("[data-color-tool]").forEach((input) => {
    input.addEventListener("input", () => {
      const tool = input.dataset.colorTool;
      toolColorOverrides[tool] = input.value;
      desktopExperienceRoot.style.setProperty(`--tool-${tool}`, input.value);
      syncColorSettingsUI();
    });
  });

  document.querySelectorAll("[data-color-reset]").forEach((button) => {
    button.addEventListener("click", () => {
      const target = button.dataset.colorReset;
      const targets = target === "all" ? ["claude", "codex", "opencode"] : [target];
      for (const tool of targets) {
        delete toolColorOverrides[tool];
        desktopExperienceRoot.style.removeProperty(`--tool-${tool}`);
      }
      syncColorSettingsUI();
    });
  });

  function updateWeeklyToggleLabel(panel) {
    const button = panel.querySelector('[data-panel-action="weekly"]');
    if (!button) return;
    const hidden = panel.classList.contains("weekly-hidden");
    const label = hidden ? "显示周额度信息" : "隐藏周额度信息";
    button.setAttribute("aria-pressed", String(hidden));
    button.setAttribute("aria-label", label);
    button.setAttribute("title", label);
  }

  document.querySelectorAll("[data-panel-action]").forEach((button) => {
    button.addEventListener("click", () => {
      const panel = button.closest("[data-panel]");
      if (button.dataset.panelAction === "language") {
        const isVisible = panel.classList.toggle("language-picker-visible");
        button.setAttribute("aria-expanded", String(isVisible));
        const picker = panel.querySelector("[data-panel-language-picker]");
        if (picker) {
          picker.hidden = !isVisible;
          if (isVisible) picker.focus();
        }
      } else if (button.dataset.panelAction === "palette") {
        openUtilityWindow("colors", panel);
      } else if (button.dataset.panelAction === "photo") {
        openUtilityWindow("photo", panel);
      } else if (button.dataset.panelAction === "weekly") {
        panel.classList.toggle("weekly-hidden");
        updateWeeklyToggleLabel(panel);
      } else if (button.dataset.panelAction === "move") {
        const currentIndex = panelLocations.indexOf(panel.dataset.location);
        panel.dataset.location = panelLocations[(currentIndex + 1) % panelLocations.length];
        syncPanelStack();
      } else if (button.dataset.panelAction === "align") {
        panel.dataset.align = {
          auto: "left",
          left: "right",
          right: "auto"
        }[panel.dataset.align] || "auto";
        syncPanelPresentation();
      } else if (button.dataset.panelAction === "order" && !button.disabled) {
        const otherPanel = panels.find((item) => item !== panel && item.dataset.location === panel.dataset.location);
        if (otherPanel) {
          const currentOrder = panel.dataset.stackOrder;
          panel.dataset.stackOrder = otherPanel.dataset.stackOrder;
          otherPanel.dataset.stackOrder = currentOrder;
          syncPanelStack();
        }
      }
      savePanelLayout();
    });
  });

  panels.forEach(updateWeeklyToggleLabel);

  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    for (const panel of panels) {
      panel.classList.remove("language-picker-visible");
      panel.querySelector('[data-panel-action="language"]')?.setAttribute("aria-expanded", "false");
      const picker = panel.querySelector("[data-panel-language-picker]");
      if (picker) picker.hidden = true;
    }
    for (const win of document.querySelectorAll(".mac-utility-window")) {
      win.hidden = true;
    }
  });

  function resizePanel(panel, delta) {
    const location = panel.dataset.location;
    const handleOnLeft = location === "bottom-right";
    const direction = handleOnLeft ? -1 : 1;
    const nextWidth = Math.min(panelMaxWidth(), Math.max(180, panel.offsetWidth + delta * direction));
    panel.style.setProperty("--panel-width", `${nextWidth}px`);
    const handle = panel.querySelector("[data-panel-resize]");
    handle?.setAttribute("aria-valuenow", String(Math.round(nextWidth)));
    handle?.setAttribute("aria-valuemax", String(panelMaxWidth()));
  }

  for (const handle of document.querySelectorAll("[data-panel-resize]")) {
    const panel = handle.closest("[data-panel]");
    let isResizing = false;
    handle.addEventListener("pointerenter", () => panel.classList.add("resize-focused"));
    handle.addEventListener("pointerleave", () => {
      if (!isResizing) panel.classList.remove("resize-focused");
    });
    handle.addEventListener("pointerdown", (event) => {
      if (event.button !== 0) return;
      event.preventDefault();
      isResizing = true;
      panel.classList.add("controls-visible", "resize-focused");
      let previousX = event.clientX;
      handle.setPointerCapture(event.pointerId);
      const move = (moveEvent) => {
        resizePanel(panel, moveEvent.clientX - previousX);
        previousX = moveEvent.clientX;
      };
      const finish = () => {
        isResizing = false;
        panel.classList.remove("resize-focused");
        handle.removeEventListener("pointermove", move);
        handle.removeEventListener("pointerup", finish);
        handle.removeEventListener("pointercancel", finish);
        handle.removeEventListener("lostpointercapture", finish);
        window.removeEventListener("mouseup", finish);
        window.removeEventListener("blur", finish);
        savePanelLayout();
      };
      handle.addEventListener("pointermove", move);
      handle.addEventListener("pointerup", finish);
      handle.addEventListener("pointercancel", finish);
      handle.addEventListener("lostpointercapture", finish);
      window.addEventListener("mouseup", finish);
      window.addEventListener("blur", finish);
    });
    handle.addEventListener("keydown", (event) => {
      if (!["ArrowLeft", "ArrowRight"].includes(event.key)) return;
      event.preventDefault();
      resizePanel(panel, event.key === "ArrowRight" ? 10 : -10);
      savePanelLayout();
    });
  }

  const cpuCell = document.querySelector("#pulse-cpu");
  const memoryCell = document.querySelector("#pulse-memory");
  let metricTimer;

  function scheduleMetricUpdate() {
    window.clearTimeout(metricTimer);
    if (document.hidden) return;
    metricTimer = window.setTimeout(() => {
      if (cpuCell) cpuCell.textContent = `${(0.6 + Math.random() * 15.4).toFixed(1)}%`;
      if (memoryCell) memoryCell.textContent = `${(50 + Math.random() * 10).toFixed(1)} MB`;
      scheduleMetricUpdate();
    }, 3000 + Math.random() * 2000);
  }

  document.addEventListener("visibilitychange", scheduleMetricUpdate);
  scheduleMetricUpdate();

  window.addEventListener("resize", () => {
    for (const windowElement of document.querySelectorAll(".mac-window")) {
      if (!windowElement.style.left || !windowElement.style.top) continue;
      const maxX = Math.max(0, desktop.clientWidth - windowElement.offsetWidth);
      const maxY = Math.max(0, desktop.clientHeight - windowElement.offsetHeight);
      windowElement.style.left = `${Math.min(maxX, Math.max(0, Number.parseFloat(windowElement.style.left)))}px`;
      windowElement.style.top = `${Math.min(maxY, Math.max(0, Number.parseFloat(windowElement.style.top)))}px`;
    }
    for (const panel of panels) {
      if (panel.offsetWidth > panelMaxWidth()) {
        panel.style.setProperty("--panel-width", `${panelMaxWidth()}px`);
      }
    }
    syncPanelStack();
    for (const win of document.querySelectorAll(".mac-utility-window:not([hidden])")) {
      const usagePanel = document.querySelector('[data-panel="usage"]');
      if (usagePanel) positionUtilityWindow(win, usagePanel);
    }
  });

  const desktopClock = document.querySelector("#desktop-clock");
  const clockFormatter = new Intl.DateTimeFormat("zh-CN", {
    month: "numeric",
    day: "numeric",
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false
  });
  const updateClock = () => {
    if (desktopClock) desktopClock.textContent = clockFormatter.format(new Date());
  };
  updateClock();
  window.setInterval(updateClock, 60000);
}
