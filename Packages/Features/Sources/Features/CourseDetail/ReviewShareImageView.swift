import SwiftUI
import Platform
import DomainKit
import DesignSystem

/// A 640pt-wide share card rendered off-screen by `ImageRenderer`.
///
/// Layout matches Flutter's `_ReviewShareImagePainter`:
/// brand header → course name + code pill → rating box → reviewer info → info pills → comment → footer.
public struct ReviewShareImageView: View {
    private static let maxRenderedCommentCharacters = 700

    let courseDetail: CourseDetail
    let review: Review

    public init(courseDetail: CourseDetail, review: Review) {
        self.courseDetail = courseDetail
        self.review = review
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().padding(.horizontal, 32)
            reviewerSection
            infoPillsRow
            commentSection
            footerSection
        }
        .frame(width: 640)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Palette

    private enum Palette {
        static let darkText = Color(red: 0.06, green: 0.09, blue: 0.16)
        static let brandTeal = Color(red: 0.39, green: 0.64, blue: 0.69)
        static let borderGray = Color(red: 0.89, green: 0.91, blue: 0.94)
        static let ratingOrange = Color(red: 0.85, green: 0.46, blue: 0.02)
        static let ratingYellow = Color(red: 1.0, green: 0.98, blue: 0.92)
        static let cyanPillFg = Color(red: 0.05, green: 0.46, blue: 0.56)
        static let cyanPillBg = Color(red: 0.93, green: 0.99, blue: 1.0)
        static let indigoPillFg = Color(red: 0.26, green: 0.22, blue: 0.77)
        static let indigoPillBg = Color(red: 0.93, green: 0.95, blue: 1.0)
        static let commentText = Color(red: 0.2, green: 0.2, blue: 0.25)
        static let commentBorder = Color(red: 0.73, green: 0.90, blue: 0.99)
        static let footerText = Color(red: 0.58, green: 0.64, blue: 0.72)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                brandLabel
                Text(courseDetail.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Palette.darkText)
                    .fixedSize(horizontal: false, vertical: true)
                courseCodePill
            }

            Spacer()

            ratingBox
        }
        .padding(32)
    }

    private var brandLabel: some View {
        Text("YOURTJ 选课社区")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Palette.brandTeal)
    }

    private var courseCodePill: some View {
        Text(courseDetail.code)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Palette.darkText)
            .clipShape(Capsule())
    }

    private var ratingBox: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1f", courseDetail.rating))
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Palette.darkText)
            Text("/ 5.0")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("\(courseDetail.reviewCount) 条评价")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Palette.borderGray, lineWidth: 1)
        )
    }

    // MARK: - Reviewer

    private var reviewerSection: some View {
        HStack(spacing: 12) {
            reviewerAvatar

            VStack(alignment: .leading, spacing: 3) {
                Text(review.reviewerName ?? "匿名用户")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.darkText)
                Text("\(review.semester) · \(formattedDate)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            reviewRatingPill
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
    }

    private var reviewerAvatar: some View {
        ZStack {
            Circle()
                .fill(AppColors.cyanLight)
                .frame(width: 44, height: 44)

            Text(avatarInitials)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.cyanDark)
        }
    }

    private var avatarInitials: String {
        let name = review.reviewerName ?? "匿名"
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        let prefix = parts.prefix(2).compactMap { $0.first.map(String.init) }
        return prefix.isEmpty ? "匿" : prefix.joined()
    }

    private var reviewRatingPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 11))
            Text("\(review.rating)")
                .font(.system(size: 14, weight: .semibold))
            Text("/ 5")
                .font(.system(size: 11))
        }
        .foregroundStyle(Palette.ratingOrange)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Palette.ratingYellow)
        .clipShape(Capsule())
    }

    // MARK: - Info Pills

    private var infoPillsRow: some View {
        HStack(spacing: 8) {
            infoPill(
                icon: "person.fill",
                text: courseDetail.teacherName,
                foreground: Palette.cyanPillFg,
                background: Palette.cyanPillBg
            )
            infoPill(
                icon: "calendar",
                text: review.semester,
                foreground: Palette.indigoPillFg,
                background: Palette.indigoPillBg
            )
            if courseDetail.credit > 0 {
                infoPill(
                    icon: "graduationcap",
                    text: "\(formattedCredit) 学分",
                    foreground: Palette.cyanPillFg,
                    background: Palette.cyanPillBg
                )
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 16)
    }

    private func infoPill(icon: String, text: String, foreground: Color, background: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 12))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(background)
        .clipShape(Capsule())
    }

    // MARK: - Comment

    private var commentSection: some View {
        Text(renderedComment)
            .font(.system(size: 15))
            .foregroundStyle(Palette.commentText)
            .lineSpacing(6)
            .lineLimit(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Palette.commentBorder, lineWidth: 1)
            )
            .padding(.horizontal, 32)
            .padding(.top, 20)
    }

    // MARK: - Footer

    private var footerSection: some View {
        Text("内容来自 YOURTJ 选课社区 · xk.yourtj.de")
            .font(.system(size: 11))
            .foregroundStyle(Palette.footerText)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 32)
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = isoFormatter.date(from: review.createdAt) else {
            return review.createdAt
        }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy/MM/dd"
        return displayFormatter.string(from: date)
    }

    private var formattedCredit: String {
        courseDetail.credit.formatted(
            .number.precision(.fractionLength(courseDetail.credit == courseDetail.credit.rounded() ? 0 : 1))
        )
    }

    private var renderedComment: String {
        let text = Self.stripMarkdown(review.comment).trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > Self.maxRenderedCommentCharacters else {
            return text
        }
        return String(text.prefix(Self.maxRenderedCommentCharacters)) + "..."
    }

    static func stripMarkdown(_ markdown: String) -> String {
        guard let attr = try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return markdown
        }
        return String(attr.characters)
    }
}
