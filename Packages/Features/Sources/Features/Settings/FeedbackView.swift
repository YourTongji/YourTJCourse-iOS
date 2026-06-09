import SwiftUI

// MARK: - Feedback View

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let url = URL(string: "https://xk.yourtj.de/feedback") {
                        Link(destination: url) {
                            feedbackLinkRow(
                                title: "打开反馈留言板",
                                subtitle: "使用 Web 端 Waline 留言系统提交反馈",
                                systemImage: "message"
                            )
                        }
                    }
                } footer: {
                    Text("留言板支持匿名昵称和 Markdown，内容会按 Web 端审核规则处理。")
                }

                Section {
                    if let url = URL(string: "https://github.com/YourTongji/YourTJCourse-iOS/issues/new") {
                        Link(destination: url) {
                            feedbackLinkRow(
                                title: "提交 iOS Issue",
                                subtitle: "客户端崩溃、界面异常、功能建议",
                                systemImage: "iphone"
                            )
                        }
                    }

                    if let url = URL(string: "https://github.com/YourTongji/YourTJCourse-Serverless/issues/new") {
                        Link(destination: url) {
                            feedbackLinkRow(
                                title: "提交后端 / 数据 Issue",
                                subtitle: "课程数据、接口、Web 反馈系统问题",
                                systemImage: "server.rack"
                            )
                        }
                    }
                } footer: {
                    Text("需要跟踪处理进度的问题请优先使用 GitHub Issue。")
                }
            }
            .navigationTitle("反馈与建议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func feedbackLinkRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.cyan)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview("Feedback") {
    FeedbackView()
}
