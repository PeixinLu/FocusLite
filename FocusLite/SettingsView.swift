import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general
    case apps
    case clipboard
    case translate
    case snippets
    case quickDirectories
    case webSearch
    case permissions
    case updates
    case about

    var iconName: String {
        switch self {
        case .general:
            return "gearshape"
        case .quickDirectories:
            return "folder"
        case .webSearch:
            return "globe"
        case .updates:
            return "arrow.triangle.2.circlepath"
        case .clipboard:
            return "doc.on.clipboard"
        case .snippets:
            return "text.append"
        case .translate:
            return "translate"
        case .apps:
            return "square.grid.2x2"
        case .permissions:
            return "lock.shield"
        case .about:
            return "info.circle"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "设置启动行为与唤起快捷键"
        case .quickDirectories:
            return "管理常用目录与别名"
        case .webSearch:
            return "配置默认浏览器搜索"
        case .updates:
            return "检查并获取最新版本"
        case .clipboard:
            return "管理剪贴板记录与过滤规则"
        case .snippets:
            return "维护文本片段与快捷填充"
        case .translate:
            return "配置翻译服务与前缀"
        case .apps:
            return "管理应用索引与搜索"
        case .permissions:
            return "查看系统权限状态"
        case .about:
            return "版本信息与反馈渠道"
        }
    }
}

enum SettingsLayout {
    static let horizontalPadding: CGFloat = 16
    static let topPadding: CGFloat = 6
    static let bottomPadding: CGFloat = 6
    static let sectionSpacing: CGFloat = 10
    static let headerBottomPadding: CGFloat = 4
    static let labelWidth: CGFloat = 96
    static let sidebarWidth: CGFloat = 220
    static let windowWidth: CGFloat = 900
    static let windowHeight: CGFloat = 620
}

extension SettingsTab {
    var title: String {
        switch self {
        case .general:
            return "通用"
        case .apps:
            return "应用搜索"
        case .clipboard:
            return "剪贴板历史"
        case .translate:
            return "快捷翻译"
        case .snippets:
            return "文本片段"
        case .quickDirectories:
            return "快捷目录"
        case .webSearch:
            return "网页搜索"
        case .permissions:
            return "权限"
        case .updates:
            return "更新"
        case .about:
            return "关于"
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String?
    let note: String?
    @ViewBuilder let content: () -> Content

    init(
        _ title: String? = nil,
        note: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.note = note
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }

            content()

            if let note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

struct SettingsFieldRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .frame(width: SettingsLayout.labelWidth, alignment: .leading)
                .foregroundColor(.secondary)
            content()
            Spacer(minLength: 0)
        }
    }
}

final class SettingsViewModel: ObservableObject {
    @Published var selectedTab: SettingsTab
    @Published var isShowingSaved = false
    let generalViewModel: GeneralSettingsViewModel
    let quickDirectoryViewModel: QuickDirectorySettingsViewModel
    let webSearchViewModel: WebSearchSettingsViewModel
    let appUpdater: AppUpdater
    let clipboardViewModel: ClipboardSettingsViewModel
    let snippetsViewModel: SnippetsManagerViewModel
    let translateViewModel: TranslateSettingsViewModel
    let onShowOnboarding: () -> Void
    let isOnboardingPresented: () -> Bool

    init(
        selectedTab: SettingsTab = .general,
        generalViewModel: GeneralSettingsViewModel,
        quickDirectoryViewModel: QuickDirectorySettingsViewModel,
        webSearchViewModel: WebSearchSettingsViewModel,
        appUpdater: AppUpdater,
        clipboardViewModel: ClipboardSettingsViewModel,
        snippetsViewModel: SnippetsManagerViewModel,
        translateViewModel: TranslateSettingsViewModel,
        onShowOnboarding: @escaping () -> Void,
        isOnboardingPresented: @escaping () -> Bool
    ) {
        self.selectedTab = selectedTab
        self.generalViewModel = generalViewModel
        self.quickDirectoryViewModel = quickDirectoryViewModel
        self.webSearchViewModel = webSearchViewModel
        self.appUpdater = appUpdater
        self.clipboardViewModel = clipboardViewModel
        self.snippetsViewModel = snippetsViewModel
        self.translateViewModel = translateViewModel
        self.onShowOnboarding = onShowOnboarding
        self.isOnboardingPresented = isOnboardingPresented
    }

    func markSaved() {
        isShowingSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.isShowingSaved = false
        }
    }
}

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var escMonitor: Any?
    @State private var settingsWindow: NSWindow?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                Divider()
                contentColumn
            }
        }
        .frame(width: SettingsLayout.windowWidth, height: SettingsLayout.windowHeight)
        .background(KeyboardTabSwitcher(
            selectedTab: $viewModel.selectedTab,
            onboardingIsPresented: viewModel.isOnboardingPresented
        ))
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                settingsWindow = NSApp.keyWindow
                settingsWindow?.collectionBehavior.insert(.moveToActiveSpace)
            }
            startEscMonitorIfNeeded()
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
            stopEscMonitor()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button {
                    viewModel.selectedTab = tab
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 20)
                        Text(tab.title)
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .frame(width: SettingsLayout.sidebarWidth, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if viewModel.selectedTab == .apps {
                // 应用设置页面不使用 ScrollView，让表格自己处理滚动
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    contentView
                        .padding(.horizontal, SettingsLayout.horizontalPadding + 4)
                        .padding(.vertical, SettingsLayout.topPadding + 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedTab.title)
                    .font(.system(size: 20, weight: .semibold))
                Text(viewModel.selectedTab.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if viewModel.selectedTab == .updates {
                Button("检查更新…") {
                    viewModel.appUpdater.checkForUpdates()
                }
            } else if viewModel.selectedTab == .permissions {
                // 刷新权限
                Button("刷新") {
                    NotificationCenter.default.post(name: .permissionsShouldRefresh, object: nil)
                }
            }
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding + 4)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.selectedTab {
        case .general:
            GeneralSettingsView(
                viewModel: viewModel.generalViewModel,
                onSaved: viewModel.markSaved,
                onShowOnboarding: viewModel.onShowOnboarding
            )
        case .apps:
            AppIndexSettingsView(viewModel: AppIndexSettingsViewModel())
        case .translate:
            TranslateSettingsView(viewModel: viewModel.translateViewModel, onSaved: viewModel.markSaved)
        case .clipboard:
            ClipboardSettingsView(viewModel: viewModel.clipboardViewModel, onSaved: viewModel.markSaved)
        case .snippets:
            SnippetsManagerView(viewModel: viewModel.snippetsViewModel, onSaved: viewModel.markSaved)
        case .quickDirectories:
            QuickDirectorySettingsView(viewModel: viewModel.quickDirectoryViewModel, onSaved: viewModel.markSaved)
        case .webSearch:
            WebSearchSettingsView(viewModel: viewModel.webSearchViewModel, onSaved: viewModel.markSaved)
        case .permissions:
            PermissionSettingsView()
        case .updates:
            UpdateSettingsView(updater: viewModel.appUpdater, onSaved: viewModel.markSaved)
        case .about:
            AboutView()
        }
    }

    private func startEscMonitorIfNeeded() {
        guard escMonitor == nil else { return }
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard settingsWindow?.isKeyWindow == true else { return event }
            if event.keyCode == 53 {
                settingsWindow?.performClose(nil)
                return nil
            }
            return event
        }
    }

    private func stopEscMonitor() {
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
        settingsWindow = nil
    }
}

private struct KeyboardTabSwitcher: NSViewRepresentable {
    @Binding var selectedTab: SettingsTab
    var onboardingIsPresented: (() -> Bool)?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let window = view.window, window.isKeyWindow else { return event }
            if context.coordinator.onboardingIsPresented?() == true {
                // 避免拦截 Onboarding 的按键
                return event
            }
            switch event.keyCode {
            case 125: // down arrow
                select(offset: 1)
                return nil
            case 126: // up arrow
                select(offset: -1)
                return nil
            default:
                return event
            }
        }
        context.coordinator.monitor = monitor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func select(offset: Int) {
        let tabs = SettingsTab.allCases
        guard let currentIndex = tabs.firstIndex(of: selectedTab) else { return }
        let next = max(0, min(currentIndex + offset, tabs.count - 1))
        selectedTab = tabs[next]
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onboardingIsPresented: onboardingIsPresented)
    }

    final class Coordinator {
        var monitor: Any?
        var onboardingIsPresented: (() -> Bool)?

        init(onboardingIsPresented: (() -> Bool)? = nil) {
            self.onboardingIsPresented = onboardingIsPresented
        }
    }
}
