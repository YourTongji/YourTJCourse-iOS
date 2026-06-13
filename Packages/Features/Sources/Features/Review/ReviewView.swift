import SwiftUI
import DomainKit
import DesignSystem
import Platform

public struct ReviewView: View {
    @State private var viewModel: ReviewViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var showCaptcha = false
    @State private var showToast = false
    private let onCompletion: (() -> Void)?

    public init(
        courseId: Int,
        courseDetail: CourseDetail? = nil,
        existingReview: Review? = nil,
        localReviewEntry: MyReviewEntry? = nil,
        onCompletion: (() -> Void)? = nil
    ) {
        self.onCompletion = onCompletion
        self._viewModel = State(
            initialValue: ReviewViewModel(
                courseId: courseId,
                courseDetail: courseDetail,
                existingReview: existingReview,
                localReviewEntry: localReviewEntry
            )
        )
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Form {
                    // MARK: - Rating Section

                    Section("评分") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { star in
                                    Button(action: { viewModel.rating = star }) {
                                        Image(
                                            systemName: star <= viewModel.rating ? "star.fill" : "star"
                                        )
                                        .font(.title2)
                                        .foregroundStyle(
                                            star <= viewModel.rating ? Color.cyan : .gray.opacity(0.3)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)

                            if viewModel.rating > 0 {
                                Text(ratingLabel(viewModel.rating))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }

                    // MARK: - Comment Section

                    Section("评价内容") {
                        ZStack(alignment: .bottomTrailing) {
                            TextEditor(text: $viewModel.comment)
                                .frame(minHeight: 150)

                            Text("\(viewModel.remainingChars)")
                                .font(.caption2)
                                .foregroundStyle(
                                    viewModel.remainingChars < 0
                                        ? AnyShapeStyle(.red)
                                        : AnyShapeStyle(.tertiary)
                                )
                                .padding(4)
                        }
                    }

                    // MARK: - Optional Info Section

                    Section("选填信息") {
                        TextField("学期（如 2025-2026-1）", text: $viewModel.semester)
                        TextField("昵称", text: $viewModel.reviewerName)
                        TextField("头像 URL", text: $viewModel.reviewerAvatar)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }

                    if viewModel.mode == .edit {
                        Section {
                            Label("编辑会使用本机积分钱包进行鉴权", systemImage: "wallet.pass")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // MARK: - Error Section

                    if let error = viewModel.error {
                        Section {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.subheadline)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Button {
                                    viewModel.dismissError()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // MARK: - Submit Section

                    Section {
                        Button(action: { showCaptcha = true }) {
                            AppActionButtonLabel(
                                viewModel.mode == .create ? "提交评价" : "保存修改",
                                systemImage: "paperplane",
                                isLoading: viewModel.isSubmitting
                            )
                        }
                        .disabled(!viewModel.isValid || viewModel.isSubmitting)
                        .buttonStyle(.appPrimaryAction)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .navigationTitle(viewModel.mode == .create ? "写评价" : "编辑评价")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                }
                .sheet(isPresented: $showCaptcha) {
                    CaptchaView(config: .tongjiCaptcha(action: "submit_review"), onToken: { token in
                        showCaptcha = false
                        Task { await viewModel.submit(captchaToken: token) }
                    })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
                .interactiveDismissDisabled(viewModel.isSubmitting)

                // MARK: - Success Toast

                if showToast {
                    toastView
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showToast)
        }
        .onChange(of: viewModel.success) { _, success in
            if success {
                withAnimation { showToast = true }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { showToast = false }
                    try? await Task.sleep(for: .milliseconds(350))
                    onCompletion?()
                    dismiss()
                }
            }
        }
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastView: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.successMessage ?? "评价提交成功")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        .background {
            toastBackground
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.cyan.opacity(0.3), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var toastBackground: some View {
        if reduceTransparency {
            AppColors.accessibleCardBackground(reduceTransparency: true)
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }

    // MARK: - Helpers

    private func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 1: return "很差"
        case 2: return "较差"
        case 3: return "一般"
        case 4: return "推荐"
        case 5: return "强烈推荐"
        default: return ""
        }
    }
}

// MARK: - Previews

#Preview("Create Review") {
    ReviewView(courseId: 1)
}

#Preview("Edit Review") {
    ReviewView(
        courseId: 1,
        existingReview: Review(
            id: 42,
            sqid: "abc123",
            courseId: 1,
            semester: "2025-2026-1",
            rating: 4,
            comment: "课程内容充实，老师讲解清晰。",
            createdAt: "2025-09-15T10:30:00Z",
            likeCount: 3,
            liked: false,
            reviewerName: "Alice",
            reviewerAvatar: nil
        )
    )
}
