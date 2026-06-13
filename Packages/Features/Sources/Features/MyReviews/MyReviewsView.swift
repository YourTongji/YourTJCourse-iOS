import SwiftUI
import DomainKit
import DesignSystem

public struct MyReviewsView: View {
    @State private var viewModel = MyReviewsViewModel()
    private let onSelectReview: (MyReviewEntry) -> Void

    public init(onSelectReview: @escaping (MyReviewEntry) -> Void = { _ in }) {
        self.onSelectReview = onSelectReview
    }

    public var body: some View {
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
                    message: "还没有在本机写过点评"
                )
            } else {
                List {
                    ForEach(viewModel.entries) { entry in
                        HStack(alignment: .center, spacing: 12) {
                            Button {
                                onSelectReview(entry)
                            } label: {
                                ReviewEntryRow(entry: entry)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if entry.canEdit {
                                Button("编辑") {
                                    viewModel.editingEntry = entry
                                }
                                .font(.caption)
                                .foregroundStyle(AppColors.cyan)
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await viewModel.refresh() }
            }
        }
        .navigationTitle("我的评价")
        .sheet(item: $viewModel.editingEntry) { entry in
            ReviewView(
                courseId: entry.courseId,
                existingReview: entry.review,
                localReviewEntry: entry,
                onCompletion: {
                    viewModel.reloadFromLocalStore()
                }
            )
        }
        .onChange(of: viewModel.editingEntry) { _, newValue in
            if newValue == nil {
                Task { await viewModel.refresh() }
            }
        }
        .task { await viewModel.loadMyReviews() }
        .onAppear {
            if !viewModel.isLoading {
                viewModel.reloadFromLocalStore()
            }
        }
    }
}

private struct ReviewEntryRow: View {
    let entry: MyReviewEntry

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
                Text(commentPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
            }

            Text(entry.createdAt)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var commentPreview: String {
        guard !entry.comment.isEmpty else { return "" }

        let preview = String(entry.comment.prefix(60))
        return entry.comment.count > 60 ? "\(preview)…" : preview
    }
}
