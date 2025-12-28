import SwiftUI

struct UpdateSettingsView: View {
    @ObservedObject var updater: AppUpdater
    let onSaved: (() -> Void)?

    init(updater: AppUpdater, onSaved: (() -> Void)? = nil) {
        self._updater = ObservedObject(wrappedValue: updater)
        self.onSaved = onSaved
    }

    private var feedURL: String {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            header
                .padding(.bottom, SettingsLayout.headerBottomPadding)

            VStack(spacing: SettingsLayout.sectionSpacing) {
                SettingsSection {
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

                SettingsSection {
                    Toggle(
                        "Automatically check for updates",
                        isOn: Binding(
                            get: { updater.automaticallyChecksForUpdates },
                            set: { newValue in
                                updater.setAutomaticallyChecksForUpdates(newValue)
                                onSaved?()
                            }
                        )
                    )
                    .toggleStyle(.switch)
                }
            }
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding)
        .padding(.top, SettingsLayout.topPadding)
        .padding(.bottom, SettingsLayout.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("更新")
                    .font(.system(size: 20, weight: .semibold))
                Text("获取 app 最新版本。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Check for Updates…") {
                updater.checkForUpdates()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
