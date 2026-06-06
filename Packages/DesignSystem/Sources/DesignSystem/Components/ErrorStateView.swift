import SwiftUI

// MARK: - ErrorStateView

/// An error-state placeholder with a prominent error icon,
/// a descriptive message, and a retry button.
///
/// Used for: network errors, API failures, loading failures.
public struct ErrorStateView: View {

    private let message: String
    private let retryTitle: String
    private let retryAction: (() -> Void)?

    public init(
        message: String = "出现了一些问题",
        retryTitle: String = "重试",
        retryAction: (() -> Void)? = nil
    ) {
        self.message = message
        self.retryTitle = retryTitle
        self.retryAction = retryAction
    }

    public var body: some View {
        ContentUnavailableView {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColors.negative)
        } actions: {
            if let retryAction {
                Button(retryTitle, action: retryAction)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.cyan)
            }
        }
    }
}

// MARK: - Previews

#Preview("ErrorStateView - With Retry") {
    ErrorStateView(
        message: "网络连接失败，请检查网络后重试",
        retryTitle: "重新加载",
        retryAction: {}
    )
}

#Preview("ErrorStateView - No Retry") {
    ErrorStateView(
        message: "服务暂不可用",
        retryAction: nil
    )
}
