import SwiftUI
import DomainKit
import DesignSystem

public struct MyReviewDetailView: View {
    @State private var viewModel: MyReviewDetailViewModel
    @State private var showHideConfirmation = false
    @State private var showReportSheet = false

    public init(entry: MyReviewEntry) {
        self._viewModel = State(initialValue: MyReviewDetailViewModel(entry: entry))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                courseSummaryCard

                ReviewCard(
                    review: viewModel.entry.review,
                    canEdit: viewModel.entry.canEdit,
                    isLikeUpdating: viewModel.isLikeUpdating,
                    onLike: { Task { await viewModel.toggleLike() } },
                    onEdit: { viewModel.editingEntry = viewModel.entry },
                    onHide: { showHideConfirmation = true },
                    onReport: { showReportSheet = true }
                )

                recordCard
            }
            .padding(.vertical)
        }
        .navigationTitle("评价详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.reloadEntry() }
        .sheet(item: $viewModel.editingEntry) { entry in
            ReviewView(
                courseId: entry.courseId,
                existingReview: entry.review,
                localReviewEntry: entry,
                onCompletion: {
                    viewModel.reloadEntry()
                }
            )
        }
        .sheet(isPresented: $showReportSheet) {
            reportSheet
        }
        .confirmationDialog(
            "隐藏这条评价？",
            isPresented: $showHideConfirmation,
            titleVisibility: .visible
        ) {
            Button("隐藏", role: .destructive) {
                viewModel.hideReview()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("隐藏后这条评价不会再显示在本机课程详情页。")
        }
        .alert(viewModel.notice?.title ?? "提示", isPresented: .init(
            get: { viewModel.notice != nil },
            set: { if !$0 { viewModel.dismissNotice() } }
        )) {
            Button("好", role: .cancel) { viewModel.dismissNotice() }
        } message: {
            if let notice = viewModel.notice {
                Text(notice.message)
            }
        }
    }

    private var courseSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.entry.courseName)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            Text(courseSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                RatingView(rating: viewModel.entry.courseRating, size: 14)
                Text("\(viewModel.entry.reviewCount) 条评价")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                NavigationLink(value: CourseDetailDestination(courseId: viewModel.entry.courseId)) {
                    Label("打开课程", systemImage: "book.closed")
                        .font(.caption)
                }
            }
        }
        .cardStyle()
        .padding(.horizontal)
    }

    private var recordCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("发表时间", value: viewModel.entry.createdAt)
            LabeledContent("本机保存", value: viewModel.entry.savedAt)
        }
        .font(.caption)
        .cardStyle()
        .padding(.horizontal)
    }

    private var courseSubtitle: String {
        let code = viewModel.entry.courseCode.isEmpty ? "未知课程号" : viewModel.entry.courseCode
        let teacher = viewModel.entry.teacherName.isEmpty ? "未知教师" : viewModel.entry.teacherName
        return "\(code) · \(teacher)"
    }

    private var reportSheet: some View {
        NavigationStack {
            List {
                ForEach(ReportReason.allCases, id: \.self) { reason in
                    Button {
                        Task {
                            await viewModel.reportReview(reason: reason)
                            showReportSheet = false
                        }
                    } label: {
                        HStack {
                            Text(reasonLabel(for: reason))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("举报评价")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showReportSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func reasonLabel(for reason: ReportReason) -> String {
        switch reason {
        case .spam: return "垃圾广告"
        case .harassment: return "人身攻击"
        case .misinformation: return "不实信息"
        case .other: return "其他"
        }
    }
}
