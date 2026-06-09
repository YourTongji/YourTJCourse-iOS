import SwiftUI

// MARK: - EULA View

struct EULAView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("用户协议 (EULA)")
                            .font(.title)
                            .bold()

                        Text("最后更新：2026 年 6 月")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("""
                    1. 服务说明
                    YourTJ Course 是一个校园选课信息分享平台，为用户提供课程评价、排课模拟等功能。

                    2. 用户内容
                    用户在本平台发表的评价和内容（UGC）应遵守法律法规和社区规范。用户保留其内容的著作权，但授予平台非独占的展示权利。

                    3. 使用规则
                    用户不得发布虚假、违法、侵权、骚扰、垃圾广告等内容。平台有权删除违规内容。

                    4. 免责声明
                    平台信息仅供参考，课程数据来源于教务系统，平台不保证数据的绝对准确性。

                    5. 隐私
                    我们不会收集不必要的个人信息。学号、PIN 和助记词不会上传；用于积分服务的钱包签名密钥仅通过 Credit 注册/恢复流程使用，并保存在本机 Keychain。

                    6. 变更
                    本协议可能随时更新，重大变更将通过公告通知。
                    """)
                    .font(.body)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("用户协议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

#Preview("EULA") {
    EULAView()
}
