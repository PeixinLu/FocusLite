import SwiftUI

enum SettingsTab: String, CaseIterable {
    case clipboard
    case snippets
    case translate
}

final class SettingsViewModel: ObservableObject {
    @Published var selectedTab: SettingsTab
    let clipboardViewModel: ClipboardSettingsViewModel
    let snippetsViewModel: SnippetsManagerViewModel
    let translateViewModel: TranslateSettingsViewModel

    init(
        selectedTab: SettingsTab = .clipboard,
        clipboardViewModel: ClipboardSettingsViewModel,
        snippetsViewModel: SnippetsManagerViewModel,
        translateViewModel: TranslateSettingsViewModel
    ) {
        self.selectedTab = selectedTab
        self.clipboardViewModel = clipboardViewModel
        self.snippetsViewModel = snippetsViewModel
        self.translateViewModel = translateViewModel
    }
}

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            ClipboardSettingsView(viewModel: viewModel.clipboardViewModel)
                .tag(SettingsTab.clipboard)
                .tabItem { Text("剪贴板") }

            SnippetsManagerView(viewModel: viewModel.snippetsViewModel)
                .tag(SettingsTab.snippets)
                .tabItem { Text("片段") }

            TranslateSettingsView(viewModel: viewModel.translateViewModel)
                .tag(SettingsTab.translate)
                .tabItem { Text("翻译") }
        }
        .padding(8)
        .frame(width: 720, height: 680)
    }
}
