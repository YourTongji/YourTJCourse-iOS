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

            // Footer: credit + compact semester tags
            HStack {
                Label("\(credit, specifier: "%.1f") 学分", systemImage: "book.closed")
                    .font(AppTypography.smallLabel)
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                if !visibleSemesterTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(visibleSemesterTags, id: \.self) { semesterTag in
                            SemesterTag(label: semesterTag)
                        }

                        if hiddenSemesterTagCount > 0 {
                            Text("+\(hiddenSemesterTagCount)")
                                .font(AppTypography.smallLabel)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private var visibleSemesterTags: [String] {
        Array(compactSemesterTags.prefix(3))
    }

    private var hiddenSemesterTagCount: Int {
        max(0, compactSemesterTags.count - visibleSemesterTags.count)
    }

    private var compactSemesterTags: [String] {
        var seenTags: Set<String> = []
        return sortedSemesterTags.compactMap { semester in
            let compactLabel = Self.compactSemesterLabel(semester)
            guard seenTags.insert(compactLabel).inserted else { return nil }
            return compactLabel
        }
    }

    private var sortedSemesterTags: [String] {
        Array(Set(semesterTags.map { $0.trimmed }.filter { !$0.isEmpty })).sorted(by: >)
    }

    private static func compactSemesterLabel(_ semester: String) -> String {
        guard let parsedSemester = parseSemester(semester) else {
            return semester.trimmed
        }

        switch parsedSemester.term {
        case 1:
            return "\(twoDigitYear(parsedSemester.startYear)) 秋"
        case 2:
            return "\(twoDigitYear(parsedSemester.endYear)) 春"
        case 3:
            return "\(twoDigitYear(parsedSemester.endYear)) 夏"
        default:
            return semester.trimmed
        }
    }

    private static func parseSemester(_ semester: String) -> (startYear: Int, endYear: Int, term: Int)? {
        let numbers = semester
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
        guard numbers.count >= 2, numbers[0] > 1900, numbers[1] > 1900 else { return nil }

        let numericTerm = numbers.dropFirst(2).first { (1...3).contains($0) }
        guard let term = numericTerm ?? chineseTerm(in: semester) else { return nil }
        return (startYear: numbers[0], endYear: numbers[1], term: term)
    }

    private static func chineseTerm(in semester: String) -> Int? {
        if semester.contains("第一") || semester.contains("秋") {
            return 1
        }
        if semester.contains("第二") || semester.contains("春") {
            return 2
        }
        if semester.contains("第三") || semester.contains("夏") || semester.contains("短学期") {
            return 3
        }
        return nil
    }

    private static func twoDigitYear(_ year: Int) -> String {
        let value = year % 100
        return value < 10 ? "0\(value)" : "\(value)"
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
        semesterTags: ["2026-2027学年 第一学期", "2025-2026学年 第二学期", "2025-2026-1"]
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
        semesterTags: ["2024-2025学年 第一学期"]
    )
    .cardStyle()
    .padding()
    .background(AppColors.background)
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
