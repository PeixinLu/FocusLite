import ApplicationServices
import SwiftUI

enum PermissionType: CaseIterable, Identifiable {
    case accessibility

    var id: String { key }

    var key: String {
        switch self {
        case .accessibility: return "accessibility"
        }
    }

    var title: String {
        switch self {
        case .accessibility: return "辅助功能"
        }
    }

    var description: String {
        switch self {
        case .accessibility: return "用于自动粘贴功能，需允许 FocusLite 控制您的 Mac。"
        }
    }

    var iconName: String {
        switch self {
        case .accessibility: return "accessibility"
        }
    }

    var settingsURL: URL? {
        switch self {
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        }
    }
}

enum PermissionStatus {
    case granted
    case denied

    var tint: Color {
        switch self {
        case .granted: return .green
        case .denied: return .orange
        }
    }
}

struct PermissionItem: Identifiable {
    let id: String
    let type: PermissionType
    var status: PermissionStatus
}

enum PermissionsChecker {
    static func status(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .accessibility:
            return AXIsProcessTrusted() ? .granted : .denied
        }
    }

    static func openSettings(for type: PermissionType) {
        guard let url = type.settingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    static func request(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .accessibility:
            let granted = AccessibilityPermission.requestIfNeeded()
            if granted { return .granted }
            openSettings(for: type)
            return .denied
        }
    }
}

struct PermissionSettingsView: View {
    @State private var items: [PermissionItem] = []
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            SettingsSection {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items) { item in
                        PermissionRow(item: item, onRequest: {
                            let newStatus = PermissionsChecker.request(for: item.type)
                            if let index = items.firstIndex(where: { $0.id == item.id }) {
                                items[index].status = newStatus
                            }
                        })
                    }
                }
            }
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding)
        .padding(.top, SettingsLayout.topPadding)
        .padding(.bottom, SettingsLayout.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .permissionsShouldRefresh)) { _ in
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                refresh()
            }
        }
    }

    private func refresh() {
        items = PermissionType.allCases.map { type in
            PermissionItem(
                id: type.id,
                type: type,
                status: PermissionsChecker.status(for: type)
            )
        }
    }
}

private struct PermissionRow: View {
    let item: PermissionItem
    let onRequest: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.type.iconName)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 28)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.type.title)
                        .font(.system(size: 14, weight: .semibold))
                    StatusBadge(status: item.status)
                }
                Text(item.type.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(item.status == .granted ? "打开系统设置" : "立即申请") {
                onRequest()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

private struct StatusBadge: View {
    let status: PermissionStatus

    var body: some View {
        Circle()
            .fill(status.tint)
            .frame(width: 10, height: 10)
    }
}
