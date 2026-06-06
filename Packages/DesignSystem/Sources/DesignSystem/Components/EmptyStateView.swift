import SwiftUI

// MARK: - EmptyStateView

/// A generic empty-state placeholder with a large SF Symbol icon,
/// a descriptive message, and an optional action button.
///
/// Used for: no reviews, no search results, no courses, etc.
public struct EmptyStateView: View {

    private let icon: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        icon: String = "magnifyingglass",
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label(message, systemImage: icon)
                .foregroundStyle(AppColors.textSecondary)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .tint(AppColors.cyan)
            }
        }
    }
}

// MARK: - Previews

#Preview("EmptyStateView - Basic") {
    EmptyStateView(
        icon: "book.closed",
        message: "暂无可选课程"
    )
}

#Preview("EmptyStateView - With Action") {
    EmptyStateView(
        icon: "magnifyingglass",
        message: "没有找到相关课程",
        actionTitle: "返回首页",
        action: {}
    )
}

#Preview("EmptyStateView - Search") {
    EmptyStateView(
        icon: "magnifyingglass",
        message: "搜索无结果",
        actionTitle: "清除筛选",
        action: {}
    )
}
