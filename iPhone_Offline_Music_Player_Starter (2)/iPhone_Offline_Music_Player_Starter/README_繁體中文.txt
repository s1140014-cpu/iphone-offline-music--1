iPhone 原生離線音樂播放器（SwiftUI 起始專案）
================================================

功能：
- 從 iPhone「檔案」App 選取並匯入音訊檔案
- 將匯入的音訊複製到 App 私有 Documents/Music 資料夾，之後可離線播放
- 播放 / 暫停 / 上一首 / 下一首
- 背景音訊設定與鎖定畫面控制程式碼
- 目前示範使用 AVAudioPlayer；MP3、AAC、WAV 等支援格式視 iOS 音訊解碼能力而定

重要限制：
你目前使用 Windows。這份 ZIP 包含原生 iOS Swift 原始碼與設定範本，但不是可直接在 Windows 上安裝到 iPhone 的 IPA。
原生 iOS App 通常需要 macOS + Xcode 進行建置與簽署。Windows 可用來編輯檔案；要真正安裝，需使用自己的 Mac 或可信任的雲端 Mac 建置服務。
不要把 Apple ID 密碼交給不明建置網站。

建立 Xcode 專案（需要 Mac 或雲端 Mac）：
1. 開啟 Xcode，建立 iOS App 專案，Product Name: OfflineMusicPlayer，Interface: SwiftUI，Language: Swift。
2. 將 ContentView.swift 的內容替換成此資料夾內的 ContentView.swift。
3. 將 OfflineMusicPlayerApp.swift 的內容替換成此資料夾內的 OfflineMusicPlayerApp.swift。
4. 將 Info.plist 的必要設定合併到專案的 Info 設定中：
   - Required background modes / UIBackgroundModes 加入 audio
   若使用傳統 Info.plist，將本資料夾的 Info.plist 設定合併到專案，不要盲目覆蓋 Xcode 自動產生的 plist。
5. 在 Signing & Capabilities 選擇你的 Apple 開發團隊；一般個人測試可使用自己的 Apple ID（免費簽署有期限及限制）。
6. 連接 iPhone，選取裝置後按 Run，並在手機上信任/允許所需設定。
7. 在 iPhone「檔案」App 中準備 MP3，開啟播放器按「匯入音樂」選取檔案。

背景播放說明：
- 程式設定 AVAudioSession category = playback。
- App 必須啟用 Background Modes > Audio, AirPlay, and Picture in Picture（至少 Audio）。
- 背景播放效果仍受 iOS 版本、音訊中斷、電話/其他音訊 App 及裝置設定影響。

注意：
- 這是可編輯的原生 Swift 起始程式，不是已測試簽署的正式 App。
- 請先用非重要音樂檔測試。
