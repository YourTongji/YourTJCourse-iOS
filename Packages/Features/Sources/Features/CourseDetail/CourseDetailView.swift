import SwiftUI
import DomainKit
import DesignSystem
import Platform

// MARK: - Navigation Destination

/// Navigation value for pushing to course detail from related courses links.
public struct CourseDetailDestination: Hashable {
    public let courseId: Int
    public let loadsRelatedCourses: Bool

    public init(courseId: Int, loadsRelatedCourses: Bool = true) {
        self.courseId = courseId
        self.loadsRelatedCourses = loadsRelatedCourses
    }
}


public struct CourseDetailView: View {
    @State private var viewModel: CourseDetailViewModel
    @State private var showReportSheet = false
    @State private var selectedReviewId: Int?
    @State private var reviewIdPendingHide: Int?
    @State private var reportMessage: String?
    @State private var showReviewSheet = false
    @State private var reviewToEdit: Review?

    public init(courseId: Int, showsRelatedCourses: Bool = true) {
        self._viewModel = State(
            initialValue: CourseDetailViewModel(
                courseId: courseId,
                loadsRelatedCourses: showsRelatedCourses
            )
        )
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.toggleFavorite()
                } label: {
                    Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(viewModel.isFavorite ? .yellow : .primary)
                }
                .disabled(viewModel.courseDetail == nil)
                .accessibilityLabel(viewModel.isFavorite ? "取消收藏课程" : "收藏课程")
            }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showReportSheet) {
            reportSheet
        }
        .sheet(isPresented: $showReviewSheet) {
            ReviewView(courseId: viewModel.courseId, courseDetail: viewModel.courseDetail)
        }
        .sheet(item: $reviewToEdit) { review in
            ReviewView(
                courseId: viewModel.courseId,
                courseDetail: viewModel.courseDetail,
                existingReview: review
            )
        }
        .onChange(of: showReviewSheet) { _, isPresented in
            if !isPresented {
                Task { await viewModel.refresh() }
            }
        }
        .onChange(of: reviewToEdit) { _, review in
            if review == nil {
                Task { await viewModel.refresh() }
            }
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
#if os(iOS)
        .sheet(isPresented: Binding<Bool>(
            get: { viewModel.shareImage != nil },
            set: { if !$0 { viewModel.clearShareImage() } }
        )) {
            if let image = viewModel.shareImage {
                ShareSheet(items: [image])
            }
        }
#endif
    }

    @ViewBuilder
    private func content(detail: CourseDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                courseHeader(detail)

                // AI Summary Card
                aiSummaryCard

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

                HStack {
                    Spacer()
                    Button(action: { showReviewSheet = true }) {
                        AppActionButtonLabel("写评价", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(AppActionButtonStyle(role: .primary, fillsWidth: false))
                    .padding(.horizontal)
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
                                canEdit: review.canEdit,
                                isLikeUpdating: viewModel.togglingLikeReviewIds.contains(review.id),
                                onLike: { Task { await viewModel.toggleLike(for: review.id) } },
                                onEdit: {
                                    reviewToEdit = review
                                },
                                onHide: {
                                    reviewIdPendingHide = review.id
                                },
                                onReport: {
                                    selectedReviewId = review.id
                                    showReportSheet = true
                                },
                                onShare: shareAction(for: review)
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

    @ViewBuilder
    private var aiSummaryCard: some View {
        if !viewModel.isAiSummaryDismissed {
            if viewModel.isSummaryLoading {
                aiSummaryStatusCard(
                    message: "正在生成 AI 总结...",
                    icon: "sparkle.magnifyingglass",
                    isLoading: true
                )
            } else if let summary = viewModel.aiSummary, summary.hasContent {
                aiSummaryContentCard(summary)
            } else if viewModel.aiSummary != nil {
                aiSummaryStatusCard(
                    message: "评价数据不足，暂不能生成总结",
                    icon: "text.bubble",
                    isLoading: false
                )
            } else if let error = viewModel.aiSummaryError {
                aiSummaryActionCard(
                    message: error,
                    buttonTitle: "重新生成",
                    systemImage: "arrow.clockwise"
                )
            } else {
                aiSummaryActionCard(
                    message: "根据课程评价生成摘要",
                    buttonTitle: "生成 AI 总结",
                    systemImage: "sparkles"
                )
            }
        }
    }

    private func aiSummaryContentCard(_ summary: AiSummaryData) -> some View {
        aiSummaryCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkle.magnifyingglass")
                        .foregroundStyle(.cyan)
                    Text("AI 课程总结")
                        .font(.subheadline.bold())
                    Spacer()
                    Button {
                        Task { await viewModel.generateAiSummary() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSummaryLoading)

                    Button {
                        viewModel.dismissSummary()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 4) {
                    Text("综合评价")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(summary.ratingConsensus)
                        .font(.subheadline.bold())
                        .foregroundStyle(.cyan)
                }

                if !summary.keywords.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(summary.keywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.cyan.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if !summary.pros.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("优点").font(.caption).bold().foregroundStyle(.green)
                        ForEach(summary.pros, id: \.self) { pro in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "plus.circle.fill").font(.caption2).foregroundStyle(.green)
                                Text(pro).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !summary.cons.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("缺点").font(.caption).bold().foregroundStyle(.orange)
                        ForEach(summary.cons, id: \.self) { con in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "minus.circle.fill").font(.caption2).foregroundStyle(.orange)
                                Text(con).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func aiSummaryStatusCard(message: String, icon: String, isLoading: Bool) -> some View {
        aiSummaryCardContainer {
            HStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: icon)
                        .foregroundStyle(.cyan)
                }
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    viewModel.dismissSummary()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func aiSummaryActionCard(
        message: String,
        buttonTitle: String,
        systemImage: String
    ) -> some View {
        aiSummaryCardContainer {
            HStack(spacing: 12) {
                Image(systemName: "sparkle.magnifyingglass")
                    .foregroundStyle(.cyan)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button {
                    Task { await viewModel.generateAiSummary() }
                } label: {
                    AppActionButtonLabel(buttonTitle, systemImage: systemImage)
                }
                .buttonStyle(AppActionButtonStyle(role: .secondary, size: .compact, fillsWidth: false))
                .disabled(viewModel.isSummaryLoading)
            }
        }
    }

    private func aiSummaryCardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .background(.cyan.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.cyan.opacity(0.2), lineWidth: 1)
            }
            .padding(.horizontal)
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
                        Text(detail.rating, format: .number.precision(.fractionLength(1)))
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
                    NavigationLink(value: CourseDetailDestination(courseId: course.id, loadsRelatedCourses: true)) {
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
                    NavigationLink(value: CourseDetailDestination(courseId: course.id, loadsRelatedCourses: true)) {
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
        credit.formatted(.number.precision(.fractionLength(credit == credit.rounded() ? 0 : 1)))
    }

    private func shareAction(for review: Review) -> (() -> Void)? {
#if os(iOS)
        {
            if let courseDetail = viewModel.courseDetail {
                viewModel.prepareShareImage(for: review, courseDetail: courseDetail)
            }
        }
#else
        nil
#endif
    }
}

// MARK: - Review Card Component

struct ReviewCard: View {
    let review: Review
    let canEdit: Bool
    let isLikeUpdating: Bool
    let onLike: () -> Void
    let onEdit: () -> Void
    let onHide: () -> Void
    let onReport: () -> Void
    let onShare: (() -> Void)?

    init(
        review: Review,
        canEdit: Bool,
        isLikeUpdating: Bool,
        onLike: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onHide: @escaping () -> Void,
        onReport: @escaping () -> Void,
        onShare: (() -> Void)? = nil
    ) {
        self.review = review
        self.canEdit = canEdit
        self.isLikeUpdating = isLikeUpdating
        self.onLike = onLike
        self.onEdit = onEdit
        self.onHide = onHide
        self.onReport = onReport
        self.onShare = onShare
    }

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
                        if isLikeUpdating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: review.liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.caption)
                        }
                        Text("\(review.likeCount)")
                            .font(.caption)
                    }
                    .foregroundStyle(review.liked ? .cyan : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(isLikeUpdating)

                Spacer()

                if canEdit {
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.caption)
                            Text("编辑")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

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

                if let onShare {
                    Button(action: onShare) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                            Text("分享")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
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
        canEdit: true,
        isLikeUpdating: false,
        onLike: {},
        onEdit: {},
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
        canEdit: true,
        isLikeUpdating: false,
        onLike: {},
        onEdit: {},
        onHide: {},
        onReport: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
