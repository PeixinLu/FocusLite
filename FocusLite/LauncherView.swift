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
    private var rowGlassStyleRaw = AppearancePreferences.rowGlassStyle.rawValue
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
    @AppStorage(AppearancePreferences.sunglassesTopSolidKey)
    private var sunglassesTopSolid = AppearancePreferences.defaultSunglassesTopSolid
    @AppStorage(AppearancePreferences.sunglassesTopFadeKey)
    private var sunglassesTopFade = AppearancePreferences.defaultSunglassesTopFade
    @AppStorage(AppearancePreferences.sunglassesMidTopAlphaKey)
    private var sunglassesMidTopAlpha = AppearancePreferences.defaultSunglassesMidTopAlpha
    @AppStorage(AppearancePreferences.sunglassesMidBottomAlphaKey)
    private var sunglassesMidBottomAlpha = AppearancePreferences.defaultSunglassesMidBottomAlpha
    @AppStorage(AppearancePreferences.sunglassesBottomFadeKey)
    private var sunglassesBottomFade = AppearancePreferences.defaultSunglassesBottomFade
    @AppStorage(AppearancePreferences.sunglassesCornerInfluenceKey)
    private var sunglassesCornerInfluence = AppearancePreferences.defaultSunglassesCornerInfluence
    @AppStorage(AppearancePreferences.sunglassesThemeKey)
    private var sunglassesThemeRaw = AppearancePreferences.defaultSunglassesTheme.rawValue
    @AppStorage(AppearancePreferences.sunglassesHDRKey)
    private var sunglassesHDR = AppearancePreferences.defaultSunglassesHDR
    @AppStorage(AppearancePreferences.glassScrimStateKey)
    private var glassScrimState = false
    @AppStorage(AppearancePreferences.glassSubduedStateKey)
    private var glassSubduedState = false
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
        (AppearancePreferences.GlassStyle(rawValue: rowGlassStyleRaw) ?? AppearancePreferences.defaultGlassStyle).baseGlassStyle
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
        let mode = style.baseGlassStyle == .regular ? regularTintMode : clearTintMode
        let tintRaw = style.baseGlassStyle == .regular ? regularTintRaw : clearTintRaw
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
        let base = NSColor(effectiveAccent)
        let alpha: CGFloat = rowGlassStyle.baseGlassStyle == .clear ? 0.28 : 0.24
        return base.withAlphaComponent(alpha)
    }

    private var launcherColorScheme: ColorScheme {
        materialStyle == .sunglasses ? .dark : colorScheme
    }

    private var sunglassesTheme: AppearancePreferences.SunglassesTheme {
        AppearancePreferences.SunglassesTheme(rawValue: sunglassesThemeRaw) ?? .warmAmber
    }

    /// Accent color used throughout the launcher — theme override when set
    private var effectiveAccent: Color {
        if let nsColor = sunglassesTheme.nsColor {
            return Color(nsColor: nsColor)
        }
        return Color.accentColor
    }

    /// HDR-bright text for search field (EDR display only, SDR clips to 1.0)
    private var searchTextColor: Color {
        if materialStyle == .sunglasses, sunglassesHDR {
            return Color(white: 1.3)
        }
        return .primary
    }

    /// Cursor tint: theme color × HDR brightness if enabled
    private var cursorTint: Color {
        guard materialStyle == .sunglasses, let c = sunglassesTheme.rgba else { return effectiveAccent }
        if sunglassesHDR {
            return Color(nsColor: NSColor(calibratedRed: c.r * 1.7,
                                          green: c.g * 1.7,
                                          blue: c.b * 1.7,
                                          alpha: 1.0))
        }
        return Color(nsColor: sunglassesTheme.nsColor!)
    }

    var body: some View {
        let targetWidth: CGFloat = viewModel.showsPreviewPane ? 820 : 640
        let expandedHeight: CGFloat = viewModel.showsPreviewPane ? 460 : 420
        let resultsContentHeight: CGFloat = expandedHeight - compactHeight
        let resultsClipHeight: CGFloat = viewModel.isExpanded ? resultsContentHeight : 0

        LiquidGlassContentContainer(
            cornerRadius: cornerRadius,
            isHighlighted: isHovered || isSearchFocused,
            style: materialStyle,
            glassStyle: glassStyle,
            glassTint: glassTint,
            animationDuration: animationDuration,
            sunglassesTopSolid: sunglassesTopSolid,
            sunglassesTopFade: sunglassesTopFade,
            sunglassesMidTopAlpha: sunglassesMidTopAlpha,
            sunglassesMidBottomAlpha: sunglassesMidBottomAlpha,
            sunglassesBottomFade: sunglassesBottomFade,
            sunglassesCornerInfluence: sunglassesCornerInfluence,
            scrimState: glassScrimState,
            subduedState: glassSubduedState
        ) {
            VStack(spacing: 0) {
                // 搜索框 — 固定锚点，不参与动画，始终可见不被遮挡
                searchBar

                // 结果区 — 向下展开、向上收缩，clip 只影响结果
                ZStack(alignment: .top) {
                    resultsContent(targetWidth: targetWidth, contentHeight: resultsContentHeight)
                }
                .modifier(ClampedFrame(targetHeight: resultsClipHeight, minHeight: 0, width: targetWidth))
            }
            .frame(width: targetWidth)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.showsPreviewPane)
        .overlay(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        viewModel.currentViewSize = geometry.size
                    }
                    .onChange(of: geometry.size) { newSize in
                        viewModel.currentViewSize = newSize
                    }
            }
        )
        .environment(\.colorScheme, launcherColorScheme)
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

    /// 搜索栏 — 固定锚点，不参与动画
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)

            if let prefix = viewModel.searchState.activePrefix {
                TagView(
                    title: prefix.title,
                    subtitle: prefix.subtitle,
                    useLiquidStyle: materialStyle == .liquid,
                    tint: effectiveAccent
                )
            }

            TextField("Search", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(searchTextColor)
                .tint(cursorTint)
                .shadow(color: materialStyle == .sunglasses ? cursorTint.opacity(0.45) : .clear, radius: 7, y: 0)
                .frame(maxWidth: .infinity)
                .focused($isSearchFocused)
                .onChange(of: viewModel.searchText) { newValue in
                    viewModel.updateInput(newValue)
                }
                .onSubmit {
                    viewModel.submitPrimaryAction()
                }

            trailingMenu
        }
        .padding(16)
        .frame(height: compactHeight)
    }

    /// 结果区（分割线 + 列表/预览），始终以完整高度渲染，由 clip 控制可见范围
    @ViewBuilder
    private func resultsContent(targetWidth: CGFloat, contentHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Divider()

            if viewModel.showsPreviewPane {
                HStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                if viewModel.results.isEmpty {
                                    EmptyStateView()
                                        .padding(.top, 40)
                                } else {
                                    ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, item in
                                        resultRow(item: item, index: index)
                                        .id(item.id)
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
                        .transition(.move(edge: .trailing).combined(with: .opacity))

                    PreviewPane(
                        item: viewModel.highlightedItem,
                        currentTargetLanguage: viewModel.currentTranslateTarget,
                        languageOptions: TranslatePreferences.languageOptions,
                        onTargetLanguageChange: { viewModel.setTranslateTarget($0) }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(12)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                .transition(.identity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if viewModel.results.isEmpty {
                                EmptyStateView()
                                    .padding(.top, 40)
                            } else {
                                ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, item in
                                    resultRow(item: item, index: index)
                                    .id(item.id)
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
                .transition(.identity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.showsPreviewPane)
        .frame(width: targetWidth, height: contentHeight)
    }

    private let compactHeight: CGFloat = 64

    private var showsLiquidSelection: Bool {
        materialStyle.isLiquid
    }

    private var isLiquidTuningMode: Bool {
        if case .prefixed(let providerID) = viewModel.searchState.scope {
            return providerID == StyleProvider.providerID
        }
        return false
    }

    private var isClipboardMode: Bool {
        if case .prefixed(let providerID) = viewModel.searchState.scope {
            return providerID == ClipboardProvider.providerID
        }
        return false
    }

    private var selectedGlassTint: NSColor? {
        rowAccentTint
    }

    @ViewBuilder
    private func resultRow(item: ResultItem, index: Int) -> some View {
        let row = ResultRow(
            item: item,
            isSelected: viewModel.selectedIndex == index,
            searchText: viewModel.searchText,
            showsLiquidSelection: showsLiquidSelection
        )

        if isClipboardMode {
            row.onTapGesture {
                let wasSelected = viewModel.selectedIndex == index
                viewModel.selectIndex(index)
                if LauncherViewModel.shouldActivateClipboardResult(wasSelected: wasSelected) {
                    viewModel.submitPrimaryAction()
                }
            }
        } else {
            row.onTapGesture {
                viewModel.selectIndex(index)
                if !isLiquidTuningMode {
                    viewModel.submitPrimaryAction()
                }
            }
        }
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
    private var trailingMenu: some View {
        if isClipboardMode {
            Menu {
                Button {
                    viewModel.openSettings(tab: .clipboard)
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)

                Divider()

                Button(role: .destructive) {
                    viewModel.clearClipboardHistory()
                } label: {
                    Label("清除剪贴板", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("剪贴板菜单")
        } else {
            settingsButton
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
    @AppStorage(AppearancePreferences.sunglassesThemeKey)
    private var sunglassesThemeRaw = AppearancePreferences.defaultSunglassesTheme.rawValue
    @AppStorage(AppearancePreferences.sunglassesHDRKey)
    private var sunglassesHDR = AppearancePreferences.defaultSunglassesHDR

    // Liquid Glass 微调参数（候选项也使用）
    @AppStorage(AppearancePreferences.liquidGlassCornerRadiusKey)
    private var cornerRadius = 16.0
    @AppStorage(AppearancePreferences.liquidGlassAnimationDurationKey)
    private var animationDuration = 0.18

    private var effectiveAccent: Color {
        if let theme = AppearancePreferences.SunglassesTheme(rawValue: sunglassesThemeRaw),
           let nsColor = theme.nsColor {
            return Color(nsColor: nsColor)
        }
        return Color.accentColor
    }

    /// Title color for selected item — HDR-bright white in sunglasses mode
    private var selectedTitleColor: Color {
        if materialStyle == .sunglasses, sunglassesHDR {
            return Color(white: 1.6)
        }
        return .primary
    }

    /// Icon color for selected item — HDR-scaled theme or accent
    private var selectedIconColor: Color {
        guard materialStyle == .sunglasses, sunglassesHDR,
              let theme = AppearancePreferences.SunglassesTheme(rawValue: sunglassesThemeRaw),
              let c = theme.rgba else {
            return effectiveAccent
        }
        return Color(nsColor: NSColor(calibratedRed: c.r * 1.5,
                                       green: c.g * 1.5,
                                       blue: c.b * 1.5,
                                       alpha: 1.0))
    }

    /// Whether to use HDR-enhanced colors for the selected row
    private var useHDRSelectedColors: Bool {
        materialStyle == .sunglasses && sunglassesHDR
    }

    private var isLiquidClear: Bool {
        materialStyle.isLiquid && rowGlassStyle.baseGlassStyle == .clear
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
                        .foregroundColor(isSelected ? selectedTitleColor : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if item.isPrefix {
                        Text("Prefix")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(
                                Capsule()
                                    .fill(effectiveAccent.opacity(0.12))
                            )
                    }
                }
                if let metadata = item.clipboardMetadata {
                    ClipboardMetadataLine(metadata: metadata)
                } else if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(item.isPrefix ? effectiveAccent : .secondary)
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
                .foregroundColor(isSelected ? selectedIconColor : effectiveAccent)
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
        } else if item.providerID == WebSearchProvider.providerID, item.action != .none {
            keyCaps(labels: ["⏎"], description: "搜索")
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
            return effectiveAccent.opacity(opacity)
        }
        if materialStyle == .classic {
            return Color(nsColor: .controlBackgroundColor).opacity(0.25)
        }
        let opacity: Double = isLiquidClear ? 0.4 : 0.55
        return Color(nsColor: .controlBackgroundColor).opacity(opacity)
    }

    private var hoverFillColor: Color {
        let opacity: Double = isLiquidClear ? 0.08 : 0.06
        return effectiveAccent.opacity(opacity)
    }

}

private struct ClipboardMetadataLine: View {
    let metadata: ClipboardResultMetadata

    var body: some View {
        HStack(spacing: 5) {
            sourceApp
            separator
            Text(metadata.timeText)
            separator
            Text(metadata.typeText)
            separator
            Text(metadata.sizeText)
        }
        .font(.system(size: 12))
        .foregroundColor(.secondary)
        .lineLimit(1)
        .truncationMode(.tail)
    }

    private var sourceApp: some View {
        HStack(spacing: 4) {
            if let bundleID = metadata.sourceBundleID,
               let image = AppIconCache.shared.icon(forBundleIdentifier: bundleID) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 13, height: 13)
            }
            Text(metadata.sourceAppName?.nonEmpty ?? "未知来源")
        }
    }

    private var separator: some View {
        Text("·")
            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
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
    @State private var sunglassesTopSolid = AppearancePreferences.sunglassesTopSolid
    @State private var sunglassesTopFade = AppearancePreferences.sunglassesTopFade
    @State private var sunglassesMidTopAlpha = AppearancePreferences.sunglassesMidTopAlpha
    @State private var sunglassesMidBottomAlpha = AppearancePreferences.sunglassesMidBottomAlpha
    @State private var sunglassesBottomFade = AppearancePreferences.sunglassesBottomFade
    @State private var sunglassesCornerInfluence = AppearancePreferences.sunglassesCornerInfluence
    @State private var sunglassesThemeRaw = AppearancePreferences.sunglassesTheme.rawValue
    @State private var sunglassesHDR = AppearancePreferences.sunglassesHDR
    @AppStorage(AppearancePreferences.glassScrimStateKey)
    private var glassScrimState = false
    @AppStorage(AppearancePreferences.glassSubduedStateKey)
    private var glassSubduedState = false
    @State private var showSunglassesTuning = false

    private var effectiveAccent: Color {
        if let theme = AppearancePreferences.SunglassesTheme(rawValue: sunglassesThemeRaw),
           let nsColor = theme.nsColor {
            return Color(nsColor: nsColor)
        }
        return Color.accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            groupContent
            Spacer()
        }
        .tint(effectiveAccent)
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
            let raw = glassStyle.baseGlassStyle == .regular ? regularTintModeRaw : clearTintModeRaw
            return AppearancePreferences.TintMode(rawValue: raw)
            ?? AppearancePreferences.defaultTintMode(for: glassStyle)
        }
        nonmutating set {
            if glassStyle.baseGlassStyle == .regular {
                regularTintModeRaw = newValue.rawValue
            } else {
                clearTintModeRaw = newValue.rawValue
            }
            AppearancePreferences.setGlassTintMode(newValue, for: glassStyle)
        }
    }

    private var activeTintRaw: String {
        get { glassStyle.baseGlassStyle == .regular ? regularTintRaw : clearTintRaw }
        nonmutating set {
            if glassStyle.baseGlassStyle == .regular {
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
                    if !materialStyle.isLiquid {
                        AppearancePreferences.setGlassTintMode(.off, for: .regular)
                        AppearancePreferences.setGlassTintMode(.systemDefault, for: .clear)
                    }
                }
            )) {
                Text(AppearancePreferences.MaterialStyle.classic.displayName).tag(AppearancePreferences.MaterialStyle.classic.rawValue)
                Text(AppearancePreferences.MaterialStyle.liquid.displayName).tag(AppearancePreferences.MaterialStyle.liquid.rawValue)
                Text(AppearancePreferences.MaterialStyle.sunglasses.displayName).tag(AppearancePreferences.MaterialStyle.sunglasses.rawValue)
                Text(AppearancePreferences.MaterialStyle.pure.displayName).tag(AppearancePreferences.MaterialStyle.pure.rawValue)
            }
            .pickerStyle(.segmented)

            if materialStyle.isLiquid {
                Picker("液态玻璃风格", selection: Binding(
                    get: { glassStyleRaw },
                set: { newValue in
                    glassStyleRaw = newValue
                    if let style = AppearancePreferences.GlassStyle(rawValue: newValue) {
                        AppearancePreferences.glassStyle = style
                    }
                }
            )) {
                ForEach(AppearancePreferences.GlassStyle.allCases) { style in
                    Text(style.displayName).tag(style.rawValue)
                }
            }
            .pickerStyle(.menu)

                // scrim / subdued
                Divider()
                Toggle("Scrim", isOn: $glassScrimState)
                    .font(.system(size: 12))
                Toggle("Subdued", isOn: $glassSubduedState)
                    .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 10) {
                if materialStyle == .sunglasses {
                    DisclosureGroup("微调（展开）", isExpanded: $showSunglassesTuning) {
                        TuningSlider(
                            title: "顶部纯黑高度",
                            value: debouncedBinding(
                                state: $sunglassesTopSolid,
                                key: "sgTopSolid",
                                apply: { AppearancePreferences.sunglassesTopSolid = $0 }
                            ),
                            range: 1...60,
                            step: 1,
                            unit: " pt"
                        )
                        TuningSlider(
                            title: "上段过渡高度",
                            value: debouncedBinding(
                                state: $sunglassesTopFade,
                                key: "sgTopFade",
                                apply: { AppearancePreferences.sunglassesTopFade = $0 }
                            ),
                            range: 1...100,
                            step: 1,
                            unit: " pt"
                        )
                        TuningSlider(
                            title: "上段目标黑度",
                            value: debouncedBinding(
                                state: $sunglassesMidTopAlpha,
                                key: "sgMidTopA",
                                apply: { AppearancePreferences.sunglassesMidTopAlpha = $0 }
                            ),
                            range: 0.50...1.00,
                            step: 0.05,
                            unit: ""
                        )
                        TuningSlider(
                            title: "下段起始黑度",
                            value: debouncedBinding(
                                state: $sunglassesMidBottomAlpha,
                                key: "sgMidBotA",
                                apply: { AppearancePreferences.sunglassesMidBottomAlpha = $0 }
                            ),
                            range: 0.05...0.50,
                            step: 0.05,
                            unit: ""
                        )
                        TuningSlider(
                            title: "底段过渡高度",
                            value: debouncedBinding(
                                state: $sunglassesBottomFade,
                                key: "sgBotFade",
                                apply: { AppearancePreferences.sunglassesBottomFade = $0 }
                            ),
                            range: 1...60,
                            step: 1,
                            unit: " pt"
                        )
                        TuningSlider(
                            title: "角落弯曲强度",
                            value: debouncedBinding(
                                state: $sunglassesCornerInfluence,
                                key: "sgCornerInf",
                                apply: { AppearancePreferences.sunglassesCornerInfluence = $0 }
                            ),
                            range: 0.0...1.0,
                            step: 0.1,
                            unit: ""
                        )
                        Toggle("HDR 文字高亮", isOn: $sunglassesHDR)
                            .onChange(of: sunglassesHDR) { newValue in
                                AppearancePreferences.sunglassesHDR = newValue
                            }
                    }
                }

                Toggle(isOn: tintEnabledBinding) {
                    HStack {
                        Text("色调")
                        Spacer()
                        Text(glassStyle.baseGlassStyle == .regular ? "Regular 独立色调" : "Clear 独立色调")
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
                range: 4...40,
                step: 1,
                unit: "pt"
            )
        }
    }

    private var rowsControls: some View {
        Group {
            if materialStyle.isLiquid {
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

            Picker("主题色", selection: $sunglassesThemeRaw) {
                ForEach(AppearancePreferences.SunglassesTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: sunglassesThemeRaw) { newValue in
                if let theme = AppearancePreferences.SunglassesTheme(rawValue: newValue) {
                    AppearancePreferences.sunglassesTheme = theme
                }
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
    var displayTransform: ((Double) -> Double)? = nil

    private var displayValue: Double {
        displayTransform?(value) ?? value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: displayTransform != nil ? "%.0f" : "%.2f", displayValue) + unit)
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
    let currentTargetLanguage: String
    let languageOptions: [TranslateLanguageOption]
    var onTargetLanguageChange: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let item {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let metadata = item.clipboardMetadata {
                    ClipboardMetadataLine(metadata: metadata)
                } else if let subtitle = item.subtitle {
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
            case .clipboardText(let preview):
                ClipboardTextPreviewView(preview: preview)
                    .id(preview.entryID)
            case .clipboardImage(_, let path):
                if let image = NSImage(contentsOfFile: path) {
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
                    Text("原始图片已不可用")
                        .foregroundColor(.secondary)
                }
            case .clipboardFiles(_, let files):
                ClipboardFilesPreview(files: files)
            case .none:
                Text("No preview available")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        } else if item.providerID == TranslateProvider.providerID {
            // 目标语言切换
            HStack(spacing: 6) {
                Text("翻译为")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Picker("目标语言", selection: Binding(
                    get: { currentTargetLanguage },
                    set: { onTargetLanguageChange?($0) }
                )) {
                    ForEach(languageOptions, id: \.code) { option in
                        Text(option.name).tag(option.code)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
            }
            .padding(.vertical, 4)

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

private struct ClipboardTextPreviewView: View {
    let preview: ClipboardTextPreview

    @State private var fullText: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(metadataText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                if fullText != nil {
                    Button("返回摘要") {
                        fullText = nil
                        errorMessage = nil
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12))
                } else if preview.isTruncated {
                    Button {
                        loadFullText()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("查看完整内容")
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .medium))
                    .disabled(isLoading)
                }
            }

            if let fullText {
                LongClipboardTextView(entryID: preview.entryID, text: fullText)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                    )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(preview.text)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .lineLimit(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    if preview.isTruncated {
                        Text("仅显示摘要，复制操作仍会使用完整内容")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                )
            }
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private var metadataText: String {
        let size = ByteCountFormatter.string(fromByteCount: Int64(preview.byteCount), countStyle: .file)
        return "\(size) · \(preview.lineCount) 行"
    }

    private func loadFullText() {
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil
        loadTask = Task {
            let text = await ClipboardStore.shared.text(for: preview.entryID)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isLoading = false
                if let text {
                    fullText = text
                } else {
                    errorMessage = "完整内容文件已不可用"
                }
            }
        }
    }
}

private struct LongClipboardTextView: NSViewRepresentable {
    let entryID: UUID
    let text: String

    final class Coordinator {
        var loadedEntryID: UUID?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView(usingTextLayoutManager: true)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.documentView = textView
        textView.frame = scrollView.contentView.bounds
        textView.string = text
        context.coordinator.loadedEntryID = entryID
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard context.coordinator.loadedEntryID != entryID,
              let textView = scrollView.documentView as? NSTextView else { return }
        textView.string = text
        context.coordinator.loadedEntryID = entryID
        textView.scrollToBeginningOfDocument(nil)
    }
}

private struct ClipboardFilesPreview: View {
    let files: [FilePreviewItem]

    var body: some View {
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

    func icon(forBundleIdentifier bundleIdentifier: String) -> NSImage? {
        let key = "bundle:\(bundleIdentifier)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        cache.setObject(image, forKey: key)
        return image
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

// MARK: - Animatable clip modifier (clamps spring overshoot to prevent search bar clipping)

private struct ClampedFrame: AnimatableModifier {
    var targetHeight: CGFloat
    let minHeight: CGFloat
    let width: CGFloat

    var animatableData: CGFloat {
        get { targetHeight }
        set { targetHeight = max(minHeight, newValue) }
    }

    func body(content: Content) -> some View {
        content
            .frame(width: width, height: targetHeight, alignment: .top)
            .clipped()
    }
}
