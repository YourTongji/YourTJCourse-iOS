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
                // In MVP, use a simplified captcha view
                // Full version: Platform's CaptchaView with TongjiCaptcha
                SimplifiedCaptchaView(onToken: { token in
                    showCaptcha = false
                    Task { await viewModel.submit(captchaToken: token) }
                })
            }
            .interactiveDismissDisabled(viewModel.isSubmitting)
            .onChange(of: viewModel.success) { _, success in
                if success {
                    dismiss()
                }
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

// MARK: - Simplified Captcha (MVP)

/// A simplified captcha placeholder used during development.
///
/// In production, replace this with `CaptchaView` from `Platform`:
/// ```swift
/// CaptchaView(config: .tongjiCaptcha(action: "submit_review"), onToken: onToken)
/// ```
struct SimplifiedCaptchaView: View {
    let onToken: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 64))
                .foregroundStyle(.cyan)

            Text("人机验证")
                .font(.title2)
                .bold()

            Text("请点击下方按钮完成验证")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: {
                // In MVP, simulate captcha with a fixed token
                // In production, this opens CaptchaView with TongjiCaptcha
                onToken("mvp_simulated_captcha_token")
            }) {
                Text("完成验证")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 40)

            Button("取消", role: .cancel) {
                dismiss()
            }
            .padding(.bottom)

            Spacer()
                .frame(height: 32)
        }
        .padding()
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
