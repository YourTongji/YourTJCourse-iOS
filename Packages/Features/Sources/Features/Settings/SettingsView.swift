import SwiftUI
import DomainKit
import DesignSystem
import Platform

// MARK: - SettingsView

public struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Announcements Section
                Section {
                    Button(action: { viewModel.showAnnouncements = true }) {
                        HStack {
                            Label("公告", systemImage: "megaphone")
                            Spacer()
                            if !viewModel.announcements.isEmpty {
                                Text("\(viewModel.announcements.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.cyan.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Support Section
                Section("支持") {
                    Button(action: { viewModel.showFeedback = true }) {
                        HStack {
                            Label("反馈与建议", systemImage: "envelope")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if let serverlessURL = URL(string: "https://github.com/YourTongji/YourTJCourse-Serverless") {
                        Link(destination: serverlessURL) {
                            HStack {
                                Label("后端仓库", systemImage: "server.rack")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if let iosURL = URL(string: "https://github.com/YourTongji/YourTJCourse-iOS") {
                        Link(destination: iosURL) {
                            HStack {
                                Label("客户端仓库", systemImage: "iphone")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                }

                // Legal Section (App Store Compliance)
                Section("法律") {
                    Button(action: { viewModel.showEULA = true }) {
                        HStack {
                            Label("用户协议 (EULA)", systemImage: "doc.text")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Button(action: { viewModel.showCommunityGuidelines = true }) {
                        HStack {
                            Label("社区规范", systemImage: "shield")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // About
                Section("关于") {
                    Button(action: { viewModel.showAbout = true }) {
                        HStack {
                            Label("关于 YourTJ Course", systemImage: "info.circle")
                            Spacer()
                            Text(AppVersion.displayString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("更多")
            .task { await viewModel.loadAnnouncements() }
            .sheet(isPresented: $viewModel.showAnnouncements) {
                AnnouncementsListView(announcements: viewModel.announcements)
            }
            .sheet(isPresented: $viewModel.showEULA) {
                EULAView()
            }
            .sheet(isPresented: $viewModel.showCommunityGuidelines) {
                CommunityGuidelinesView()
            }
            .sheet(isPresented: $viewModel.showFeedback) {
                FeedbackView()
            }
            .sheet(isPresented: $viewModel.showAbout) {
                AboutView()
            }
        }
    }
}

// MARK: - Announcements List

struct AnnouncementsListView: View {
    let announcements: [Announcement]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if announcements.isEmpty {
                    ContentUnavailableView("暂无公告", systemImage: "megaphone", description: Text("目前没有新的公告"))
                } else {
                    List(announcements) { announcement in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(announcement.title)
                                .font(.headline)
                            if let date = announcement.createdAt {
                                Text(date)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(announcement.content)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("公告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

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

struct GuidelineRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.cyan)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

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

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.cyan)

                Text("YourTJ Course")
                    .font(.title)
                    .bold()

                Text("版本 \(AppVersion.displayString)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("同济大学选课社区 iOS 客户端")
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    if let serverlessURL = URL(string: "https://github.com/YourTongji/YourTJCourse-Serverless") {
                        Link("后端: YourTJCourse-Serverless", destination: serverlessURL)
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }
                    if let iosURL = URL(string: "https://github.com/YourTongji/YourTJCourse-iOS") {
                        Link("客户端: YourTJCourse-iOS", destination: iosURL)
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    Text("Built with SwiftUI + Liquid Glass")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("© 2026 YourTJ. All rights reserved.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
                    .frame(height: 32)
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("SettingsView") {
    SettingsView()
}

#Preview("Announcements List") {
    AnnouncementsListView(announcements: [
        Announcement(id: "1", title: "系统维护通知", content: "教务系统将于 6 月 10 日凌晨进行维护。", createdAt: "2026-06-01"),
        Announcement(id: "2", title: "选课功能更新", content: "排课模拟器已新增学期切换功能。", createdAt: "2026-05-28"),
    ])
}

#Preview("Announcements Empty") {
    AnnouncementsListView(announcements: [])
}

#Preview("EULA") {
    EULAView()
}

#Preview("Community Guidelines") {
    CommunityGuidelinesView()
}

#Preview("Guideline Row") {
    GuidelineRow(icon: "heart", text: "尊重他人")
}

#Preview("Feedback") {
    FeedbackView()
}

#Preview("About") {
    AboutView()
}
