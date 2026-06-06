import SwiftUI

// MARK: - CourseCard

/// A reusable card that displays a course summary in list and grid contexts.
///
/// Shows the course name, code, teacher, department, rating, review count,
/// credit value, and semester tags. Uses a solid `.cardStyle()` background.
public struct CourseCard: View {

    private let name: String
    private let code: String
    private let teacher: String
    private let department: String
    private let rating: Double
    private let reviewCount: Int
    private let credit: Double
    private let semesterTags: [String]

    public init(
        name: String,
        code: String,
        teacher: String,
        department: String,
        rating: Double,
        reviewCount: Int,
        credit: Double,
        semesterTags: [String] = []
    ) {
        self.name = name
        self.code = code
        self.teacher = teacher
        self.department = department
        self.rating = rating
        self.reviewCount = reviewCount
        self.credit = credit
        self.semesterTags = semesterTags
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: name + code
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)

                Text(code)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Metadata row: teacher · department
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.caption2)
                Text(teacher)
                    .font(AppTypography.caption)

                if !department.isEmpty {
                    Text("·")
                        .foregroundStyle(AppColors.textSecondary)
                    Text(department)
                        .font(AppTypography.caption)
                }
            }
            .foregroundStyle(AppColors.textSecondary)

            // Rating + review count
            HStack(spacing: 6) {
                RatingView(rating: rating, size: 12)

                Text(String(format: "%.1f", rating))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textPrimary)

                Text("(\(reviewCount))")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Footer: credit + semester tags
            HStack {
                Label("\(credit, specifier: "%.1f") 学分", systemImage: "book.closed")
                    .font(AppTypography.smallLabel)
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                HStack(spacing: 4) {
                    ForEach(semesterTags.prefix(3), id: \.self) { tag in
                        SemesterTag(label: tag)
                    }
                    if semesterTags.count > 3 {
                        Text("+\(semesterTags.count - 3)")
                            .font(AppTypography.smallLabel)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("CourseCard") {
    CourseCard(
        name: "高等数学（上）",
        code: "MATH1011",
        teacher: "李老师",
        department: "数学科学学院",
        rating: 4.5,
        reviewCount: 128,
        credit: 5.0,
        semesterTags: ["2024-2025-1", "2023-2024-2", "2023-2024-1"]
    )
    .cardStyle()
    .padding()
    .background(AppColors.background)
}

#Preview("CourseCard - No rating") {
    CourseCard(
        name: "线性代数",
        code: "MATH1012",
        teacher: "王老师",
        department: "数学科学学院",
        rating: 0,
        reviewCount: 0,
        credit: 4.0,
        semesterTags: ["2024-2025-1"]
    )
    .cardStyle()
    .padding()
    .background(AppColors.background)
}
