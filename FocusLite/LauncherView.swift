import AppKit
import SwiftUI
import Carbon.HIToolbox

struct LauncherView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var isHovered = false
    @AppStorage(AppearancePreferences.materialStyleKey)
    private var materialStyleRaw = AppearancePreferences.MaterialStyle.liquid.rawValue
    @AppStorage(AppearancePreferences.glassStyleKey)
    private var glassStyleRaw = AppearancePreferences.GlassStyle.regular.rawValue
    @AppStorage(AppearancePreferences.glassTintKey)
    private var glassTintRaw = ""
    @AppStorage(AppearancePreferences.liquidGlassExtraBlurMaterialKey)
    private var extraBlurMaterialRaw = AppearancePreferences.ExtraBlurMaterial.system.rawValue
    
    // Liquid Glass 微调参数
    @AppStorage(AppearancePreferences.liquidGlassBlurRadiusKey)
    private var blurRadius = 30.0
    @AppStorage(AppearancePreferences.liquidGlassGradientStartOpacityKey)
    private var gradientStartOpacity = 0.45
    @AppStorage(AppearancePreferences.liquidGlassGradientEndOpacityKey)
    private var gradientEndOpacity = 0.14
    @AppStorage(AppearancePreferences.liquidGlassAnimationDurationKey)
    private var animationDuration = 0.18
    @AppStorage(AppearancePreferences.liquidGlassCornerRadiusKey)
    private var cornerRadius = 16.0
    private let rowCornerRadius: CGFloat = 10.0

    private var materialStyle: AppearancePreferences.MaterialStyle {
        AppearancePreferences.MaterialStyle(rawValue: materialStyleRaw) ?? .liquid
    }

    private var glassStyle: AppearancePreferences.GlassStyle {
        AppearancePreferences.GlassStyle(rawValue: glassStyleRaw) ?? .regular
    }

    private var extraBlurMaterial: AppearancePreferences.ExtraBlurMaterial {
        AppearancePreferences.ExtraBlurMaterial(rawValue: extraBlurMaterialRaw) ?? .system
    }

    private var glassTint: NSColor? {
        colorFromRGBA(glassTintRaw)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)

                if let prefix = viewModel.searchState.activePrefix {
                    TagView(title: prefix.title, subtitle: prefix.subtitle)
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
                            withAnimation(.easeInOut(duration: 0.12)) {
                                proxy.scrollTo(viewModel.results[index].id, anchor: .center)
                            }
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
                        withAnimation(.easeInOut(duration: 0.12)) {
                            proxy.scrollTo(viewModel.results[index].id, anchor: .center)
                        }
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
                blurRadius: blurRadius,
                extraBlurMaterial: extraBlurMaterial,
                gradientStartOpacity: gradientStartOpacity,
                gradientEndOpacity: gradientEndOpacity,
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
               providerID == LiquidTuningProvider.providerID
    }

    private var showsLiquidSelection: Bool {
        materialStyle == .liquid
    }

    private var isLiquidTuningMode: Bool {
        if case .prefixed(let providerID) = viewModel.searchState.scope {
            return providerID == LiquidTuningProvider.providerID
        }
        return false
    }

    private var selectedGlassTint: NSColor? {
        let base = NSColor(Color.accentColor)
        let baseAlpha: CGFloat = glassStyle == .clear ? 0.18 : 0.24
        return base.withAlphaComponent(baseAlpha)
    }

    @ViewBuilder
    private func selectionBackgroundLayer(for anchor: Anchor<CGRect>?) -> some View {
        if showsLiquidSelection, let anchor {
            GeometryReader { proxy in
                let rect = proxy[anchor]
                LiquidGlassRowBackground(
                    cornerRadius: rowCornerRadius,
                    glassStyle: glassStyle,
                    glassTint: selectedGlassTint
                )
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .animation(.easeInOut(duration: animationDuration), value: rect)
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
                viewModel.prepareSettings(tab: .clipboard)
            })
            .help("设置")
        } else {
            Button {
                viewModel.openSettings(tab: .clipboard)
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
    let blurRadius: Double
    let extraBlurMaterial: AppearancePreferences.ExtraBlurMaterial
    let gradientStartOpacity: Double
    let gradientEndOpacity: Double
    let animationDuration: Double

    var body: some View {
        ZStack {
            backgroundBase
            highlightOverlay
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // 边框已移除，可以在设置中重新启用
        .animation(.easeInOut(duration: animationDuration), value: isHighlighted)
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
            if glassStyle == .clear {
                VisualEffectView(
                    material: extraBlurMaterial.material,
                    blendingMode: .behindWindow,
                    state: .active
                )
                .opacity(extraBlurOpacity)
            }
        case .pure:
            Color(nsColor: .windowBackgroundColor)
        }
    }

    @ViewBuilder
    private var highlightOverlay: some View {
        if style == .liquid {
            ZStack {
                Color.white.opacity(0.04)
                LinearGradient(
                    colors: [
                        Color.white.opacity(isHighlighted ? gradientStartOpacity : 0.22),
                        Color.white.opacity(isHighlighted ? gradientEndOpacity : 0.04),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.screen)
            }
        }
    }

    private var glassMaterial: NSVisualEffectView.Material {
        if #available(macOS 26, *) {
            return .hudWindow
        }
        if #available(macOS 13, *) {
            return .popover
        }
        return .hudWindow
    }

    private var extraBlurOpacity: Double {
        guard blurRadius > 0 else { return 0 }
        return min(1.0, blurRadius / 100.0)
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

private func rgbaString(from color: Color) -> String {
    let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.white
    return String(format: "%.3f,%.3f,%.3f,%.3f",
                  nsColor.redComponent,
                  nsColor.greenComponent,
                  nsColor.blueComponent,
                  nsColor.alphaComponent)
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
    @AppStorage(AppearancePreferences.materialStyleKey)
    private var materialStyleRaw = AppearancePreferences.MaterialStyle.liquid.rawValue
    @AppStorage(AppearancePreferences.glassStyleKey)
    private var glassStyleRaw = AppearancePreferences.GlassStyle.regular.rawValue
    @AppStorage(AppearancePreferences.glassTintKey)
    private var glassTintRaw = ""
    @AppStorage(AppearancePreferences.liquidGlassExtraBlurMaterialKey)
    private var extraBlurMaterialRaw = AppearancePreferences.ExtraBlurMaterial.system.rawValue
    
    // Liquid Glass 微调参数（候选项也使用）
    @AppStorage(AppearancePreferences.liquidGlassCornerRadiusKey)
    private var cornerRadius = 16.0
    @AppStorage(AppearancePreferences.liquidGlassAnimationDurationKey)
    private var animationDuration = 0.18

    private var isLiquidClear: Bool {
        let material = AppearancePreferences.MaterialStyle(rawValue: materialStyleRaw) ?? .liquid
        let glass = AppearancePreferences.GlassStyle(rawValue: glassStyleRaw) ?? .regular
        return material == .liquid && glass == .clear
    }

    private var materialStyle: AppearancePreferences.MaterialStyle {
        AppearancePreferences.MaterialStyle(rawValue: materialStyleRaw) ?? .liquid
    }

    private var glassStyle: AppearancePreferences.GlassStyle {
        AppearancePreferences.GlassStyle(rawValue: glassStyleRaw) ?? .regular
    }

    private var extraBlurMaterial: AppearancePreferences.ExtraBlurMaterial {
        AppearancePreferences.ExtraBlurMaterial(rawValue: extraBlurMaterialRaw) ?? .system
    }

    private var glassTint: NSColor? {
        colorFromRGBA(glassTintRaw)
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
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectionFillColor)
                if isHovered && !isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(hoverFillColor)
                }
            }
        }
        .overlay(alignment: .trailing) {
            actionHint
                .padding(.trailing, 10)
        }
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
        } else if item.providerID == AppSearchProvider.providerID {
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
                    material: .popover,
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

    @State private var glassStyleRaw = AppearancePreferences.glassStyle.rawValue
    @State private var glassTintRaw = AppearancePreferences.glassTint
    @State private var cornerRadius = AppearancePreferences.liquidGlassCornerRadius
    @State private var blurRadius = AppearancePreferences.liquidGlassBlurRadius
    @State private var extraBlurMaterialRaw = AppearancePreferences.liquidGlassExtraBlurMaterial.rawValue
    @State private var gradientStartOpacity = AppearancePreferences.liquidGlassGradientStartOpacity
    @State private var gradientEndOpacity = AppearancePreferences.liquidGlassGradientEndOpacity
    @State private var animationDuration = AppearancePreferences.liquidGlassAnimationDuration

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(group.title)
                .font(.system(size: 16, weight: .semibold))
            Text(group.subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Divider()

            groupContent
            Spacer()
        }
        .padding(8)
    }

    @ViewBuilder
    private var groupContent: some View {
        switch group {
        case .base:
            baseControls
        case .gradient:
            gradientControls
        case .blur:
            blurControls
        case .animation:
            animationControls
        }
    }

    private var baseControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("玻璃风格", selection: Binding(
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

            HStack(spacing: 12) {
                Toggle("色调", isOn: tintEnabledBinding)
                ColorPicker(
                    "",
                    selection: Binding(
                        get: { colorFromRGBA(glassTintRaw).map { Color(nsColor: $0) } ?? .white.opacity(0.2) },
                        set: { newValue in
                            glassTintRaw = rgbaString(from: newValue)
                            AppearancePreferences.glassTint = glassTintRaw
                        }
                    ),
                    supportsOpacity: true
                )
                .labelsHidden()
                .disabled(!tintEnabledBinding.wrappedValue)
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

    private var gradientControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            TuningSlider(
                title: "渐变起始透明度",
                value: debouncedBinding(
                    state: $gradientStartOpacity,
                    key: "gradientStartOpacity",
                    apply: { AppearancePreferences.liquidGlassGradientStartOpacity = $0 }
                ),
                range: 0...1,
                step: 0.01,
                unit: ""
            )
            TuningSlider(
                title: "渐变结束透明度",
                value: debouncedBinding(
                    state: $gradientEndOpacity,
                    key: "gradientEndOpacity",
                    apply: { AppearancePreferences.liquidGlassGradientEndOpacity = $0 }
                ),
                range: 0...1,
                step: 0.01,
                unit: ""
            )
            // 高光强度字段未在渲染中使用，暂不暴露控件
        }
    }

    private var blurControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            TuningSlider(
                title: "额外模糊强度",
                value: debouncedBinding(
                    state: $blurRadius,
                    key: "blurRadius",
                    apply: { AppearancePreferences.liquidGlassBlurRadius = $0 }
                ),
                range: 0...100,
                step: 1,
                unit: "%"
            )
            Picker("模糊材质", selection: Binding(
                get: { extraBlurMaterialRaw },
                set: { newValue in
                    extraBlurMaterialRaw = newValue
                    if let material = AppearancePreferences.ExtraBlurMaterial(rawValue: newValue) {
                        AppearancePreferences.liquidGlassExtraBlurMaterial = material
                    }
                }
            )) {
                Text("系统").tag(AppearancePreferences.ExtraBlurMaterial.system.rawValue)
                Text("超薄").tag(AppearancePreferences.ExtraBlurMaterial.ultraThin.rawValue)
                Text("薄").tag(AppearancePreferences.ExtraBlurMaterial.thin.rawValue)
                Text("常规").tag(AppearancePreferences.ExtraBlurMaterial.regular.rawValue)
                Text("厚").tag(AppearancePreferences.ExtraBlurMaterial.thick.rawValue)
                Text("超厚").tag(AppearancePreferences.ExtraBlurMaterial.ultraThick.rawValue)
            }
            .pickerStyle(.segmented)
        }
    }

    private var animationControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            TuningSlider(
                title: "候选项过渡动画时长",
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

    private var tintEnabledBinding: Binding<Bool> {
        Binding(
            get: { !glassTintRaw.isEmpty },
            set: { newValue in
                if newValue, glassTintRaw.isEmpty {
                    glassTintRaw = rgbaString(from: .white.opacity(0.2))
                }
                if !newValue {
                    glassTintRaw = ""
                }
                AppearancePreferences.glassTint = glassTintRaw
            }
        )
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
        case LiquidTuningGroup.base.title:
            return .base
        case LiquidTuningGroup.gradient.title:
            return .gradient
        case LiquidTuningGroup.blur.title:
            return .blur
        case LiquidTuningGroup.animation.title:
            return .animation
        default:
            return .base
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
        } else if item.providerID == LiquidTuningProvider.providerID {
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
