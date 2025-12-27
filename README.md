# FocusLite

A macOS-only Spotlight-style launcher built with Swift 5.9+, SwiftUI, and AppKit.

## Requirements
- macOS 13+
- Xcode 15+ (Swift 5.9)

## Run
1. Open `FocusLite.xcodeproj` in Xcode.
2. Select the `FocusLite` scheme.
3. Run (Cmd+R).

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
