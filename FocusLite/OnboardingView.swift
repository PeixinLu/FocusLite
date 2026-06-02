import SwiftUI
import AppKit

struct OnboardingView: View {
    @ObservedObject var state: OnboardingState
    @State private var demoQuery: String = ""
    @State private var demoResult: String = "翻译: Hello → 你好"
    @State private var animateTyping = false
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppearancePreferences.materialStyleKey)
    private var materialStyleRaw = AppearancePreferences.defaultMaterialStyle.rawValue
    @AppStorage(AppearancePreferences.glassStyleKey)
    private var glassStyleRaw = AppearancePreferences.defaultGlassStyle.rawValue
    @AppStorage(AppearancePreferences.glassTintModeRegularKey)
    private var regularTintModeRaw = AppearancePreferences.defaultTintMode(for: .regular).rawValue
    @AppStorage(AppearancePreferences.glassTintModeClearKey)
    private var clearTintModeRaw = AppearancePreferences.defaultTintMode(for: .clear).rawValue
    @AppStorage(AppearancePreferences.glassTintRegularKey)
    private var regularTintRaw = AppearancePreferences.glassTintRegular
    @AppStorage(AppearancePreferences.glassTintClearKey)
    private var clearTintRaw = AppearancePreferences.glassTintClear
    @AppStorage(AppearancePreferences.liquidGlassAnimationDurationKey)
    private var animationDuration = AppearancePreferences.defaultAnimationDuration
    @State private var isRecordingHotKey = false
    @State private var keyMonitor: Any?
    @State private var hostingWindow: NSWindow?
    @State private var overviewSelection = 0

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, 28)
                .padding(.top, 26)

            Spacer(minLength: 12)

            indicator
                .padding(.top, 10)

            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .frame(width: 520, height: 420)
        .background(
            LiquidGlassBackground(
                cornerRadius: 18,
                isHighlighted: true,
                style: materialStyle,
                glassStyle: glassStyle,
                glassTint: glassTint,
                animationDuration: animationDuration
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
        .onAppear {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard let window = hostingWindow, window.isKeyWindow else { return event }
                return handleKey(event: event)
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hotKeyRecordingWillBegin)) { _ in
            isRecordingHotKey = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .hotKeyRecordingDidEnd)) { _ in
            isRecordingHotKey = false
        }
        .background(
            WindowAccessor(window: $hostingWindow)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch state.currentStep {
        case .hotkey:
            hotkeyStep
        case .overview:
            overviewStep
        case .prefixes:
            prefixesStep
        case .appearance:
            appearanceStep
        }
    }

    private var hotkeyStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            let displayKey = hotKeyDisplayText(for: state.launcherHotKeyText) ?? "⌘ + 空格"
            Text("设置FocusLite快捷键")
                .font(.system(size: 22, weight: .bold))
            Text("请测试启动搜索框的快捷键「\(displayKey)」，完成后将自动进入下一步")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            HotKeyRecorderField(
                text: Binding(
                    get: { state.launcherHotKeyText },
                    set: { newValue in
                        state.launcherHotKeyText = newValue
                        GeneralPreferences.launcherHotKeyText = newValue
                    }
                ),
                conflictHotKeys: [ClipboardPreferences.hotKeyText]
            ) {
                state.hotkeyStepCompleted = false
            }
            if state.hotkeyStepCompleted {
                Text("完成 🎉")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Text("亦可稍后在「设置-通用」中修改")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var overviewStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("基础能力速览")
                .font(.system(size: 22, weight: .bold))
            Text("键盘[↑][↓]键选中搜索结果，回车打开｜确认｜复制，可在下方尝试交互")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(overviewItems.enumerated()), id: \.offset) { entry in
                    let index = entry.offset
                    let item = entry.element
                    OnboardingCandidateRow(
                        title: item.title,
                        subtitle: item.subtitle,
                        isSelected: overviewSelection == index
                    )
                    .onTapGesture {
                        overviewSelection = index
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var prefixesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("高级功能")
                .font(.system(size: 22, weight: .bold))
            Text("通过可自定义的文本前缀激活 翻译｜剪贴板历史｜文本片段 等功能（亦可在设置中配置各个功能的直达快捷键）")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            prefixChips
            demoSearch
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appearanceStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("自定义外观")
                .font(.system(size: 22, weight: .bold))
            Text("在搜索框输入style并回车即可进入外观配置")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var indicator: some View {
        HStack(spacing: 8) {
            ForEach(Array(OnboardingState.Step.allCases.enumerated()), id: \.element) { index, step in
                let isActive = step == state.currentStep
                Button {
                    state.currentStep = step
                } label: {
                    Circle()
                        .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: isActive ? 12 : 8, height: isActive ? 12 : 8)
                        .animation(.easeInOut(duration: 0.2), value: isActive)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        HStack {
            if state.currentStep != .appearance {
                Button("我是老手，跳过教程 Esc") {
                    state.dismiss(markSeen: true)
                }
                .buttonStyle(.plain)
                .underline()
                .padding(.vertical, 6)
            } else {
                Spacer()
            }

            Spacer()

            if state.currentStep != .hotkey {
                Button("上一页 ←") {
                    goBack()
                }
                .buttonStyle(.bordered)
            }

            let nextTitle = state.currentStep == .appearance ? "已学会并成为老手😎 ⏎" : "下一步 ⏎"
            Button(nextTitle) {
                if state.currentStep == .appearance {
                    state.dismiss(markSeen: true)
                } else {
                    state.advance()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
        }
    }

    private var prefixChips: some View {
        HStack(spacing: 10) {
            chip(title: TranslatePreferences.searchPrefix, subtitle: "翻译", action: {
                playDemo(query: "\(TranslatePreferences.searchPrefix) Hello")
                demoResult = "翻译: Hello → 你好"
            })
            chip(title: ClipboardPreferences.searchPrefix, subtitle: "剪贴板", action: {
                playDemo(query: "\(ClipboardPreferences.searchPrefix) 近期文本")
                demoResult = "在剪贴板历史中搜索包含“近期文本”的项目"
            })
            chip(title: SnippetsPreferences.searchPrefix, subtitle: "文本片段", action: {
                playDemo(query: "\(SnippetsPreferences.searchPrefix) 邮箱")
                demoResult = "在已配置的文本片段中搜索包含“邮箱”的项目"
            })
        }
    }

    private func chip(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    private var demoSearch: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                )
                .overlay(
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                        Text(demoQuery.isEmpty ? "点击上方前缀进行演示" : demoQuery)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(demoQuery.isEmpty ? .secondary : .primary)
                        Spacer()
                    }
                    .padding(12)
                )
                .frame(height: 48)

            OnboardingCandidateRow(title: demoResult, subtitle: nil, isSelected: true, showsIcon: true)
        }
        .padding(.top, 4)
    }

    private func playDemo(query: String) {
        demoQuery = ""
        animateTyping = true
        let chars = Array(query)
        demoQuery = ""
        var index = 0
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            guard index < chars.count else {
                timer.invalidate()
                animateTyping = false
                return
            }
            demoQuery.append(chars[index])
            index += 1
        }
    }

    private func handleKey(event: NSEvent) -> NSEvent? {
        if isRecordingHotKey {
            return event
        }
        if state.currentStep == .overview {
            switch event.keyCode {
            case 125: // down arrow
                overviewSelection = min(overviewSelection + 1, overviewItems.count - 1)
                return nil
            case 126: // up arrow
                overviewSelection = max(overviewSelection - 1, 0)
                return nil
            default:
                break
            }
        }
        switch event.keyCode {
        case 36, 48: // return, tab
            advance()
            return nil
        case 124: // right
            advance()
            return nil
        case 123: // left
            goBack()
            return nil
        case 53: // esc
            state.dismiss(markSeen: true)
            return nil
        default:
            return event
        }
    }

    private func advance() {
        if state.currentStep == .appearance {
            state.dismiss(markSeen: true)
        } else {
            state.advance()
        }
    }

    private func goBack() {
        guard let prev = OnboardingState.Step(rawValue: state.currentStep.rawValue - 1) else {
            return
        }
        state.currentStep = prev
    }

    private struct OverviewItem {
        let title: String
        let subtitle: String
    }

    private var overviewItems: [OverviewItem] {
        [
            OverviewItem(title: "应用搜索", subtitle: "支持中英文名称匹配、亦可配置别名"),
            OverviewItem(title: "快捷目录", subtitle: "输入 / 可以搜索常用文件夹一键打开，可在设置中配置常用的文件夹"),
            OverviewItem(title: "直达浏览器搜索", subtitle: "输入 ？+ 文本，回车即可自动打开浏览器搜索"),
            OverviewItem(title: "简单运算", subtitle: "输入 168 / 2，会自动计算结果，回车复制")
        ]
    }

    private func hotKeyDisplayText(for text: String) -> String? {
        let parts = text
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        var modifiers: [String] = []
        var keyToken: String?
        for token in parts {
            switch token {
            case "command", "cmd", "⌘":
                modifiers.append("⌘")
            case "option", "opt", "alt", "⌥":
                modifiers.append("⌥")
            case "shift", "⇧":
                modifiers.append("⇧")
            case "control", "ctrl", "⌃":
                modifiers.append("⌃")
            default:
                keyToken = token
            }
        }
        let keyText: String
        if let keyToken {
            if keyToken == "space" {
                keyText = "空格"
            } else if keyToken.count == 1 {
                keyText = keyToken.uppercased()
            } else {
                keyText = keyToken.uppercased()
            }
        } else {
            keyText = ""
        }
        let chunks = modifiers + (keyText.isEmpty ? [] : [keyText])
        return chunks.isEmpty ? nil : chunks.joined(separator: " + ")
    }

    private var materialStyle: AppearancePreferences.MaterialStyle {
        AppearancePreferences.MaterialStyle(rawValue: materialStyleRaw) ?? AppearancePreferences.defaultMaterialStyle
    }

    private var glassStyle: AppearancePreferences.GlassStyle {
        AppearancePreferences.GlassStyle(rawValue: glassStyleRaw) ?? AppearancePreferences.defaultGlassStyle
    }

    private var glassTint: NSColor? {
        let mode = glassStyle == .regular
            ? AppearancePreferences.TintMode(rawValue: regularTintModeRaw) ?? AppearancePreferences.defaultTintMode(for: .regular)
            : AppearancePreferences.TintMode(rawValue: clearTintModeRaw) ?? AppearancePreferences.defaultTintMode(for: .clear)
        let tintRaw = glassStyle == .regular ? regularTintRaw : clearTintRaw
        switch mode {
        case .off:
            return nil
        case .custom:
            return colorFromRGBA(tintRaw) ?? defaultTintColor
        case .systemDefault:
            return defaultTintColor
        }
    }

    private var defaultTintColor: NSColor {
        let base = colorScheme == .dark ? NSColor.black : NSColor.white
        return base.withAlphaComponent(0.618)
    }
}

private struct OnboardingCandidateRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    var showsIcon: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if showsIcon {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor).opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}
