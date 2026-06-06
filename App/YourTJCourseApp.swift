import SwiftUI
import Features
import DomainKit
import DataKit

// MARK: - Announcement Read Store

/// Persists the last-read announcement ID so we only show new announcements once.
struct AnnouncementReadStore {
    private let key = "com.yourtj.course.lastReadAnnouncementId"

    var lastReadId: String? {
        UserDefaults.standard.string(forKey: key)
    }

    func markRead(_ id: String) {
        UserDefaults.standard.set(id, forKey: key)
    }

    func hasUnread(_ announcements: [Announcement]) -> Bool {
        guard let latestId = announcements.first?.id else { return false }
        return lastReadId != latestId
    }
}

// MARK: - App Entry Point

@main
struct YourTJCourseApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @State private var startupFinished = false

    var body: some View {
        Group {
            if startupFinished {
                MainTabView()
                    .transition(.opacity)
            } else {
                StartupGateView(onComplete: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        startupFinished = true
                    }
                })
                .transition(.opacity)
            }
        }
        .animation(.default, value: startupFinished)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var latestAnnouncement: Announcement?

    var body: some View {
        TabView {
            CatalogView()
                .tabItem {
                    Label("课程", systemImage: "book.closed")
                }

            SchedulerStubView()
                .tabItem {
                    Label("排课", systemImage: "calendar")
                }

            WalletView()
                .tabItem {
                    Label("我的", systemImage: "wallet.pass")
                }

            SettingsView()
                .tabItem {
                    Label("更多", systemImage: "ellipsis")
                }
        }
        .task {
            await checkAnnouncements()
        }
        .sheet(item: $latestAnnouncement) { announcement in
            NavigationStack {
                VStack(spacing: 16) {
                    Text(announcement.title)
                        .font(.title2).bold()
                        .multilineTextAlignment(.center)

                    ScrollView {
                        Text(announcement.content)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button("我已知晓") {
                        markRead(announcement.id)
                        latestAnnouncement = nil
                    }
                    .buttonStyle(.glassProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .navigationTitle("公告")
                .navigationBarTitleDisplayMode(.inline)
            }
            .interactiveDismissDisabled()
        }
    }

    func checkAnnouncements() async {
        let repo = SettingsRepository()
        guard let state = try? await repo.getRuntimeState() else { return }
        let announcements = state.announcements
        guard let latest = announcements.first else { return }

        let store = AnnouncementReadStore()
        if store.hasUnread(announcements) {
            latestAnnouncement = latest
        }
    }

    func markRead(_ id: String) {
        let store = AnnouncementReadStore()
        store.markRead(id)
    }
}

// MARK: - Preview

#Preview {
    RootView()
}
