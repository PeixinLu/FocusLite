# FocusLite (Milestone 1 MVP)

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
- Typing shows mock results in the list.
- Press Esc to hide the window.
- Cmd+Space toggles the window when the hotkey is available.
- A menu bar icon (bolt) can toggle the window and quit the app.

## Global hotkey notes
- Cmd+Space is reserved by Spotlight by default. To use it, disable Spotlight's shortcut in:
  System Settings > Keyboard > Keyboard Shortcuts > Spotlight.
- If you keep Spotlight enabled, use the menu bar icon instead or change the hotkey in:
  `FocusLite/AppDelegate.swift` (edit keyCode/modifiers).
- This hotkey method (Carbon RegisterEventHotKey) does not require Accessibility or Input Monitoring.

## Permissions
- Milestone 1 does not request any permissions.
- Future milestones will request only the minimum required (Accessibility, Input Monitoring, Screen Recording),
  with explicit prompts and guidance.

### How to enable permissions (when prompted)
- Accessibility: System Settings > Privacy & Security > Accessibility
- Input Monitoring: System Settings > Privacy & Security > Input Monitoring
- Screen Recording: System Settings > Privacy & Security > Screen Recording
- After enabling, quit and relaunch FocusLite if the system does not apply access immediately.

## FAQ / Common issues
- Cmd+Space does nothing: Spotlight is still bound to Cmd+Space. Disable it in
  System Settings > Keyboard > Keyboard Shortcuts > Spotlight, or change the hotkey in
  `FocusLite/AppDelegate.swift`.
- Window shows but cannot type: click inside the window once, or relaunch the app after
  granting permissions (future milestones). If it persists, file an issue with macOS version and logs.
- Hotkey registration fails: use the menu bar icon to toggle the window.

## Known limitations (Milestone 1)
- Only a mock provider is wired; results are fake and not actionable.
- No persistence, indexing, or plugin loading from disk yet.
- Hotkey is fixed in code (no in-app customization).

## Tests
- Run unit tests from Xcode (Cmd+U).
- Or via CLI: `xcodebuild test -scheme FocusLite`.
