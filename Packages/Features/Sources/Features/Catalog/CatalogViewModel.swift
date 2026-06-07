import Foundation
import Observation
import DomainKit
import DataKit
import Platform

@MainActor
@Observable
public final class CatalogViewModel {
    public private(set) var courses: [Course] = []
    public private(set) var isLoading = false
    public private(set) var isLoadingMore = false
    public private(set) var hasMore = true
    public private(set) var totalCount: Int?
    public private(set) var error: String?

    // Search and filter state
    public var searchText = "" {
        didSet { searchTask?.cancel(); searchTask = Task { await searchDebounced() } }
    }
    public var selectedDepartments: [String] = []
    public var onlyWithReviews = false
    public var courseNameFilter = ""
    public var courseCodeFilter = ""
    public var teacherNameFilter = ""
    public var campusFilter = ""
    public var facultyFilter = ""
    public var departments: [String] = []

    private var currentPage = 1
    private var searchTask: Task<Void, Never>?
    private let repository: CourseRepository
    private let settingsRepository: SettingsRepository
    private let logger = AppLogger(category: "Catalog")

    private static let debounceInterval: Duration = .milliseconds(300)

    public init(
        repository: CourseRepository = .init(),
        settingsRepository: SettingsRepository = .init()
    ) {
        self.repository = repository
        self.settingsRepository = settingsRepository
    }

    public func loadInitial() async {
        isLoading = true
        error = nil
        currentPage = 1
        courses = []
        _ = await fetchPage(page: 1)
        isLoading = false
    }

    public func loadInitialIfNeeded() async {
        guard courses.isEmpty, !isLoading else { return }
        await loadInitial()
    }

    public func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        let nextPage = currentPage + 1
        if await fetchPage(page: nextPage, append: true) {
            currentPage = nextPage
        }
        isLoadingMore = false
    }

    public func refresh() async {
        await loadInitial()
    }

    public func resetFilters() {
        selectedDepartments = []
        onlyWithReviews = false
        courseNameFilter = ""
        courseCodeFilter = ""
        teacherNameFilter = ""
        campusFilter = ""
        facultyFilter = ""
    }

    public func loadDepartments() async {
        guard departments.isEmpty else { return }

        do {
            departments = try await settingsRepository.getDepartments()
        } catch {
            logger.error("Failed to load departments: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func searchDebounced() async {
        try? await Task.sleep(for: Self.debounceInterval)
        guard !Task.isCancelled else { return }
        await loadInitial()
    }

    private func fetchPage(page: Int, append: Bool = false) async -> Bool {
        do {
            let response: PaginatedResponse<Course> = try await repository.getCourses(
                query: searchText.isEmpty ? nil : searchText,
                departments: selectedDepartments.isEmpty ? nil : selectedDepartments.joined(separator: ","),
                onlyWithReviews: onlyWithReviews,
                courseName: courseNameFilter.trimmed.nilIfEmpty,
                courseCode: courseCodeFilter.trimmed.nilIfEmpty,
                teacherName: teacherNameFilter.trimmed.nilIfEmpty,
                campus: campusFilter.trimmed.nilIfEmpty,
                faculty: facultyFilter.trimmed.nilIfEmpty,
                page: page,
                limit: 20,
                includeTotal: page == 1
            )
            if append {
                courses += response.data
            } else {
                courses = response.data
            }
            hasMore = response.hasMore
            totalCount = response.total
            return true
        } catch {
            logger.error("Failed to load courses: \(error.localizedDescription)")
            self.error = error.localizedDescription
            return false
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
