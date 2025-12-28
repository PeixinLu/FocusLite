import SwiftUI

enum SettingsTab: String, CaseIterable {
    case updates
    case clipboard
    case snippets
    case translate
}

enum SettingsLayout {
    static let horizontalPadding: CGFloat = 16
    static let topPadding: CGFloat = 6
    static let bottomPadding: CGFloat = 6
    static let sectionSpacing: CGFloat = 10
    static let headerBottomPadding: CGFloat = 4
    static let labelWidth: CGFloat = 96
}

extension SettingsTab {
    var title: String {
        switch self {
        case .updates:
            return "更新"
        case .clipboard:
            return "剪贴板"
        case .snippets:
            return "文本片段"
        case .translate:
            return "翻译"
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
    let appUpdater: AppUpdater
    let clipboardViewModel: ClipboardSettingsViewModel
    let snippetsViewModel: SnippetsManagerViewModel
    let translateViewModel: TranslateSettingsViewModel

    init(
        selectedTab: SettingsTab = .clipboard,
        appUpdater: AppUpdater,
        clipboardViewModel: ClipboardSettingsViewModel,
        snippetsViewModel: SnippetsManagerViewModel,
        translateViewModel: TranslateSettingsViewModel
    ) {
        self.selectedTab = selectedTab
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
            tabBar
            contentView
        }
        .frame(minWidth: 600, minHeight: 520)
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.selectedTab {
        case .updates:
            UpdateSettingsView(updater: viewModel.appUpdater, onSaved: viewModel.markSaved)
        case .clipboard:
            ClipboardSettingsView(viewModel: viewModel.clipboardViewModel, onSaved: viewModel.markSaved)
        case .snippets:
            SnippetsManagerView(viewModel: viewModel.snippetsViewModel, onSaved: viewModel.markSaved)
        case .translate:
            TranslateSettingsView(viewModel: viewModel.translateViewModel, onSaved: viewModel.markSaved)
        }
    }

    private var tabBar: some View {
        HStack {
            Spacer()
            Picker("设置", selection: $viewModel.selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 340)
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .padding(.horizontal, SettingsLayout.horizontalPadding)
    }
}
