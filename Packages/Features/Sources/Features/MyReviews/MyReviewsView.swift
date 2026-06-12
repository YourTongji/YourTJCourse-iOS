import SwiftUI
import DataKit
import DomainKit
import DesignSystem

public struct MyReviewsView: View {
    @State private var viewModel = MyReviewsViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("加载中…")
                } else if let error = viewModel.error, viewModel.entries.isEmpty {
                    ErrorStateView(
                        message: error,
                        retryTitle: "重试",
                        retryAction: { Task { await viewModel.loadMyReviews() } }
                    )
                } else if viewModel.entries.isEmpty {
                    EmptyStateView(
                        icon: "text.bubble",
                        message: "你还没有发表过评价"
                    )
                } else {
                    List {
                        ForEach(viewModel.entries) { entry in
                            NavigationLink(value: CourseDetailDestination(courseId: entry.courseId)) {
                                ReviewEntryRow(entry: entry, onEdit: { viewModel.editingEntry = entry })
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await viewModel.refresh() }
                }
            }
            .navigationTitle("我的评价")
            .navigationDestination(for: CourseDetailDestination.self) { dest in
                CourseDetailView(courseId: dest.courseId, showsRelatedCourses: dest.loadsRelatedCourses)
            }
            .sheet(item: $viewModel.editingEntry) { entry in
                ReviewView(courseId: entry.courseId, existingReview: entry.review)
            }
            .onChange(of: viewModel.editingEntry) { _, newValue in
                if newValue == nil {
                    Task { await viewModel.refresh() }
                }
            }
            .task { await viewModel.loadMyReviews() }
        }
    }
}

private struct ReviewEntryRow: View {
    let entry: MyReviewEntry
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.courseName)
                    .font(.body.weight(.semibold))
                Text(entry.courseCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(entry.teacherName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                RatingView(rating: Double(entry.rating), size: 12)
                Text(entry.comment.isEmpty ? "" : String(entry.comment.prefix(60)) + (entry.comment.count > 60 ? "…" : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
            }

            HStack {
                Text(entry.createdAt)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                if entry.canEdit {
                    Button("编辑") { onEdit() }
                        .font(.caption)
                        .foregroundStyle(AppColors.cyan)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
