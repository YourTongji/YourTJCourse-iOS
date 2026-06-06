import Foundation

/// Represents an academic semester in "YYYY-S" format, e.g. "2024-1" for Fall 2024.
public struct Semester: Codable, Hashable, Sendable, RawRepresentable, Comparable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var year: Int? {
        let components = rawValue.split(separator: "-")
        guard components.count == 2, let year = Int(components[0]) else { return nil }
        return year
    }

    public var term: Int? {
        let components = rawValue.split(separator: "-")
        guard components.count == 2, let term = Int(components[1]) else { return nil }
        return term
    }

    public var isFall: Bool { term == 1 }
    public var isSpring: Bool { term == 2 }
    public var isSummer: Bool { term == 3 }

    public static func < (lhs: Semester, rhs: Semester) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String { rawValue }
}

/// Provides sorting and display utilities for semester strings.
public enum SemesterFormatter {
    /// Sort an array of semester strings in descending order (most recent first).
    public static func sortDescending(_ semesters: [String]) -> [String] {
        semesters.sorted(by: >)
    }

    /// Sort an array of semester strings in ascending order.
    public static func sortAscending(_ semesters: [String]) -> [String] {
        semesters.sorted(by: <)
    }

    /// Format a semester string into a human-readable label.
    /// - Parameter semester: A string in "YYYY-S" format.
    /// - Returns: e.g. "2024 Fall" or "2025 Spring"
    public static func displayName(for semester: String) -> String {
        let components = semester.split(separator: "-")
        guard components.count == 2, let term = Int(components[1]) else { return semester }

        let termName: String
        switch term {
        case 1: termName = "Fall"
        case 2: termName = "Spring"
        case 3: termName = "Summer"
        default: termName = "Term \(term)"
        }
        return "\(components[0]) \(termName)"
    }
}
