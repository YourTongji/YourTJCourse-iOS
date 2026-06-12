import SwiftUI
import DomainKit
import DesignSystem
import Platform

// MARK: - SettingsView

public struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @AppStorage(AppAppearancePreference.storageKey) private var appearancePreferenceRawValue =
        AppAppearancePreference.system.rawValue

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

                // Content Section
                Section("内容") {
                    Button(action: { viewModel.showMyReviews = true }) {
                        HStack {
                            Label("我的评价", systemImage: "text.bubble")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AppearanceMenuButton(selectionRawValue: $appearancePreferenceRawValue)
                }
            }
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
            .sheet(isPresented: $viewModel.showMyReviews) {
                MyReviewsView()
            }
        }
    }
}

#Preview("SettingsView") {
    SettingsView()
}
