# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

FocusLite is a macOS productivity launcher (think Spotlight alternative) written in Swift. It runs as a menu bar app (`accessory` activation policy) and provides a floating, borderless search window triggered by global hotkeys. Features include app launching, clipboard history, calculator, translation, code snippets, web search, and quick directory access — all organized as plugins.

## Build & Test Commands

```bash
# Build (Debug)
xcodebuild -project FocusLite.xcodeproj -scheme FocusLite -configuration Debug build

# Build (Release)
xcodebuild -project FocusLite.xcodeproj -scheme FocusLite -configuration Release build

# Run tests
xcodebuild -project FocusLite.xcodeproj -scheme FocusLite -destination 'platform=macOS' test

# Run a single test class
xcodebuild -project FocusLite.xcodeproj -scheme FocusLite -destination 'platform=macOS' -only-testing:FocusLiteTests/MatchingTests test

# Run a single test method
xcodebuild -project FocusLite.xcodeproj -scheme FocusLite -destination 'platform=macOS' -only-testing:FocusLiteTests/MatchingTests/testAcceptanceRankingCases test

# Archive for distribution
xcodebuild -project FocusLite.xcodeproj -scheme FocusLite -configuration Release -archivePath build/FocusLite.xcarchive archive
```

The project uses an `.xcodeproj` (not `.xcworkspace`), with SPM dependencies declared directly in the project file. **Do not** convert it to an xcworkspace.

## Architecture

### Application Entry Point

`FocusLite/FocusLiteApp.swift` — `@main` struct using `MenuBarExtra` for the menu bar icon. Uses `NSApplicationDelegateAdaptor` to delegate lifecycle to `AppDelegate`.

### Core Layers

```
FocusLite/                 # UI layer (SwiftUI views + AppKit controllers)
FocusLiteCore/             # Framework-agnostic logic (search, preferences, onboarding)
FocusLitePlugins/          # Feature plugins implementing ResultProvider
```

### Plugin System

Every feature is a `ResultProvider` (defined in `FocusLiteCore/Search/ResultProvider.swift`):

```swift
protocol ResultProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    func results(for query: String, isScoped: Bool) async -> [ResultItem]
}
```

Plugins are instantiated and registered in `AppDelegate.applicationDidFinishLaunching()` (line 50). Each plugin has a static `providerID` string. Adding a new feature means creating a new `ResultProvider` and adding it to the providers array.

### Search Flow

1. **Input** → `LauncherView` text field binding to `LauncherViewModel.searchText`
2. **State reduction** → `SearchStateReducer` classifies input: detects prefix matching (e.g., "Sn " → Snippets scoped mode) or stays in global search
3. **Query dispatch** → `SearchEngine.search()` fans out to all active providers concurrently via `withTaskGroup`
4. **Results** → `[ResultItem]` sorted by score descending, then title length, then alphabetical
5. **Action execution** → `LauncherViewModel.submitPrimaryAction()` switches on `ResultAction` enum: `.runApp`, `.copyText`, `.pasteText`, `.openURL`, `.copyImage`, `.copyFiles`

### Prefix/Tag System

`PrefixRegistry` (in `FocusLiteCore`) defines scoped search entries. Each plugin can register a prefix (e.g., "Sn" for snippets, "tr" for translate). When the user types a prefix followed by a space, `SearchStateReducer` switches to `SearchScope.prefixed(providerID:)`. The prefix itself is determined by user-configurable `@AppStorage` preferences.

### Result Model

`ResultItem` (in `FocusLiteCore/Search/ResultItem.swift`) is the universal result type with:
- `action: ResultAction` — what happens on Enter
- `category: ResultCategory` — `.calc` (pinned to top for math queries) or `.standard`
- `isPrefix: Bool` — whether this item is a prefix suggestion (activates scoped mode)
- `preview: ResultPreview?` — optional preview data (text, image, files)

### Key AppKit/SwiftUI Bridge

- `LauncherWindowController` — `NSWindowDelegate` managing a borderless `.floating` level `NSWindow` containing a `NSHostingView` with `LauncherView`
- `HotKeyManager` — Carbon `RegisterEventHotKey` wrapper; singleton, supports multiple hotkeys with identifier-based registration
- `AppDelegate` — sets `.accessory` activation policy (no Dock icon), wires clipboard monitor, registers 4 hotkeys (launcher, clipboard, snippets, translate)

### Preferences

All settings use `@AppStorage` in SwiftUI views backed by key constants in `FocusLiteCore/Preferences/`. Each feature has its own preferences struct (e.g., `ClipboardPreferences`, `TranslatePreferences`) defining static keys and computed defaults.

### Data Storage

```
~/Library/Application Support/FocusLite/
├── clipboard_history.json
└── snippets.json
```

### Dependencies (SPM)

- **Sparkle 2.8.1** — app update framework; `AppUpdater` wraps `SPUStandardUpdaterController`
- **LaunchAtLogin-Modern** — login item management (via `sindresorhus/LaunchAtLogin-Modern`)

### Matching Engine (AppSearch plugin)

The fuzzy matching for app names is specified in `MatchingSpec.md` at the repo root. Key types:
- `Matcher.match(query:index:)` — produces a `MatchResult` with a `bucket` (exact, prefix, substring, token, acronym, pinyin, fuzzy) and `finalScore`
- `AppNameIndex` — pre-processed name representation with tokens, acronyms, pinyin variants
- `UserAliasStore` — loads `~/Library/Application Support/FocusLite/aliases.json` for custom app aliases
- Pinyin support: **Plan A** (built-in alias table for common Chinese apps) is default; **Plan B** (system `CFStringTransform`) is available as fallback via `SystemPinyinProvider`

## Global Hotkey Format

Hotkeys are stored as user-configurable strings like `"option+space"`. `HotKeyDescriptor.parse()` converts these to Carbon key codes + modifier masks. Changing a hotkey in preferences triggers `UserDefaults.didChangeNotification`, which causes `AppDelegate` to re-register all hotkeys.

## CI/CD

GitHub Actions in `.github/workflows/release.yml`:
- Triggers on `v*` tags
- Builds Release archive with ad-hoc signing
- Generates Sparkle appcast with ED25519 signing
- Creates GitHub Release with the zipped app
- Deploys appcast to GitHub Pages
- **Requires macOS 26 runner** (`macos-26`)
- Requires `SPARKLE_ED25519_PRIVATE_KEY` secret

## Logging

`Log.info()` always prints with `[FocusLite]` prefix. `Log.debug()` only prints in `#if DEBUG` builds. No external logging framework.

## Accessibility Permissions

Auto-paste functionality requires Accessibility permission. `AccessibilityPermission.requestIfNeeded()` checks/prompts. The paste mechanism uses `CGEvent` to simulate Cmd+V after a brief delay.
