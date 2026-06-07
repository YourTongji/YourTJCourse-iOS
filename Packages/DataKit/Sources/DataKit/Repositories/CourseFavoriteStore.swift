import Foundation
import DomainKit

public struct CourseFavoriteStore: Sendable {
    private let key: String

    public init(key: String = "com.yourtj.course.favoriteCourses") {
        self.key = key
    }

    public func load() -> [FavoriteCourse] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }

        do {
            return try JSONDecoder().decode([FavoriteCourse].self, from: data)
                .sorted { $0.savedAt > $1.savedAt }
        } catch {
            return []
        }
    }

    public func isFavorite(courseId: Int) -> Bool {
        load().contains { $0.id == courseId }
    }

    public func isFavorite(courseCode: String) -> Bool {
        let normalizedCode = courseCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else { return false }
        return load().contains { $0.code == normalizedCode }
    }

    public func save(_ course: FavoriteCourse) {
        var favorites = load().filter { $0.id != course.id && $0.code != course.code }
        favorites.insert(course, at: 0)
        persist(favorites)
    }

    public func remove(courseId: Int) {
        persist(load().filter { $0.id != courseId })
    }

    public func toggle(_ course: FavoriteCourse) -> Bool {
        if isFavorite(courseId: course.id) {
            remove(courseId: course.id)
            return false
        }

        save(course)
        return true
    }

    private func persist(_ favorites: [FavoriteCourse]) {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
