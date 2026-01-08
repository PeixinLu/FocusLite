import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general
    case updates
    case clipboard
    case snippets
    case translate
    case appearance
    case apps

    var iconName: String {
        switch self {
        case .general:
            return "gearshape"
        case .updates:
            return "arrow.triangle.2.circlepath"
        case .clipboard:
            return "doc.on.clipboard"
        case .snippets:
            return "text.append"
        case .translate:
            return "character.bubble"
        case .appearance:
            return "paintbrush.pointed"
        case .apps:
            return "square.grid.2x2"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "设置启动行为与唤起快捷键"
        case .updates:
            return "检查并获取最新版本"
        case .clipboard:
            return "管理剪贴板记录与过滤规则"
        case .snippets:
            return "维护文本片段与快捷填充"
        case .translate:
            return "配置翻译服务与前缀"
        case .appearance:
            return "调整搜索面板材质"
        case .apps:
            return "管理应用索引与搜索"
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
        case .updates:
            return "更新"
        case .clipboard:
            return "剪贴板"
        case .snippets:
            return "文本片段"
        case .translate:
            return "翻译"
        case .appearance:
            return "外观"
        case .apps:
            return "应用"
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
    let appUpdater: AppUpdater
    let clipboardViewModel: ClipboardSettingsViewModel
    let snippetsViewModel: SnippetsManagerViewModel
    let translateViewModel: TranslateSettingsViewModel

    init(
        selectedTab: SettingsTab = .general,
        generalViewModel: GeneralSettingsViewModel,
        appUpdater: AppUpdater,
        clipboardViewModel: ClipboardSettingsViewModel,
        snippetsViewModel: SnippetsManagerViewModel,
        translateViewModel: TranslateSettingsViewModel
    ) {
        self.selectedTab = selectedTab
        self.generalViewModel = generalViewModel
        self.appUpdater = appUpdater
        self.clipboardViewModel = clipboardViewModel
        self.snippetsViewModel = snippetsViewModel
        self.translateViewModel = translateViewModel
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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                Divider()
                contentColumn
            }
        }
        .frame(width: SettingsLayout.windowWidth, height: SettingsLayout.windowHeight)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
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
            ScrollView {
                contentView
                    .padding(.horizontal, SettingsLayout.horizontalPadding + 4)
                    .padding(.vertical, SettingsLayout.topPadding + 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Button("Check for Updates…") {
                    viewModel.appUpdater.checkForUpdates()
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
            GeneralSettingsView(viewModel: viewModel.generalViewModel, onSaved: viewModel.markSaved)
        case .updates:
            UpdateSettingsView(updater: viewModel.appUpdater, onSaved: viewModel.markSaved)
        case .clipboard:
            ClipboardSettingsView(viewModel: viewModel.clipboardViewModel, onSaved: viewModel.markSaved)
        case .snippets:
            SnippetsManagerView(viewModel: viewModel.snippetsViewModel, onSaved: viewModel.markSaved)
        case .translate:
            TranslateSettingsView(viewModel: viewModel.translateViewModel, onSaved: viewModel.markSaved)
        case .appearance:
            AppearanceSettingsView()
        case .apps:
            AppIndexSettingsView(viewModel: AppIndexSettingsViewModel())
        }
    }
}
