import SwiftUI
import DesignSystem

/// A placeholder view for the 排课模拟器 (Scheduler) tab.
/// Displays a "coming soon" hero section followed by a card listing planned features.
public struct SchedulerStubView: View {

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                    featureCard
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
            }
            .background(AppColors.background)
            .navigationTitle("排课")
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 52))
                .foregroundStyle(AppColors.cyan)
                .symbolRenderingMode(.hierarchical)

            Text("排课模拟器")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)

            Text("即将推出")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Feature Card

    private var featureCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("计划功能")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            VStack(spacing: 4) {
                FeatureRow(
                    icon: "calendar.day.timeline.left",
                    title: "周课表网格视图"
                )
                FeatureRow(
                    icon: "plus.circle",
                    title: "加课 / 退课操作"
                )
                FeatureRow(
                    icon: "exclamationmark.triangle",
                    title: "时间冲突检测"
                )
                FeatureRow(
                    icon: "square.grid.2x2",
                    title: "跨学科 / 通识标记"
                )
                FeatureRow(
                    icon: "square.and.arrow.down",
                    title: "课表模板保存"
                )
                FeatureRow(
                    icon: "magnifyingglass",
                    title: "按学期 / 专业 / 课程性质检索"
                )
            }
        }
        .cardStyle()
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppColors.cyan)
                .frame(width: 28, alignment: .center)

            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview {
    SchedulerStubView()
}
