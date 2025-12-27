import SwiftUI

struct UpdateSettingsView: View {
    @ObservedObject var updater: AppUpdater

    private var feedURL: String {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            Form {
                Section {
                    HStack {
                        Text("当前版本")
                        Spacer()
                        Text(updater.versionDescription)
                            .foregroundStyle(.secondary)
                    }

                    if !feedURL.isEmpty {
                        Text("更新源：\(feedURL)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button("Check for Updates…") {
                        updater.checkForUpdates()
                    }
                    Toggle(
                        "Automatically check for updates",
                        isOn: Binding(
                            get: { updater.automaticallyChecksForUpdates },
                            set: { updater.setAutomaticallyChecksForUpdates($0) }
                        )
                    )
                }

                Section {
                    Text("使用 Sparkle 2 从 GitHub Releases 获取更新。网络或 Feed 不可用时会显示错误提示，不会中断应用。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)
        }
        .padding(16)
        .frame(width: 520, height: 320)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("更新")
                .font(.system(size: 20, weight: .semibold))
            Text("通过 Sparkle 检查更新，并可选择自动检查。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
