import SwiftUI
import DomainKit
import DesignSystem
import Platform

public struct CourseDetailView: View {
    @State private var viewModel: CourseDetailViewModel
    @State private var showReportSheet = false
    @State private var selectedReviewId: Int?
    @State private var reviewIdPendingHide: Int?
    @State private var reportMessage: String?

    public init(courseId: Int) {
        self._viewModel = State(initialValue: CourseDetailViewModel(courseId: courseId))
    }

    public var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView(message: "加载课程详情...")
            } else if let error = viewModel.error {
                ErrorStateView(
                    message: error,
                    retryTitle: "重试",
                    retryAction: { Task { await viewModel.refresh() } }
                )
            } else if let detail = viewModel.courseDetail {
                content(detail: detail)
            }
        }
        .navigationTitle(viewModel.courseDetail?.name ?? "课程详情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .sheet(isPresented: $showReportSheet) {
            reportSheet
        }
        .confirmationDialog(
            "隐藏这条评价？",
            isPresented: .init(
                get: { reviewIdPendingHide != nil },
                set: { if !$0 { reviewIdPendingHide = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("隐藏", role: .destructive) {
                if let reviewId = reviewIdPendingHide {
                    viewModel.hideReview(reviewId: reviewId)
                }
                reviewIdPendingHide = nil
            }
            Button("取消", role: .cancel) {
                reviewIdPendingHide = nil
            }
        } message: {
            Text("隐藏后这条评价不会再显示在本机。")
        }
        .alert("举报成功", isPresented: .init(
            get: { reportMessage != nil },
            set: { if !$0 { reportMessage = nil } }
        )) {
            Button("好", role: .cancel) { reportMessage = nil }
        } message: {
            Text(reportMessage ?? "")
        }
    }

    @ViewBuilder
    private func content(detail: CourseDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                courseHeader(detail)

                if !detail.semesters.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(detail.semesters, id: \.self) { semester in
                                SemesterTag(label: semester)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                let visibleReviews = viewModel.visibleReviews
                if visibleReviews.isEmpty {
                    EmptyStateView(
                        icon: "text.bubble",
                        message: detail.reviews.isEmpty ? "暂无评价" : "已隐藏所有评价"
                    )
                    .padding()
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("评价 (\(visibleReviews.count))")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(visibleReviews) { review in
                            ReviewCard(
                                review: review,
                                onLike: { Task { await viewModel.toggleLike(for: review.id) } },
                                onHide: {
                                    reviewIdPendingHide = review.id
                                },
                                onReport: {
                                    selectedReviewId = review.id
                                    showReportSheet = true
                                }
                            )
                        }
                    }
                }

                if let related = viewModel.relatedCourses {
                    relatedSection(related)
                }
            }
            .padding(.vertical)
        }
    }

    private func courseHeader(_ detail: CourseDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.name)
                        .font(.title2)
                        .bold()
                    Text("\(detail.code) · \(detail.teacherName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 2) {
                        RatingView(rating: detail.rating, size: 14)
                        Text(String(format: "%.1f", detail.rating))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(detail.reviewCount) 评价")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            HStack(spacing: 12) {
                Label(detail.department, systemImage: "building.columns")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if detail.credit > 0 {
                    Label("\(formattedCredit(detail.credit)) 学分", systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }

    private func relatedSection(_ related: RelatedCourses) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !related.teacherOtherCourses.isEmpty {
                Text("同教师其他课程")
                    .font(.headline)
                    .padding(.horizontal)
                ForEach(related.teacherOtherCourses, id: \.id) { course in
                    NavigationLink(destination: CourseDetailView(courseId: course.id)) {
                        CourseCard(
                            name: course.name,
                            code: course.code,
                            teacher: course.teacherName,
                            department: course.department,
                            rating: course.rating,
                            reviewCount: course.reviewCount,
                            credit: course.credit,
                            semesterTags: course.semesters
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }

            if !related.sameCourseOtherTeachers.isEmpty {
                Text("同课程其他教师")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)
                ForEach(related.sameCourseOtherTeachers, id: \.id) { course in
                    NavigationLink(destination: CourseDetailView(courseId: course.id)) {
                        CourseCard(
                            name: course.name,
                            code: course.code,
                            teacher: course.teacherName,
                            department: course.department,
                            rating: course.rating,
                            reviewCount: course.reviewCount,
                            credit: course.credit,
                            semesterTags: course.semesters
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
    }

    private var reportSheet: some View {
        NavigationStack {
            List {
                ForEach(ReportReason.allCases, id: \.self) { reason in
                    Button {
                        if let id = selectedReviewId {
                            Task {
                                let success = await viewModel.reportReview(reviewId: id, reason: reason)
                                if success {
                                    reportMessage = "感谢您的举报，我们会尽快处理。"
                                } else {
                                    reportMessage = "举报提交失败，请稍后再试。"
                                }
                                showReportSheet = false
                            }
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

    private func formattedCredit(_ credit: Double) -> String {
        if credit.rounded() == credit {
            return String(Int(credit))
        }
        return String(format: "%g", credit)
    }
}

// MARK: - Review Card Component

struct ReviewCard: View {
    let review: Review
    let onLike: () -> Void
    let onHide: () -> Void
    let onReport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let avatar = review.reviewerAvatar, let url = URL(string: avatar) {
                    AsyncAvatarView(url: url, name: review.reviewerName ?? "匿名")
                } else {
                    AsyncAvatarView(url: nil, name: review.reviewerName ?? "匿名")
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.reviewerName ?? "匿名用户")
                        .font(.subheadline.bold())
                    Text(review.semester)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                RatingView(rating: Double(review.rating), size: 12)
            }

            MarkdownContentView(review.comment)
                .font(.body)
                .lineLimit(nil)

            HStack {
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: review.liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.caption)
                        Text("\(review.likeCount)")
                            .font(.caption)
                    }
                    .foregroundStyle(review.liked ? .cyan : .secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onHide) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.slash")
                            .font(.caption)
                        Text("隐藏")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: onReport) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.bubble")
                            .font(.caption)
                        Text("举报")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - Previews

#Preview("CourseDetailView - Loading") {
    NavigationStack {
        CourseDetailView(courseId: 1)
    }
}

#Preview("ReviewCard") {
    ReviewCard(
        review: Review(
            id: 1,
            sqid: "abc123",
            courseId: 1,
            semester: "2024-2025-1",
            rating: 4,
            comment: "老师讲课**非常清晰**，板书工整。\n\n* 知识点覆盖全面\n* 作业量适中\n* 给分友好",
            createdAt: "2025-01-15T10:30:00Z",
            likeCount: 12,
            liked: false,
            reviewerName: "张同学",
            reviewerAvatar: nil
        ),
        onLike: {},
        onHide: {},
        onReport: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("ReviewCard - Liked") {
    ReviewCard(
        review: Review(
            id: 2,
            sqid: "def456",
            courseId: 1,
            semester: "2023-2024-2",
            rating: 5,
            comment: "非常好的课程！",
            createdAt: "2024-06-20T08:00:00Z",
            likeCount: 42,
            liked: true,
            reviewerName: "李同学",
            reviewerAvatar: "https://i.pravatar.cc/80?u=li"
        ),
        onLike: {},
        onHide: {},
        onReport: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
