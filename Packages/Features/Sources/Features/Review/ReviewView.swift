import SwiftUI
import DomainKit
import DesignSystem
import Platform

public struct ReviewView: View {
    @State private var viewModel: ReviewViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCaptcha = false

    public init(courseId: Int, existingReview: Review? = nil) {
        self._viewModel = State(
            initialValue: ReviewViewModel(courseId: courseId, existingReview: existingReview))
    }

    public var body: some View {
        NavigationStack {
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
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: - Submit Section

                Section {
                    Button(action: { showCaptcha = true }) {
                        HStack {
                            Spacer()
                            if viewModel.isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(viewModel.mode == .create ? "提交评价" : "保存修改")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSubmitting)
                    .buttonStyle(.glassProminent)
                    .listRowInsets(EdgeInsets())
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
                .presentationDetents([.medium, .large])
            }
            .interactiveDismissDisabled(viewModel.isSubmitting)
            .alert("完成", isPresented: .init(
                get: { viewModel.successMessage != nil },
                set: { if !$0 { viewModel.dismissSuccess() } }
            )) {
                Button("好") {
                    viewModel.dismissSuccess()
                    dismiss()
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
        }
    }

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
