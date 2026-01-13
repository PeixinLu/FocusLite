import Cocoa
import Foundation
import Sparkle

@MainActor
final class AppUpdater: NSObject, ObservableObject {
    static let shared = AppUpdater()
    private static let automaticChecksKey = "SUEnableAutomaticChecks"

    private lazy var updaterController: SPUStandardUpdaterController = {
        SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }()
    @Published var automaticallyChecksForUpdates: Bool
    let versionDescription: String

    private override init() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        versionDescription = "版本 \(version)（\(build)）"
        UserDefaults.standard.register(defaults: [Self.automaticChecksKey: false])
        automaticallyChecksForUpdates = false

        super.init()
        automaticallyChecksForUpdates = updaterController.updater.automaticallyChecksForUpdates
        updaterController.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ isOn: Bool) {
        automaticallyChecksForUpdates = isOn
        updaterController.updater.automaticallyChecksForUpdates = isOn
        UserDefaults.standard.set(isOn, forKey: Self.automaticChecksKey)
    }
}

extension AppUpdater: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == "SUSparkleErrorDomain",
           nsError.localizedDescription.localizedCaseInsensitiveContains("up to date") {
            // Sparkle already shows the "up to date" dialog.
            return
        }
        let alert = NSAlert()
        alert.messageText = "无法检查更新"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }
}
