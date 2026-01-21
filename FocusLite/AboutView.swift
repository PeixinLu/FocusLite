import SwiftUI

struct AboutView: View {
    @State private var didCopyGroupNumber = false

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
                Text("欢迎加入 QQ 反馈交流群，十分期待收到你的 使用反馈｜意见建议")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Button("复制qq群号码") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("1070327833", forType: .string)
                    didCopyGroupNumber = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        didCopyGroupNumber = false
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                if didCopyGroupNumber {
                    Text("复制成功")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
                Text("邮件联系：luhuijiao667@gmail.com")
                    .font(.system(size: 13))
                Link("我的其他产品（GitHub主页）", destination: URL(string: "https://github.com/PeixinLu")!)
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
