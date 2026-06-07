import SwiftUI
import DesignSystem
import DomainKit
import Platform

// MARK: - StartupGateView

/// The root gate that orchestrates the startup flow: loading, maintenance,
/// captcha verification, and transition into the main app.
public struct StartupGateView: View {
    @State private var viewModel: StartupViewModel
    let onComplete: () -> Void

    public init(onComplete: @escaping () -> Void) {
        self._viewModel = State(initialValue: StartupViewModel())
        self.onComplete = onComplete
    }

    /// Creates a gate view with a pre-configured ViewModel for previews or testing.
    public init(viewModel: StartupViewModel, onComplete: @escaping () -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 24) {
            switch viewModel.phase {
            case .loading:
                Spacer()
                LoadingView(message: "正在加载...")
                Spacer()

            case .maintenance(let config):
                MaintenanceContentView(config: config)

            case .captcha:
                CaptchaContent(onVerify: { token in
                    Task { await viewModel.verifyWithTurnstile(token: token) }
                })

            case .verifying:
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("验证中...")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()

            case .failed(let message, _):
                Spacer()
                ErrorStateView(
                    message: message,
                    retryTitle: "重试",
                    retryAction: { Task { await viewModel.retry() } }
                )
                Spacer()

            case .completed:
                Color.clear
                    .onAppear { onComplete() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .task {
            await viewModel.checkRuntimeState()
        }
    }
}

// MARK: - Captcha Content

/// The branded landing screen displaying the app icon and Turnstile verification.
private struct CaptchaContent: View {
    let onVerify: (String) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(AppColors.cyan)

                Text("YourTJ Course")
                    .font(AppTypography.largeTitle)

                Text("同济大学选课社区")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            CaptchaView(
                config: .turnstile(siteKey: AppConstants.turnstileSiteKey, action: "startup_gate"),
                onToken: onVerify
            )
            .frame(maxWidth: 340)
            .padding(.horizontal, 40)

            Text("点击即表示同意用户协议和隐私政策")
                .font(AppTypography.smallLabel)
                .foregroundStyle(AppColors.textSecondary)

            Spacer()
                .frame(height: 32)
        }
        .padding()
    }
}

// MARK: - Maintenance Content

/// Displays maintenance mode information with the app icon.
private struct MaintenanceContentView: View {
    let config: MaintenanceConfig?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.cyan)

            Text(config?.title ?? "维护中")
                .font(AppTypography.title)
                .bold()

            if let message = config?.message {
                Text(message)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let downtime = config?.estimatedDowntime {
                Label(downtime, systemImage: "clock")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if let progress = config?.progress, !progress.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(progress) { step in
                        HStack(spacing: 10) {
                            Image(systemName: maintenanceStepIcon(step))
                                .font(.caption)
                                .foregroundStyle(step.active ? AppColors.cyan : AppColors.textSecondary)
                                .frame(width: 18)
                            Text(step.label)
                                .font(AppTypography.caption)
                                .foregroundStyle(step.active ? AppColors.textPrimary : AppColors.textSecondary)
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(.cyan.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }

            if let lastUpdated = config?.lastUpdated {
                Text("更新于 \(lastUpdated)")
                    .font(AppTypography.smallLabel)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding()
    }

    private func maintenanceStepIcon(_ step: MaintenanceProgressStep) -> String {
        if step.done {
            "checkmark.circle.fill"
        } else if step.active {
            "clock.badge"
        } else {
            "circle"
        }
    }
}

// MARK: - Previews

#Preview("Loading") {
    StartupGateView(onComplete: {})
}

#Preview("Maintenance") {
    startupGateWithViewModel(
        StartupViewModel(initialPhase: .maintenance(maintenance: MaintenanceConfig(
            title: "系统维护",
            message: "我们正在进行系统升级，预计需要 2 小时。",
            estimatedDowntime: "预计完成：14:00"
        )))
    )
}

#Preview("Captcha") {
    startupGateWithViewModel(StartupViewModel(initialPhase: .captcha))
}

#Preview("Verifying") {
    startupGateWithViewModel(StartupViewModel(initialPhase: .verifying))
}

#Preview("Failed") {
    startupGateWithViewModel(StartupViewModel(initialPhase: .failed(
        "网络连接失败，请检查网络后重试",
        recovery: .runtimeState
    )))
}

// MARK: - Preview Helper

@MainActor
private func startupGateWithViewModel(_ vm: StartupViewModel) -> some View {
    StartupGateView(viewModel: vm, onComplete: {})
}
