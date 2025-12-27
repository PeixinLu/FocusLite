# FocusLite

A macOS-only Spotlight-style launcher built with Swift 5.9+, SwiftUI, and AppKit.

## Requirements
- macOS 13+
- Xcode 15+ (Swift 5.9)

## Run
1. Open `FocusLite.xcodeproj` in Xcode.
2. Select the `FocusLite` scheme.
3. Run (Cmd+R).

## 自动更新（Sparkle 2 + GitHub）
- 应用内：状态栏菜单新增 `Check for Updates…`，设置面板新增“更新”页（显示版本号、手动检查、自动检查开关，失败会弹窗提示）。
- Feed：`SUFeedURL` 指向 `https://peixinlu.github.io/focuslight/appcast.xml`（由 CI 发布到 GitHub Pages），`SUPublicEDKey` 已配置。
- CI：`.github/workflows/release.yml` 在 `v*` tag 时运行，使用 `Sparkle 2.8.1` 工具链，禁用签名构建 Release、打包 `FocusLite.zip`（顶层直接是 `.app`），生成 `appcast.xml`（含 `sparkle:edSignature`），发布 GitHub Release，并部署 appcast 到 Pages（无需手建 `gh-pages` 分支）。
- 版本策略：tag `vX.Y.Z` 会注入为 `MARKETING_VERSION`，构建号使用 `GITHUB_RUN_NUMBER` 写入 `CFBundleVersion`，确保可递增比较。
- 示例：`docs/appcast.example.xml` 展示生成结果结构；正式 feed 由 CI 覆盖。

### 我需要手工做的事
- GitHub Secrets：添加 `SPARKLE_ED25519_PRIVATE_KEY`（对应 `SUPublicEDKey` 的私钥，PEM 内容）。不要提交到仓库。
- GitHub Pages：第一次运行 workflow 会自动创建/更新 Pages 发布，无需手工建分支；如需自定义域名可在仓库设置中调整。
- Tag：在推送 `vX.Y.Z` 前确认版本号递增；如需变更公钥，在 `FocusLite/Info.plist` 更新 `SUPublicEDKey` 并重新生成私钥。

### 端到端验证
1. 下载并运行旧版本（上一条 Release）。
2. 在 main 分支合并改动后打 tag（如 `v0.1.2`）并 push。
3. 等待 GitHub Actions 生成 Release 资产和 Pages `appcast.xml`。
4. 旧版应用里点击菜单或设置页的 `Check for Updates…`，应弹出 Sparkle 面板并下载新版本。
5. 更新完成后重新打开设置页，版本号应与新 tag 匹配。

### 常见问题排查
- Feed 404 或旧内容：检查 Actions 是否成功，`actions/deploy-pages` 是否运行；确保 `SUFeedURL` 使用 `https://<owner>.github.io/focuslight/appcast.xml`。
- 签名缺失/校验失败：确认 Secrets 中存在正确的 `SPARKLE_ED25519_PRIVATE_KEY`，与 `SUPublicEDKey` 成对；如更换密钥，老版本需要新的公钥更新才能信任新包。
- Zip 结构错误：确保通过 workflow 生成的 `FocusLite.zip`，解压后顶层直接是 `FocusLite.app`，不要再包一层目录。
- 版本号不递增：tag 必须递增；`CFBundleVersion` 由 `GITHUB_RUN_NUMBER` 写入，重复 tag 会导致比较失败。
- 网络/Feed 不可用：Sparkle 会弹出错误提示且不会崩溃；若完全无 UI，请确认应用能访问外网并未被防火墙阻断。

## Expected behavior
- A centered, borderless launcher window appears with rounded corners and shadow.
- The window stays floating above other apps and can join all spaces.
- Typing shows results in the list (apps, calculator, snippets, clipboard, translate).
- Prefix entries (for example `cc` or `sn`) appear as action-like results in global search.
- Press Esc to hide the window.
- Cmd+Space toggles the window when the hotkey is available.
- A menu bar icon (bolt) can toggle the window and quit the app.
- Click the pencil icon to manage snippets.
- Clipboard Settings are available from the menu bar.
- Clipboard hotkey (default `option+v`) opens clipboard mode.
- Clipboard/Snippets show a two-column preview (left results, right preview).
- Translate prefix `tr` enters translation mode and returns multiple services.

## Global hotkey notes
- Cmd+Space is reserved by Spotlight by default. To use it, disable Spotlight's shortcut in:
  System Settings > Keyboard > Keyboard Shortcuts > Spotlight.
- If you keep Spotlight enabled, use the menu bar icon instead or change the hotkey in:
  `FocusLite/AppDelegate.swift` (edit keyCode/modifiers).
- This hotkey method (Carbon RegisterEventHotKey) does not require Accessibility or Input Monitoring.

## Permissions
- FocusLite only requests permissions it needs for enabled features.
- Accessibility is required for auto paste.
- Input Monitoring and Screen Recording are not required.

### Auto paste for snippets
- To auto paste snippet content into the previous app, FocusLite needs Accessibility permission.
- When you press Enter on a snippet for the first time, macOS will prompt for this permission.
- If permission is denied, FocusLite still copies the snippet to the clipboard.

### Clipboard monitoring (macOS)
- Reading the system pasteboard does not require Accessibility or Input Monitoring permission.
- macOS does not provide clipboard change callbacks; FocusLite polls `NSPasteboard.changeCount` on a low interval.
- Source app is best-effort: we record the current frontmost app, which may be inaccurate for background copies.
- Some apps use private pasteboards or clear content quickly; those copies may not be captured.
- Clipboard history is persisted to `~/Library/Application Support/FocusLite/clipboard_history.json`.

### How to enable permissions (when prompted)
- Accessibility: System Settings > Privacy & Security > Accessibility
- Input Monitoring: System Settings > Privacy & Security > Input Monitoring (not required)
- Screen Recording: System Settings > Privacy & Security > Screen Recording (not required)
- After enabling, quit and relaunch FocusLite if the system does not apply access immediately.

## FAQ / Common issues
- Cmd+Space does nothing: Spotlight is still bound to Cmd+Space. Disable it in
  System Settings > Keyboard > Keyboard Shortcuts > Spotlight, or change the hotkey in
  `FocusLite/AppDelegate.swift`.
- Window shows but cannot type: click inside the window once, or relaunch the app after
  granting permissions (future milestones). If it persists, file an issue with macOS version and logs.
- Hotkey registration fails: use the menu bar icon to toggle the window.
- System translation fails with missing language packs: install the required language packs in macOS
  system settings or disable System in Translate Settings.

## Known limitations (Milestone 6)
- Translation services require user-provided API keys for official providers.
- System translation depends on OS language packs and may fail if not downloaded.
- Preview pane only shows for clipboard/snippets; other providers stay single-column.
- Hotkey is fixed in code (no in-app customization).

## Snippets
- Stored at `~/Library/Application Support/FocusLite/snippets.json`.
- Trigger with `;keyword` (for example, `;addr`).
- Manage snippets via the pencil icon in the launcher (opens a separate window).
- Snippets search prefix is configurable in Snippets Manager.

## Clipboard
- Stored on disk (no Keychain access).
- Default history size: 200 entries.
- Ignored apps and max entries can be configured in Clipboard Settings.
- Clipboard search prefix defaults to `c` (type `c ` then your query).
- Clipboard hotkey defaults to `option+v` and is configurable in Clipboard Settings.
- Files and images are supported, with preview in the right pane.
- Retention can be configured to 3h, 12h, 1d, 3d, or 1w.

## Translate
- Trigger with `tr ` or select the translate prefix in search.
- Configure services in the menu bar: "翻译设置...".
- Each enabled service returns a result; Enter copies the translation.

## Tests
- Run unit tests from Xcode (Cmd+U).
- Or via CLI: `xcodebuild test -scheme FocusLite`.

## Development workflow
- Use one branch and one PR per milestone to simplify review and rollback.
