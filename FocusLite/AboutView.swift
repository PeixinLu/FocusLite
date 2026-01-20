import SwiftUI

struct AboutView: View {
    private var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (s?, b?):
            return "v\(s) (\(b))"
        case let (s?, nil):
            return "v\(s)"
        case let (nil, b?):
            return "Build \(b)"
        default:
            return "未知版本"
        }
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 10) {
                if let icon = NSImage(named: "AppIcon") {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .frame(width: 72, height: 72)
                        .cornerRadius(16)
                        .shadow(radius: 4, y: 2)
                }
                Text("FocusLite")
                    .font(.system(size: 24, weight: .bold))
                Text(versionString)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 14) {
                Link("GitHub 仓库", destination: URL(string: "https://github.com/PeixinLu/FocusLite")!)
                    .font(.system(size: 14, weight: .semibold))
                Text("欢迎提供使用反馈 / 意见建议")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("QQ 反馈群：1070327833")
                    .font(.system(size: 14, weight: .semibold))
                Text("邮件联系：luhuijiao667@gmail.com")
                    .font(.system(size: 13))
                Link("我的其他产品", destination: URL(string: "https://github.com/PeixinLu")!)
                    .font(.system(size: 13))
            }
            .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.vertical, 30)
    }
}
