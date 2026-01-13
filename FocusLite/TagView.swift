import SwiftUI

struct TagView: View {
    let title: String
    let subtitle: String?
    var useLiquidStyle: Bool = false
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(backgroundView)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if useLiquidStyle {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(tint.opacity(0.24))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
                )
        } else {
            Capsule()
                .fill(Color(nsColor: .controlAccentColor).opacity(0.15))
        }
    }
}
