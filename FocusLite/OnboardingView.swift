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
                handleKey(event: event)
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
            Text("按下唤起搜索的快捷键")
                .font(.system(size: 22, weight: .bold))
            Text("当前快捷键：\(state.launcherHotKeyText)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            Text("可在「设置 - 通用」修改。")
                .font(.system(size: 14))
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
                Label("完成 ✅", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16, weight: .semibold))
            } else {
                Text("请按下快捷键，完成后将自动进入下一步。")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var overviewStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("核心能力速览")
                .font(.system(size: 22, weight: .bold))
            VStack(alignment: .leading, spacing: 8) {
                bullet("搜索应用、文件夹，输入 `/` 进入快捷目录，`?` 置顶浏览器搜索")
                bullet("直接算式：如 `1+2*3`")
                bullet("输入网址/关键字：快速在浏览器打开")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var prefixesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("三大默认前缀")
                .font(.system(size: 22, weight: .bold))
            Text("点击前缀查看示例，不依赖真实搜索，低耦合且直观演示。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            prefixChips
            demoSearch
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appearanceStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("外观与主题调节")
                .font(.system(size: 22, weight: .bold))
            Text("在搜索框中可调节外观/主题；前往设置可进一步微调玻璃效果与配色。")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var indicator: some View {
        HStack(spacing: 8) {
            ForEach(Array(OnboardingState.Step.allCases.enumerated()), id: \.element) { index, step in
                let isActive = step == state.currentStep
                Circle()
                    .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: isActive ? 12 : 8, height: isActive ? 12 : 8)
                    .animation(.easeInOut(duration: 0.2), value: isActive)
            }
        }
    }

    private var footer: some View {
        HStack {
            if state.currentStep != .appearance {
                Button("我是老手，跳过教程") {
                    state.dismiss(markSeen: true)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 6)
            } else {
                Spacer()
            }

            Spacer()

            let nextTitle = state.currentStep == .appearance ? "已学会并成为老手😎" : "下一步"
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
                demoResult = "剪贴板: 最近复制的文本"
            })
            chip(title: SnippetsPreferences.searchPrefix, subtitle: "文本片段", action: {
                playDemo(query: "\(SnippetsPreferences.searchPrefix) 邮箱")
                demoResult = "片段: 填充常用邮箱"
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

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.08))
                .overlay(
                    VStack(alignment: .leading, spacing: 6) {
                        Text("示例结果")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(demoResult)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(12)
                )
                .frame(height: 70)
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

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }

    private func handleKey(event: NSEvent) -> NSEvent? {
        if isRecordingHotKey {
            return event
        }
        switch event.keyCode {
        case 36, 48: // return, tab
            advance()
            return nil
        case 124, 125: // right, down
            advance()
            return nil
        case 123, 126: // left, up
            goBack()
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

private struct LiquidGlassBackground: View {
    let cornerRadius: CGFloat
    let isHighlighted: Bool
    let style: AppearancePreferences.MaterialStyle
    let glassStyle: AppearancePreferences.GlassStyle
    let glassTint: NSColor?
    let animationDuration: Double

    var body: some View {
        ZStack {
            backgroundBase
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(.easeInOut(duration: animationDuration), value: isHighlighted && style == .liquid)
    }

    @ViewBuilder
    private var backgroundBase: some View {
        switch style {
        case .classic:
            VisualEffectView(
                material: .popover,
                blendingMode: .behindWindow,
                state: .active
            )
        case .liquid:
            VisualEffectView(
                material: glassMaterial,
                blendingMode: .behindWindow,
                state: .active
            )
        case .pure:
            Color(nsColor: .windowBackgroundColor)
        }
    }

    private var glassMaterial: NSVisualEffectView.Material {
        if #available(macOS 26, *) {
            return .hudWindow
        }
        if #available(macOS 13, *) {
            return glassStyle == .clear ? .hudWindow : .popover
        }
        return glassStyle == .clear ? .hudWindow : .hudWindow
    }
}

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = state
        view.blendingMode = blendingMode
        view.material = material
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = state
        nsView.blendingMode = blendingMode
        nsView.material = material
    }
}

private func colorFromRGBA(_ raw: String) -> NSColor? {
    let parts = raw.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    guard parts.count == 4 else { return nil }
    let r = CGFloat(parts[0] / 255.0)
    let g = CGFloat(parts[1] / 255.0)
    let b = CGFloat(parts[2] / 255.0)
    let a = CGFloat(parts[3])
    return NSColor(red: r, green: g, blue: b, alpha: a)
}
