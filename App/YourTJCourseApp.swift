import SwiftUI
import Features

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
    }
}

// MARK: - Preview

#Preview {
    RootView()
}
