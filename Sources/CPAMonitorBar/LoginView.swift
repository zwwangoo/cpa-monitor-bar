import SwiftUI

struct LoginView: View {
    let error: String?
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("需要管理员登录", systemImage: "lock")
                .font(.headline)
            Text("请在设置中填写管理员密码并应用，成功后会自动登录。")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let error {
                ErrorBanner(message: error, stale: false)
            }
            Button("打开设置…", action: onOpenSettings)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
    }
}
