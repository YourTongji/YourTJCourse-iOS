import SwiftUI
import DomainKit

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

#Preview("Announcements List") {
    AnnouncementsListView(announcements: [
        Announcement(id: "1", title: "系统维护通知", content: "教务系统将于 6 月 10 日凌晨进行维护。", createdAt: "2026-06-01"),
        Announcement(id: "2", title: "选课功能更新", content: "排课模拟器已新增学期切换功能。", createdAt: "2026-05-28"),
    ])
}

#Preview("Announcements Empty") {
    AnnouncementsListView(announcements: [])
}
