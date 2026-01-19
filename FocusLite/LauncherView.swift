import AppKit
import SwiftUI
import Carbon.HIToolbox

struct LauncherView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isSearchFocused: Bool
    @State private var isHovered = false
    @AppStorage(AppearancePreferences.materialStyleKey)
    private var materialStyleRaw = AppearancePreferences.defaultMaterialStyle.rawValue
    @AppStorage(AppearancePreferences.glassStyleKey)
    private var glassStyleRaw = AppearancePreferences.defaultGlassStyle.rawValue
    @AppStorage(AppearancePreferences.rowGlassStyleKey)
    private var rowGlassStyleRaw = AppearancePreferences.glassStyle.rawValue
    @AppStorage(AppearancePreferences.glassTintModeRegularKey)
    private var regularTintModeRaw = AppearancePreferences.defaultTintMode(for: .regular).rawValue
    @AppStorage(AppearancePreferences.glassTintModeClearKey)
    private var clearTintModeRaw = AppearancePreferences.defaultTintMode(for: .clear).rawValue
    @AppStorage(AppearancePreferences.glassTintRegularKey)
    private var regularTintRaw = AppearancePreferences.glassTintRegular
    @AppStorage(AppearancePreferences.glassTintClearKey)
    private var clearTintRaw = AppearancePreferences.glassTintClear
    
    // Liquid Glass 微调参数
    @AppStorage(AppearancePreferences.liquidGlassAnimationDurationKey)
    private var animationDuration = AppearancePreferences.defaultAnimationDuration
    @AppStorage(AppearancePreferences.liquidGlassCornerRadiusKey)
    private var cornerRadius = AppearancePreferences.defaultCornerRadius
    private var rowCornerRadius: CGFloat {
        max(8, min(CGFloat(cornerRadius) - 6, CGFloat(cornerRadius)))
    }

    private var materialStyle: AppearancePreferences.MaterialStyle {
        AppearancePreferences.MaterialStyle(rawValue: materialStyleRaw) ?? AppearancePreferences.defaultMaterialStyle
    }

    private var glassStyle: AppearancePreferences.GlassStyle {
        AppearancePreferences.GlassStyle(rawValue: glassStyleRaw) ?? AppearancePreferences.defaultGlassStyle
    }

    private var rowGlassStyle: AppearancePreferences.GlassStyle {
        AppearancePreferences.GlassStyle(rawValue: rowGlassStyleRaw) ?? AppearancePreferences.defaultGlassStyle
    }

    private var regularTintMode: AppearancePreferences.TintMode {
        AppearancePreferences.TintMode(rawValue: regularTintModeRaw)
        ?? AppearancePreferences.defaultTintMode(for: .regular)
    }

    private var clearTintMode: AppearancePreferences.TintMode {
        AppearancePreferences.TintMode(rawValue: clearTintModeRaw)
        ?? AppearancePreferences.defaultTintMode(for: .clear)
    }

    private var defaultTintColor: NSColor {
        let base = colorScheme == .dark ? NSColor.black : NSColor.white
        return base.withAlphaComponent(0.618)
    }

    private func resolvedTint(for style: AppearancePreferences.GlassStyle) -> NSColor? {
        let mode = style == .regular ? regularTintMode : clearTintMode
        let tintRaw = style == .regular ? regularTintRaw : clearTintRaw
        switch mode {
        case .off:
            return nil
        case .custom:
            return colorFromRGBA(tintRaw) ?? defaultTintColor
        case .systemDefault:
            return defaultTintColor
        }
    }

    private var glassTint: NSColor? {
        resolvedTint(for: glassStyle)
    }

    private var rowAccentTint: NSColor {
        let base = NSColor(Color.accentColor)
        let alpha: CGFloat = rowGlassStyle == .clear ? 0.28 : 0.24
        return base.withAlphaComponent(alpha)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)

                if let prefix = viewModel.searchState.activePrefix {
                    TagView(
                        title: prefix.title,
                        subtitle: prefix.subtitle,
                        useLiquidStyle: materialStyle == .liquid,
                        tint: Color.accentColor
                    )
                }

                TextField("Search", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .focused($isSearchFocused)
                    .onChange(of: viewModel.searchText) { newValue in
                        viewModel.updateInput(newValue)
                    }
                    .onSubmit {
                        viewModel.submitPrimaryAction()
                    }

                settingsButton
            }
            .padding(16)

            Divider()

            if showsPreviewPane {
                HStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                if viewModel.results.isEmpty {
                                    EmptyStateView()
                                        .padding(.top, 40)
                                } else {
                                    ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, item in
                                        ResultRow(
                                            item: item,
                                            isSelected: viewModel.selectedIndex == index,
                                            searchText: viewModel.searchText,
                                            showsLiquidSelection: showsLiquidSelection
                                        )
                                            .id(item.id)
                                            .onTapGesture {
                                                viewModel.selectIndex(index)
                                                if !isLiquidTuningMode {
                                                    viewModel.submitPrimaryAction()
                                                }
                                            }
                                    }
                                }
                            }
                            .backgroundPreferenceValue(SelectedRowBoundsPreferenceKey.self) { anchor in
                                selectionBackgroundLayer(for: anchor)
                            }
                            .padding(12)
                        }
                        .frame(width: 340)
                        .onChange(of: viewModel.selectedIndex) { index in
                            guard let index,
                                  viewModel.results.indices.contains(index) else { return }
                            let duration = viewModel.shouldAnimateSelection ? 0.12 : 0
                            withAnimation(.easeInOut(duration: duration)) {
                                proxy.scrollTo(viewModel.results[index].id, anchor: .center)
                            }
                            viewModel.shouldAnimateSelection = false
                        }
                    }

                    Divider()

                    PreviewPane(item: viewModel.highlightedItem)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(12)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if viewModel.results.isEmpty {
                                EmptyStateView()
                                    .padding(.top, 40)
                            } else {
                            ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, item in
                                ResultRow(
                                    item: item,
                                    isSelected: viewModel.selectedIndex == index,
                                    searchText: viewModel.searchText,
                                    showsLiquidSelection: showsLiquidSelection
                                )
                                .id(item.id)
                                .onTapGesture {
                                    viewModel.selectIndex(index)
                                    if !isLiquidTuningMode {
                                        viewModel.submitPrimaryAction()
                                    }
                                }
                            }
                        }
                        }
                        .backgroundPreferenceValue(SelectedRowBoundsPreferenceKey.self) { anchor in
                            selectionBackgroundLayer(for: anchor)
                        }
                        .padding(12)
                    }
                    .onChange(of: viewModel.selectedIndex) { index in
                        guard let index,
                              viewModel.results.indices.contains(index) else { return }
                        let duration = viewModel.shouldAnimateSelection ? 0.12 : 0
                        withAnimation(.easeInOut(duration: duration)) {
                            proxy.scrollTo(viewModel.results[index].id, anchor: .center)
                        }
                        viewModel.shouldAnimateSelection = false
                    }
                }
            }
        }
        .background(
            LiquidGlassBackground(
                cornerRadius: cornerRadius,
                isHighlighted: isHovered || isSearchFocused,
                style: materialStyle,
                glassStyle: glassStyle,
                glassTint: glassTint,
                animationDuration: animationDuration
            )
        )
        .frame(width: showsPreviewPane ? 820 : 640, height: showsPreviewPane ? 460 : 420)
        .onAppear {
            isSearchFocused = true
        }
        .onHover { isHovered = $0 }
        .onChange(of: viewModel.focusToken) { _ in
            isSearchFocused = true
        }
        .onExitCommand {
            viewModel.handleEscapeKey()
        }
        .overlay(alignment: .topTrailing) {
            if let message = viewModel.toastMessage {
                ToastView(message: message)
                    .padding(12)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage != nil)
    }

    private var showsPreviewPane: Bool {
        guard case .prefixed(let providerID) = viewModel.searchState.scope else { return false }
        return providerID == ClipboardProvider.providerID || 
               providerID == SnippetsProvider.providerID || 
               providerID == TranslateProvider.providerID ||
               providerID == StyleProvider.providerID
    }

    private var showsLiquidSelection: Bool {
        materialStyle == .liquid
    }

    private var isLiquidTuningMode: Bool {
        if case .prefixed(let providerID) = viewModel.searchState.scope {
            return providerID == StyleProvider.providerID
        }
        return false
    }

    private var selectedGlassTint: NSColor? {
        rowAccentTint
    }

    @ViewBuilder
    private func selectionBackgroundLayer(for anchor: Anchor<CGRect>?) -> some View {
        if showsLiquidSelection, let anchor {
            GeometryReader { proxy in
                let rect = proxy[anchor]
                LiquidGlassRowBackground(
                    cornerRadius: rowCornerRadius,
                    glassStyle: rowGlassStyle,
                    glassTint: selectedGlassTint
                )
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .animation(viewModel.shouldAnimateSelection ? .easeInOut(duration: animationDuration) : .none, value: rect)
            }
        }
    }


    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14, *) {
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .simultaneousGesture(TapGesture().onEnded {
                viewModel.prepareSettings(tab: viewModel.preferredSettingsTab())
            })
            .help("设置")
        } else {
            Button {
                viewModel.openSettings(tab: viewModel.preferredSettingsTab())
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .help("设置")
        }
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
        // 边框已移除，可以在设置中重新启用
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
            if #available(macOS 26, *) {
                GlassBackgroundView(
                    cornerRadius: cornerRadius,
                    style: glassStyle,
                    tintColor: glassTint
                )
            } else {
                VisualEffectView(
                    material: glassMaterial,
                    blendingMode: .behindWindow,
                    state: .active
                )
            }
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

@available(macOS 26, *)
private struct GlassBackgroundView: NSViewRepresentable {
    let cornerRadius: CGFloat
    let style: AppearancePreferences.GlassStyle
    let tintColor: NSColor?

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.cornerRadius = cornerRadius
        view.style = style.nsStyle
        view.tintColor = tintColor
        return view
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.style = style.nsStyle
        nsView.tintColor = tintColor
    }
}

private func colorFromRGBA(_ raw: String) -> NSColor? {
    let parts = raw.split(separator: ",").compactMap { Double($0) }
    guard parts.count == 4 else { return nil }
    return NSColor(
        calibratedRed: parts[0],
        green: parts[1],
        blue: parts[2],
        alpha: parts[3]
    )
}

@available(macOS 26, *)
private extension AppearancePreferences.GlassStyle {
    var nsStyle: NSGlassEffectView.Style {
        switch self {
        case .regular:
            return .regular
        case .clear:
            return .clear
        }
    }
}

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

private struct SelectedRowBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

private struct ResultRow: View {
    let item: ResultItem
    let isSelected: Bool
    let searchText: String
    let showsLiquidSelection: Bool
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppearancePreferences.materialStyleKey)
    private var materialStyleRaw = AppearancePreferences.MaterialStyle.liquid.rawValue
    @AppStorage(AppearancePreferences.rowGlassStyleKey)
    private var rowGlassStyleRaw = AppearancePreferences.glassStyle.rawValue
    
    // Liquid Glass 微调参数（候选项也使用）
    @AppStorage(AppearancePreferences.liquidGlassCornerRadiusKey)
    private var cornerRadius = 16.0
    @AppStorage(AppearancePreferences.liquidGlassAnimationDurationKey)
    private var animationDuration = 0.18

    private var isLiquidClear: Bool {
        materialStyle == .liquid && rowGlassStyle == .clear
    }

    private var materialStyle: AppearancePreferences.MaterialStyle {
        AppearancePreferences.MaterialStyle(rawValue: materialStyleRaw) ?? .liquid
    }

    private var rowGlassStyle: AppearancePreferences.GlassStyle {
        AppearancePreferences.GlassStyle(rawValue: rowGlassStyleRaw) ?? .regular
    }

    private var rowCornerRadiusValue: CGFloat {
        max(8, min(CGFloat(cornerRadius) - 6, CGFloat(cornerRadius)))
    }

    var body: some View {
        HStack(spacing: 12) {
            iconView

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if item.isPrefix {
                        Text("Prefix")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                    }
                }
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(item.isPrefix ? .accentColor : .secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: rowCornerRadiusValue)
                    .fill(selectionFillColor)
                if isHovered && !isSelected {
                    RoundedRectangle(cornerRadius: rowCornerRadiusValue)
                        .fill(hoverFillColor)
                }
            }
        }
        .overlay(alignment: .trailing) {
            actionHint
                .padding(.trailing, 10)
        }
        .contentShape(Rectangle())
        .anchorPreference(key: SelectedRowBoundsPreferenceKey.self, value: .bounds) { anchor in
            isSelected && showsLiquidSelection ? anchor : nil
        }
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var iconView: some View {
        switch item.icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundColor(.accentColor)
        case .bundle(let name):
            if let image = NSImage(named: name) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            } else {
                placeholderIcon
            }
        case .filePath(let path):
            if let image = AppIconCache.shared.icon(for: path) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            } else {
                placeholderIcon
            }
        case .none:
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(nsColor: .tertiaryLabelColor))
            .frame(width: 28, height: 28)
            .opacity(0.4)
    }

    @ViewBuilder
    private var actionHint: some View {
        if !isSelected {
            EmptyView()
        } else if item.action == .none && !item.isPrefix {
            EmptyView()
        } else if item.isPrefix {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let prefixText = item.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let labels = query == prefixText ? ["␣", "⏎"] : ["⏎"]
            keyCaps(labels: labels, description: "进入")
        } else if item.providerID == AppSearchProvider.providerID ||
                    item.providerID == QuickDirectoryProvider.providerID {
            keyCaps(labels: ["⏎"], description: "打开")
        } else if item.providerID == SnippetsProvider.providerID ||
                    item.providerID == ClipboardProvider.providerID ||
                    item.providerID == TranslateProvider.providerID {
            keyCaps(labels: ["⏎"], description: "拷贝")
        } else {
            EmptyView()
        }
    }

    private func keyCaps(labels: [String], description: String) -> some View {
        HStack(spacing: 6) {
            let joined = labels.joined(separator: "/")
            Text("\(joined) \(description)")
                .font(.system(size: 11, weight: .semibold))
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }

    private var selectionFillColor: Color {
        if showsLiquidSelection {
            return .clear
        }
        if isSelected {
            let opacity: Double = isLiquidClear ? 0.26 : 0.15
            return Color.accentColor.opacity(opacity)
        }
        if materialStyle == .classic {
            return Color(nsColor: .controlBackgroundColor).opacity(0.25)
        }
        let opacity: Double = isLiquidClear ? 0.4 : 0.55
        return Color(nsColor: .controlBackgroundColor).opacity(opacity)
    }

    private var hoverFillColor: Color {
        let opacity: Double = isLiquidClear ? 0.08 : 0.06
        return Color.accentColor.opacity(opacity)
    }

}

private struct LiquidGlassRowBackground: View {
    let cornerRadius: CGFloat
    let glassStyle: AppearancePreferences.GlassStyle
    let glassTint: NSColor?

    var body: some View {
        ZStack {
            if #available(macOS 26, *) {
                GlassBackgroundView(
                    cornerRadius: cornerRadius,
                    style: glassStyle,
                    tintColor: glassTint
                )
            } else {
                VisualEffectView(
                    material: glassStyle == .clear ? .hudWindow : .popover,
                    blendingMode: .behindWindow,
                    state: .active
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
        )
    }
}

private struct LiquidTuningPreview: View {
    let group: LiquidTuningGroup

    @Environment(\.colorScheme) private var colorScheme

    @State private var materialStyleRaw = AppearancePreferences.materialStyle.rawValue
    @State private var glassStyleRaw = AppearancePreferences.glassStyle.rawValue
    @State private var rowGlassStyleRaw = AppearancePreferences.rowGlassStyle.rawValue
    @State private var regularTintModeRaw = AppearancePreferences.glassTintModeRegular.rawValue
    @State private var clearTintModeRaw = AppearancePreferences.glassTintModeClear.rawValue
    @State private var regularTintRaw = AppearancePreferences.glassTintRegular
    @State private var clearTintRaw = AppearancePreferences.glassTintClear
    @State private var cornerRadius = AppearancePreferences.liquidGlassCornerRadius
    @State private var animationDuration = AppearancePreferences.liquidGlassAnimationDuration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            groupContent
            Spacer()
        }
        .padding(8)
    }

    @ViewBuilder
    private var groupContent: some View {
        switch group {
        case .search:
            searchControls
        case .rows:
            rowsControls
        case .animation:
            animationControls
        }
    }

    private var glassStyle: AppearancePreferences.GlassStyle {
        AppearancePreferences.GlassStyle(rawValue: glassStyleRaw) ?? .regular
    }

    private var rowGlassStyle: AppearancePreferences.GlassStyle {
        AppearancePreferences.GlassStyle(rawValue: rowGlassStyleRaw) ?? .regular
    }

    private var materialStyle: AppearancePreferences.MaterialStyle {
        AppearancePreferences.MaterialStyle(rawValue: materialStyleRaw) ?? .liquid
    }

    private var activeTintMode: AppearancePreferences.TintMode {
        get {
            let raw = glassStyle == .regular ? regularTintModeRaw : clearTintModeRaw
            return AppearancePreferences.TintMode(rawValue: raw)
            ?? AppearancePreferences.defaultTintMode(for: glassStyle)
        }
        nonmutating set {
            if glassStyle == .regular {
                regularTintModeRaw = newValue.rawValue
            } else {
                clearTintModeRaw = newValue.rawValue
            }
            AppearancePreferences.setGlassTintMode(newValue, for: glassStyle)
        }
    }

    private var activeTintRaw: String {
        get { glassStyle == .regular ? regularTintRaw : clearTintRaw }
        nonmutating set {
            if glassStyle == .regular {
                regularTintRaw = newValue
            } else {
                clearTintRaw = newValue
            }
            AppearancePreferences.setGlassTint(newValue, for: glassStyle)
        }
    }

    private var defaultTintColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.618) : Color.white.opacity(0.618)
    }

    private var tintEnabledBinding: Binding<Bool> {
        Binding(
            get: { activeTintMode != .off },
            set: { isOn in
                if isOn {
                    if activeTintMode == .off {
                        let newMode = AppearancePreferences.defaultTintMode(for: glassStyle)
                        activeTintMode = newMode
                        if newMode == .custom && activeTintRaw.isEmpty {
                            activeTintRaw = rgbaString(from: defaultTintColor)
                        }
                    }
                } else {
                    activeTintMode = .off
                }
            }
        )
    }

    private var activeTintColor: Color {
        colorFromRGBA(activeTintRaw) ?? defaultTintColor
    }

    private var activeTintOpacity: Double {
        alphaFromRGBA(activeTintRaw) ?? 0.618
    }

    private var searchControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("材质", selection: Binding(
                get: { materialStyleRaw },
                set: { newValue in
                    materialStyleRaw = newValue
                    if let style = AppearancePreferences.MaterialStyle(rawValue: newValue) {
                        AppearancePreferences.materialStyle = style
                    }
                    if materialStyle != .liquid {
                        AppearancePreferences.setGlassTintMode(.off, for: .regular)
                        AppearancePreferences.setGlassTintMode(.systemDefault, for: .clear)
                    }
                }
            )) {
                Text(AppearancePreferences.MaterialStyle.classic.displayName).tag(AppearancePreferences.MaterialStyle.classic.rawValue)
                Text(AppearancePreferences.MaterialStyle.liquid.displayName).tag(AppearancePreferences.MaterialStyle.liquid.rawValue)
                Text(AppearancePreferences.MaterialStyle.pure.displayName).tag(AppearancePreferences.MaterialStyle.pure.rawValue)
            }
            .pickerStyle(.segmented)

            if materialStyle == .liquid {
                Picker("液态玻璃风格", selection: Binding(
                    get: { glassStyleRaw },
                set: { newValue in
                    glassStyleRaw = newValue
                    if let style = AppearancePreferences.GlassStyle(rawValue: newValue) {
                        AppearancePreferences.glassStyle = style
                    }
                }
            )) {
                Text("Regular").tag(AppearancePreferences.GlassStyle.regular.rawValue)
                Text("Clear").tag(AppearancePreferences.GlassStyle.clear.rawValue)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: tintEnabledBinding) {
                    HStack {
                        Text("色调")
                        Spacer()
                        Text(glassStyle == .regular ? "Regular 独立色调" : "Clear 独立色调")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Picker("色调模式", selection: Binding(
                    get: { activeTintMode.rawValue },
                    set: { newValue in
                        let mode = AppearancePreferences.TintMode(rawValue: newValue) ?? .systemDefault
                        activeTintMode = mode
                        if mode == .custom && activeTintRaw.isEmpty {
                            activeTintRaw = rgbaString(from: defaultTintColor)
                        }
                    }
                )) {
                    Text("默认").tag(AppearancePreferences.TintMode.systemDefault.rawValue)
                    Text("自定义").tag(AppearancePreferences.TintMode.custom.rawValue)
                }
                .pickerStyle(.segmented)
                .disabled(!tintEnabledBinding.wrappedValue)

                if tintEnabledBinding.wrappedValue && activeTintMode == .custom {
                    HStack(spacing: 12) {
                        ColorPicker(
                            "",
                            selection: Binding(
                                get: { activeTintColor },
                                set: { newValue in
                                    activeTintRaw = rgbaString(from: newValue, overrideAlpha: activeTintOpacity)
                                }
                            ),
                            supportsOpacity: false
                        )
                        .labelsHidden()

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("透明度")
                                Spacer()
                                Text(String(format: "%.0f%%", activeTintOpacity * 100))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { activeTintOpacity },
                                    set: { newValue in
                                        activeTintRaw = rgbaString(from: activeTintColor, overrideAlpha: newValue)
                                    }
                                ),
                                in: 0...1,
                                step: 0.01
                            )
                            .controlSize(.small)
                        }
                    }
                } else if tintEnabledBinding.wrappedValue {
                    Text("默认：浅色白色 61.8% 透明度；深色黑色 61.8% 透明度。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text("已关闭色调，使用系统默认透明玻璃。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            } else {
                Text("液态玻璃配置仅在材质为“液态玻璃”时可用。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            TuningSlider(
                title: "搜索框圆角大小",
                value: debouncedBinding(
                    state: $cornerRadius,
                    key: "cornerRadius",
                    apply: { AppearancePreferences.liquidGlassCornerRadius = $0 }
                ),
                range: 8...24,
                step: 1,
                unit: "pt"
            )
        }
    }

    private var rowsControls: some View {
        Group {
            if materialStyle == .liquid {
                Picker("液态玻璃风格", selection: Binding(
                    get: { rowGlassStyleRaw },
                    set: { newValue in
                        rowGlassStyleRaw = newValue
                        if let style = AppearancePreferences.GlassStyle(rawValue: newValue) {
                            AppearancePreferences.rowGlassStyle = style
                        }
                    }
                )) {
                    Text(AppearancePreferences.GlassStyle.regular.displayName).tag(AppearancePreferences.GlassStyle.regular.rawValue)
                    Text(AppearancePreferences.GlassStyle.clear.displayName).tag(AppearancePreferences.GlassStyle.clear.rawValue)
                }
                .pickerStyle(.segmented)
            } else {
                Text("候选项液态玻璃样式仅在材质为“液态玻璃”时可用。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var animationControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            TuningSlider(
                title: "候选项过渡速度",
                value: debouncedBinding(
                    state: $animationDuration,
                    key: "animationDuration",
                    apply: { AppearancePreferences.liquidGlassAnimationDuration = $0 }
                ),
                range: 0.05...0.5,
                step: 0.01,
                unit: "s"
            )
        }
    }

    private func debouncedBinding(
        state: Binding<Double>,
        key: String,
        apply: @escaping (Double) -> Void
    ) -> Binding<Double> {
        Binding(
            get: { state.wrappedValue },
            set: { newValue in
                state.wrappedValue = newValue
                LiquidTuningDebouncer.shared.debounce(key: key) {
                    apply(newValue)
                }
            }
        )
    }

    private func colorFromRGBA(_ raw: String) -> Color? {
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4 else { return nil }
        return Color(.sRGB, red: parts[0], green: parts[1], blue: parts[2], opacity: parts[3])
    }

    private func alphaFromRGBA(_ raw: String) -> Double? {
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4 else { return nil }
        return parts[3]
    }

    private func rgbaString(from color: Color, overrideAlpha: Double? = nil) -> String {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.white
        let alpha = overrideAlpha ?? nsColor.alphaComponent
        return String(format: "%.3f,%.3f,%.3f,%.3f",
                      nsColor.redComponent,
                      nsColor.greenComponent,
                      nsColor.blueComponent,
                      alpha)
    }
}

private struct TuningSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value) + unit)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
        }
    }
}

private final class LiquidTuningDebouncer {
    static let shared = LiquidTuningDebouncer()
    private var workItems: [String: DispatchWorkItem] = [:]
    private let queue = DispatchQueue(label: "liquid.tuning.debounce")

    func debounce(key: String, delay: TimeInterval = 0.18, action: @escaping @MainActor () -> Void) {
        queue.async {
            self.workItems[key]?.cancel()
            let item = DispatchWorkItem {
                Task { @MainActor in
                    action()
                }
            }
            self.workItems[key] = item
            self.queue.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }
}

private extension LiquidTuningGroup {
    static func fromTitle(_ title: String) -> LiquidTuningGroup {
        switch title {
        case LiquidTuningGroup.search.title:
            return .search
        case LiquidTuningGroup.rows.title:
            return .rows
        case LiquidTuningGroup.animation.title:
            return .animation
        default:
            return .search
        }
    }
}

private struct PreviewPane: View {
    let item: ResultItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let item {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Divider()
                content(for: item)
            } else {
                Text("Select an item to preview")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func content(for item: ResultItem) -> some View {
        if item.providerID == ClipboardProvider.providerID || item.providerID == SnippetsProvider.providerID {
            switch item.preview {
            case .text(let text):
                ScrollView {
                    Text(text)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                )
            case .image(let data):
                if let image = NSImage(data: data) {
                    ScrollView {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                            .padding(8)
                    }
                } else {
                    Text("Cannot preview image")
                        .foregroundColor(.secondary)
                }
            case .files(let files):
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(files, id: \.self) { file in
                            HStack(spacing: 8) {
                                if let icon = AppIconCache.shared.icon(for: file.path) {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                } else {
                                    Image(systemName: "doc")
                                        .frame(width: 24, height: 24)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text(file.path)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                        }
                    }
                }
            case .none:
                Text("No preview available")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        } else if item.providerID == TranslateProvider.providerID {
            // 翻译结果预览
            ScrollView {
                Text(item.title)
                    .font(.system(size: 15, weight: .regular))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
            )
        } else if item.providerID == StyleProvider.providerID {
            LiquidTuningPreview(group: LiquidTuningGroup.fromTitle(item.title))
        } else {
            Text("预览仅适用于剪贴板、Snippets、翻译和液态玻璃调试")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Start typing to search")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Text("Results will appear here")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

private struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .semibold))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(radius: 2)
            )
            .foregroundColor(.primary)
    }
}

private final class AppIconCache {
    static let shared = AppIconCache()
    private let cache = NSCache<NSString, NSImage>()

    func icon(for path: String) -> NSImage? {
        if let cached = cache.object(forKey: path as NSString) {
            return cached
        }

        let image = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}
