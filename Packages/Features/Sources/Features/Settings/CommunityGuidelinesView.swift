import SwiftUI

// MARK: - Community Guidelines

struct CommunityGuidelinesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("社区规范")
                        .font(.title)
                        .bold()

                    VStack(alignment: .leading, spacing: 12) {
                        GuidelineRow(icon: "heart", text: "尊重他人，不进行人身攻击")
                        GuidelineRow(icon: "checkmark.seal", text: "评价内容应真实、客观、有帮助")
                        GuidelineRow(icon: "exclamationmark.bubble", text: "禁止发布虚假信息或恶意差评")
                        GuidelineRow(icon: "megaphone", text: "禁止垃圾广告和刷屏行为")
                        GuidelineRow(icon: "lock.shield", text: "保护个人隐私，不泄露他人信息")
                        GuidelineRow(icon: "flag", text: "发现违规内容请使用举报功能")
                    }

                    Text("违规处理")
                        .font(.headline)
                        .padding(.top)

                    Text("违反社区规范的内容可能会被隐藏或删除，多次违规可能导致账号功能受限。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("社区规范")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

#Preview("Community Guidelines") {
    CommunityGuidelinesView()
}
