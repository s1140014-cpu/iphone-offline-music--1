雲端 iOS 編譯檢查（GitHub Actions）
====================================

此資料夾包含：
- project.yml：由 XcodeGen 產生 Xcode 專案
- .github/workflows/ios-build.yml：在 GitHub macOS runner 編譯 iOS Simulator 版本

如何套用：
1. 在你的私人 GitHub Repository 開啟 Add file > Upload files。
2. 上傳 project.yml，以及 .github/workflows/ios-build.yml（GitHub 網頁通常需逐層建立資料夾，或在本機使用 Git 上傳）。
3. 確認 ContentView.swift 和 OfflineMusicPlayerApp.swift 位於 repository 根目錄。
4. Commit changes。
5. 打開 Actions 分頁，選擇「iOS compile check」，查看最近一次執行結果。

限制：
- 此 workflow 只編譯 iOS Simulator 版本，並明確關閉程式碼簽署；它不是已簽署的 iPhone App，也不會產生可安裝的 IPA。
- 免費 Apple Developer 帳號不能使用 Xcode Cloud；此處使用 GitHub Actions macOS runner 進行未簽署的模擬器編譯檢查。
- 要安裝到真實 iPhone，仍需要可用的 Apple 開發簽署與 provisioning profile。請勿把 Apple ID 密碼、驗證碼、憑證私鑰放進 repository。
- 若 build 失敗，請從 Actions 複製第一個真正的 Swift/Xcode error 訊息，再修正。
