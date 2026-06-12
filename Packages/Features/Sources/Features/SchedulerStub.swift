import Foundation
import SwiftUI
import Observation
import DomainKit
import DataKit
import DesignSystem
import Platform

public typealias SchedulerStubView = SchedulerView

private enum SchedulerPage: String, CaseIterable, Identifiable {
    case filters
    case candidates
    case selected
    case timetable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .filters: "筛选"
        case .candidates: "候选"
        case .selected: "已选"
        case .timetable: "课表"
        }
    }
}

private enum TeachingClassSelectionState {
    case none
    case selected
    case sameCourseSelected
}

enum SchedulerFavoriteImportResult: Sendable {
    /// Course + matching teaching class imported into candidates.
    case imported
    /// The course was already in the candidate list.
    case alreadyPresent
    /// The course exists this semester but the favorited teacher has no teaching class.
    case noTeachingClass
    /// The lookup failed (network / missing course this semester).
    case failed(String)
}

private enum SchedulerSlotSheetPage: String, CaseIterable, Identifiable {
    case candidates
    case timeLookup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .candidates: "候选"
        case .timeLookup: "空段找课"
        }
    }
}

private struct SchedulerTimetableSlot: Identifiable, Hashable, Sendable {
    let day: Int
    let section: Int

    var id: String { "\(day)-\(section)" }

    var title: String {
        "\(dayName) 第 \(section) 节"
    }

    var dayName: String {
        ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"][safe: day] ?? "未定"
    }
}

private struct SchedulerClassCandidate: Identifiable, Hashable, Sendable {
    let course: SchedulerCourseSummary
    let teachingClass: SchedulerTeachingClass

    var id: String { "\(course.courseCode)|\(teachingClass.code)" }
}

/// Value-based navigation target for a teaching-class review. Using a value with
/// `.navigationDestination` (instead of an inline `NavigationLink` destination)
/// avoids the double-push that happens when several `NavigationLink`s live inside
/// the same `List` row.
///
/// The `classCode` is part of the value so that each teaching class produces a
/// *distinct* target. Without it, classes that share a teacher (or whose teacher
/// list is empty) would yield identical values, and SwiftUI would push one screen
/// per duplicate link — nesting several identical review pages.
private struct SchedulerReviewTarget: Hashable {
    let courseCode: String
    let classCode: String
    let teacherName: String?
    let teacherCode: String?

    init(courseCode: String, teachingClass: SchedulerTeachingClass) {
        self.courseCode = courseCode
        self.classCode = teachingClass.code
        let teacher = teachingClass.resolvedTeacher
        self.teacherName = teacher?.teacherName.trimmed.nilIfEmpty
        self.teacherCode = teacher?.teacherCode.trimmed.nilIfEmpty
    }
}

fileprivate struct SchedulerCourseReviewInfo: Equatable, Sendable {
    let courseId: Int
    let rating: Double
    let reviewCount: Int
    let teacherName: String
    let isFavorite: Bool

    init(course: CourseDetail, isFavorite: Bool) {
        self.courseId = course.id
        self.rating = course.rating
        self.reviewCount = course.reviewCount
        self.teacherName = course.teacherName
        self.isFavorite = isFavorite
    }

    init(favorite: FavoriteCourse) {
        self.courseId = favorite.id
        self.rating = favorite.rating
        self.reviewCount = favorite.reviewCount
        self.teacherName = favorite.teacherName
        self.isFavorite = true
    }

    var ratingGrade: String {
        guard reviewCount > 0 else { return "暂无" }
        switch rating {
        case 4.5...: return "优秀"
        case 4.0..<4.5: return "推荐"
        case 3.0..<4.0: return "中等"
        default: return "谨慎"
        }
    }

    var ratingText: String {
        guard reviewCount > 0 else { return "暂无评课" }
        return "\(ratingGrade) \(rating.formatted(.number.precision(.fractionLength(1)))) · \(reviewCount) 评"
    }
}

public struct SchedulerView: View {
    @State private var viewModel: SchedulerViewModel
    @State private var selectedPage: SchedulerPage = .filters
    @State private var activeTimetableSlot: SchedulerTimetableSlot?
    @State private var showsClearConfirmation = false
    @State private var showsFavoriteImport = false
    @State private var showSyncChanges = false
    @State private var reviewTarget: SchedulerReviewTarget?

    public init() {
        self._viewModel = State(initialValue: SchedulerViewModel())
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("排课页面", selection: $selectedPage) {
                    ForEach(SchedulerPage.allCases) { page in
                        Text(page.title).tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 6)

                pageContent
            }
            .navigationTitle("排课")
            .navigationDestination(item: $reviewTarget) { target in
                SchedulerCourseByCodeView(
                    courseCode: target.courseCode,
                    teacherName: target.teacherName,
                    teacherCode: target.teacherCode
                )
            }
            .task { await viewModel.load() }
            .onAppear {
                viewModel.refreshFavorites()
                Task { await viewModel.syncSelectedClasses() }
            }
            .onChange(of: viewModel.unacknowledgedChangeCount) { _, count in
                if count > 0 { showSyncChanges = true }
            }
            .sheet(isPresented: $showSyncChanges) {
                SyncChangeSheet(viewModel: viewModel)
            }
            .onChange(of: viewModel.selectedCalendarId) { _, _ in
                Task { await viewModel.calendarChanged() }
            }
            .onChange(of: viewModel.selectedGrade) { _, _ in
                Task { await viewModel.gradeChanged() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(!viewModel.hasPlannerData)
                    .accessibilityLabel("清空排课数据")
                }
            }
            .sheet(item: $activeTimetableSlot) { slot in
                SchedulerSlotSheet(
                    viewModel: viewModel,
                    slot: slot,
                    onDismiss: { activeTimetableSlot = nil }
                )
            }
            .sheet(isPresented: $showsFavoriteImport) {
                SchedulerFavoriteImportSheet(
                    viewModel: viewModel,
                    onDismiss: { showsFavoriteImport = false }
                )
            }
            .confirmationDialog(
                "清空排课数据？",
                isPresented: $showsClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("清空候选和已选课程", role: .destructive) {
                    viewModel.clearPlannerData()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("当前候选列表、已选课程和课表数据都会被删除，筛选条件会保留。")
            }
            .alert("提示", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )) {
                Button("好", role: .cancel) { viewModel.dismissError() }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    // All four pages are kept alive in a ZStack and toggled via opacity so each
    // page retains its own scroll position (and other List UI state) when the user
    // switches tabs and comes back, instead of being torn down and rebuilt.
    private var pageContent: some View {
        ZStack {
            page(.filters) {
                List {
                    filterSection
                    majorSection
                    timeLookupSection
                }
            }

            page(.candidates) {
                List {
                    favoriteImportSection
                    resultsSection
                }
            }

            page(.selected) {
                List {
                    selectedPageSection
                }
            }

            page(.timetable) {
                List {
                    timetableSection
                }
            }
        }
    }

    @ViewBuilder
    private func page<Content: View>(
        _ page: SchedulerPage,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isActive = selectedPage == page
        content()
            .refreshable { await viewModel.load() }
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
    }

    private var filterSection: some View {
        Section {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                    Text("正在加载排课数据...")
                        .foregroundStyle(.secondary)
                }
            }

            Picker("学期", selection: $viewModel.selectedCalendarId) {
                ForEach(viewModel.calendars) { calendar in
                    Text(calendar.calendarName).tag(calendar.calendarId)
                }
            }

            TextField("课程名", text: $viewModel.courseName)
                .textInputAutocapitalization(.never)
            TextField("课号", text: $viewModel.courseCode)
                .textInputAutocapitalization(.never)
            TextField("教师姓名", text: $viewModel.teacherName)
                .textInputAutocapitalization(.never)

            Picker("校区", selection: $viewModel.selectedCampusId) {
                Text("不限").tag("")
                ForEach(viewModel.campuses) { campus in
                    Text(campus.campusName).tag(campus.campusId)
                }
            }

            Picker("开课院系", selection: $viewModel.selectedFacultyId) {
                Text("不限").tag("")
                ForEach(viewModel.faculties) { faculty in
                    Text(faculty.facultyName).tag(faculty.facultyId)
                }
            }

            Button {
                Task {
                    await viewModel.search()
                    if viewModel.error == nil {
                        selectedPage = .candidates
                    }
                }
            } label: {
                AppActionButtonLabel(
                    viewModel.isSearching ? "搜索中..." : "搜索课程",
                    systemImage: "magnifyingglass",
                    isLoading: viewModel.isSearching
                )
            }
            .buttonStyle(.appPrimaryAction)
            .disabled(viewModel.isSearching || !viewModel.canSearch)
        } header: {
            HStack {
                Text("检索")
                Spacer()
                if let latestUpdateTime = viewModel.latestUpdateTime {
                    Text("同步于 \(latestUpdateTime)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("至少填写一个检索条件。课程详情会在展开教学班时按课号实时查询。")
        }
    }

    private var majorSection: some View {
        Section {
            if viewModel.isLoadingMajorOptions {
                HStack {
                    ProgressView()
                    Text("正在加载专业列表...")
                        .foregroundStyle(.secondary)
                }
            }

            Picker("年级", selection: $viewModel.selectedGrade) {
                Text("未选择").tag(0)
                ForEach(viewModel.grades, id: \.self) { grade in
                    Text("\(grade) 级").tag(grade)
                }
            }

            if viewModel.hasSelectedMajor {
                // 填入之后：展示已选专业，并提供清除入口
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已选专业")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.selectedMajorDisplayName)
                            .font(.subheadline.weight(.medium))
                    }
                    Spacer()
                    Button {
                        viewModel.clearSelectedMajor()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除已选专业")
                }
            } else {
                // 未填入：搜索 + 结果列表
                TextField("搜索专业代码或名称", text: $viewModel.majorSearchText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if viewModel.selectedGrade == 0 {
                    Text("请先选择年级")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if viewModel.majors.isEmpty {
                    Text(viewModel.isLoadingMajorOptions ? "正在加载专业..." : "暂无专业数据")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if viewModel.majorSearchText.trimmed.isEmpty {
                    Text("共 \(viewModel.majors.count) 个专业，输入代码或名称搜索")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if viewModel.filteredMajors.isEmpty {
                    Text("未找到匹配「\(viewModel.majorSearchText.trimmed)」的专业")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.filteredMajors) { major in
                        Button {
                            viewModel.selectMajor(major)
                        } label: {
                            HStack(spacing: 8) {
                                Text(major.code)
                                    .font(.subheadline.monospacedDigit().weight(.medium))
                                    .foregroundStyle(AppColors.cyan)
                                Text(major.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                Task {
                    await viewModel.loadMajorCourses()
                    if viewModel.error == nil {
                        selectedPage = .candidates
                    }
                }
            } label: {
                AppActionButtonLabel(
                    viewModel.isLoadingMajorCourses ? "加载中..." : "加载专业课表",
                    systemImage: "list.bullet.rectangle",
                    isLoading: viewModel.isLoadingMajorCourses
                )
            }
            .buttonStyle(.appSecondaryAction)
            .disabled(viewModel.isLoadingMajorCourses || viewModel.selectedCalendarId == 0 || viewModel.selectedGrade == 0 || viewModel.selectedMajorCode.isEmpty)
        } header: {
            Text("专业课表")
        } footer: {
            Text("按培养方案课程加载教学班，可继续手动选择具体教学班加入周课表。")
        }
    }

    private var timeLookupSection: some View {
        Section {
            Picker("星期", selection: $viewModel.selectedDay) {
                ForEach(1...7, id: \.self) { day in
                    Text(Self.dayNames[day]).tag(day)
                }
            }

            Picker("节次", selection: $viewModel.selectedSectionGroup) {
                ForEach(1...6, id: \.self) { section in
                    Text(Self.sectionGroupNames[section]).tag(section)
                }
            }

            Button {
                Task {
                    await viewModel.findCoursesBySelectedTime()
                    if viewModel.error == nil {
                        selectedPage = .candidates
                    }
                }
            } label: {
                AppActionButtonLabel("按时间找可选课", systemImage: "clock")
            }
            .buttonStyle(.appSecondaryAction)
            .disabled(viewModel.isSearching || viewModel.selectedCalendarId == 0)
        } header: {
            Text("空段找课")
        } footer: {
            Text("按后端可选课程范围查询，不会自动避开已选课程冲突；加课时会再次检测。")
        }
    }

    @ViewBuilder
    private var selectedPageSection: some View {
        if viewModel.selectedClasses.isEmpty {
            Section {
                ContentUnavailableView(
                    "暂无已选课程",
                    systemImage: "calendar.badge.plus",
                    description: Text("在候选页展开教学班后加入模拟课表")
                )
            }
        } else {
            Section("已选课程") {
                ForEach(viewModel.selectedClasses) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.course.courseName)
                                    .font(.headline)
                                Text("\(item.course.courseCode) · \(item.teachingClass.code)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.remove(item)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("移除 \(item.course.courseName)")
                        }

                        Text(item.teachingClass.teacherNames)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.teachingClass.scheduleSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var timetableSection: some View {
        Section("周课表") {
            ScrollView(.horizontal, showsIndicators: true) {
                Grid(alignment: .topLeading, horizontalSpacing: 6, verticalSpacing: 6) {
                    GridRow {
                        Text("节")
                            .font(.caption.bold())
                            .frame(width: 34, height: 32)
                        ForEach(1...7, id: \.self) { day in
                            Text(Self.dayNames[day])
                                .font(.caption.bold())
                                .frame(width: 92, height: 32)
                        }
                    }

                    ForEach(1...12, id: \.self) { section in
                        GridRow {
                            Text("\(section)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 34, height: 62)
                            ForEach(1...7, id: \.self) { day in
                                Button {
                                    activeTimetableSlot = SchedulerTimetableSlot(day: day, section: section)
                                } label: {
                                    TimetableCell(entry: viewModel.scheduleEntry(day: day, section: section))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(timetableCellAccessibilityLabel(day: day, section: section))
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var favoriteImportSection: some View {
        Section {
            Button {
                viewModel.refreshFavorites()
                showsFavoriteImport = true
            } label: {
                Label("导入已收藏课程", systemImage: "star")
            }
            .disabled(viewModel.favoriteCourses.isEmpty)

            if viewModel.favoriteCourses.isEmpty {
                Text("在评课详情页收藏课程后，可以从这里加入候选列表。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("收藏")
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        Section {
            if viewModel.isSearching {
                HStack {
                    ProgressView()
                    Text("正在查询课程...")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.searchResults.isEmpty {
                ContentUnavailableView(
                    "暂无课程",
                    systemImage: "magnifyingglass",
                    description: Text("输入课程名、课号、教师或选择空段后查询")
                )
            } else {
                if !viewModel.availableCampusesInResults.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            FilterChip(title: "全部校区", isSelected: viewModel.candidateCampusFilter.isEmpty) {
                                viewModel.candidateCampusFilter = ""
                            }
                            ForEach(viewModel.availableCampusesInResults, id: \.self) { campus in
                                FilterChip(title: campus, isSelected: viewModel.candidateCampusFilter == campus) {
                                    viewModel.candidateCampusFilter = campus
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 8)
                    }
                }

                ForEach(viewModel.searchResults) { course in
                    SchedulerCourseResultRow(
                        course: course,
                        isExpanded: viewModel.expandedCourseCode == course.courseCode,
                        isLoading: viewModel.loadingDetailsCourseCode == course.courseCode,
                        classes: viewModel.classes(for: course).filter { cls in
                            viewModel.candidateCampusFilter.isEmpty || cls.campus == viewModel.candidateCampusFilter
                        },
                        selectionState: { teachingClass in
                            viewModel.selectionState(course: course, teachingClass: teachingClass)
                        },
                        reviewInfo: { teachingClass in
                            viewModel.reviewInfo(course: course, teachingClass: teachingClass)
                        },
                        isFavorite: { teachingClass in
                            viewModel.isFavorite(course: course, teachingClass: teachingClass)
                        },
                        onToggle: {
                            Task { await viewModel.toggleDetails(for: course) }
                        },
                        onAdd: { teachingClass in
                            viewModel.add(course: course, teachingClass: teachingClass)
                        },
                        onRemove: { teachingClass in
                            viewModel.remove(course: course, teachingClass: teachingClass)
                        },
                        onShowReview: { teachingClass in
                            reviewTarget = SchedulerReviewTarget(
                                courseCode: course.courseCode,
                                teachingClass: teachingClass
                            )
                        }
                    )
                }
            }
        } header: {
            HStack {
                Text("查询结果")
                Spacer()
                if !viewModel.searchResults.isEmpty {
                    Text("\(viewModel.searchResults.count) 门")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private static let dayNames = ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    private static let sectionGroupNames = ["", "1-2 节", "3-4 节", "5-6 节", "7-8 节", "第 9 节", "10-12 节"]

    private func timetableCellAccessibilityLabel(day: Int, section: Int) -> String {
        let slot = SchedulerTimetableSlot(day: day, section: section)
        if let entry = viewModel.scheduleEntry(day: day, section: section) {
            return "\(slot.title)，\(entry.courseName)"
        }
        return "\(slot.title)，空白时段"
    }
}

@MainActor
@Observable
public final class SchedulerViewModel {
    public private(set) var calendars: [SchedulerCalendar] = []
    public private(set) var campuses: [SchedulerCampus] = []
    public private(set) var faculties: [SchedulerFaculty] = []
    public private(set) var searchResults: [SchedulerCourseSummary] = []
    public private(set) var selectedClasses: [SchedulerSelectedClass] = []
    public private(set) var latestUpdateTime: String?
    public private(set) var isLoading = false
    public private(set) var isSearching = false
    public private(set) var loadingDetailsCourseCode: String?
    public private(set) var expandedCourseCode: String?
    public private(set) var error: String?
    public private(set) var grades: [Int] = []
    public private(set) var majors: [SchedulerMajor] = []
    public private(set) var isLoadingMajorOptions = false
    public private(set) var isLoadingMajorCourses = false
    public private(set) var timetableLookupResults: [SchedulerCourseSummary] = []
    public private(set) var isLoadingTimetableLookup = false
    public private(set) var loadingTimetableLookupDetailsCourseCode: String?
    public private(set) var timetableLookupExpandedCourseCode: String?
    public private(set) var favoriteCourses: [FavoriteCourse] = []
    public private(set) var syncResult: SyncResult?
    public private(set) var isSyncing = false
    public private(set) var unacknowledgedChangeCount = 0

    public var selectedCalendarId = 0
    public var selectedGrade = 0
    public var selectedMajorCode = ""
    public var selectedCampusId = ""
    public var selectedFacultyId = ""
    public var courseName = ""
    public var courseCode = ""
    public var teacherName = ""
    public var selectedDay = 1
    public var selectedSectionGroup = 1
    public var majorSearchText = ""
    public var candidateCampusFilter = ""

    public var filteredMajors: [SchedulerMajor] {
        let text = majorSearchText.trimmed.lowercased()
        guard !text.isEmpty else { return majors }
        return majors.filter { $0.code.lowercased().contains(text) || $0.name.lowercased().contains(text) }
    }

    public var hasSelectedMajor: Bool {
        !selectedMajorCode.isEmpty
    }

    /// Display label for the currently selected major. Resolves the name from the
    /// loaded list, falling back to the bare code if the list isn't available.
    public var selectedMajorDisplayName: String {
        if let major = majors.first(where: { $0.code == selectedMajorCode }) {
            return "\(major.code) \(major.name)"
        }
        return selectedMajorCode
    }

    public func selectMajor(_ major: SchedulerMajor) {
        selectedMajorCode = major.code
        majorSearchText = ""
    }

    public func clearSelectedMajor() {
        selectedMajorCode = ""
        majorSearchText = ""
    }

    public var availableCampusesInResults: [String] {
        let allClasses = searchResults.flatMap { detailsByCourseCode[$0.courseCode] ?? [] }
        let campuses = Set(allClasses.map(\.campus).filter { !$0.isEmpty })
        return Array(campuses).sorted()
    }

    private let schedulerRepo: SchedulerRepository
    private let courseRepo: CourseRepository
    private let favoriteStore: CourseFavoriteStore
    private let logger = AppLogger(category: "Scheduler")
    private var detailsByCourseCode: [String: [SchedulerTeachingClass]] = [:]
    private var timetableLookupDetailsByCourseCode: [String: [SchedulerTeachingClass]] = [:]
    /// Review/rating metadata keyed per teaching class (course + teacher), because
    /// reviews in this system target a course taught by a specific teacher rather
    /// than the whole course.
    private var reviewInfoByClassKey: [String: SchedulerCourseReviewInfo] = [:]
    /// Class keys that have already been resolved over the network, so repeated
    /// expands don't refetch (favorite-seeded entries are absent here and still
    /// get one network refresh).
    private var hydratedClassKeys: Set<String> = []
    private var timetableLookupSlotId: String?
    private let selectedClassesStorageKey = "com.yourtj.course.scheduler.selectedClassesByCalendar"
    private let syncEngine = SyncEngine()
    private let syncStore = SyncStore()

    public init(
        schedulerRepo: SchedulerRepository = .init(),
        courseRepo: CourseRepository = .init(),
        favoriteStore: CourseFavoriteStore = .init()
    ) {
        self.schedulerRepo = schedulerRepo
        self.courseRepo = courseRepo
        self.favoriteStore = favoriteStore
        refreshFavorites()
    }

    public var canSearch: Bool {
        selectedCalendarId != 0 && hasSearchCriteria
    }

    public var hasPlannerData: Bool {
        !searchResults.isEmpty || !selectedClasses.isEmpty || !timetableLookupResults.isEmpty
    }

    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        refreshFavorites()
        defer { isLoading = false }

        do {
            calendars = try await schedulerRepo.getCalendars()
            if selectedCalendarId == 0 {
                selectedCalendarId = calendars.first?.calendarId ?? 0
            }
            restoreSelectedClasses()
        } catch {
            logger.error("Failed to load scheduler calendars: \(error.localizedDescription)")
            self.error = error.localizedDescription
            return
        }

        async let campusTask: [SchedulerCampus] = schedulerRepo.getCampuses()
        async let facultyTask: [SchedulerFaculty] = schedulerRepo.getFaculties()
        async let updateTask: String? = schedulerRepo.getLatestUpdateTime()

        campuses = (try? await campusTask) ?? []
        faculties = (try? await facultyTask) ?? []
        latestUpdateTime = try? await updateTask
        await loadGrades()
    }

    public func calendarChanged() async {
        selectedGrade = 0
        selectedMajorCode = ""
        majorSearchText = ""
        grades = []
        majors = []
        searchResults = []
        expandedCourseCode = nil
        detailsByCourseCode = [:]
        clearTimetableLookup()
        restoreSelectedClasses()
        guard selectedCalendarId != 0 else { return }
        await loadGrades()
    }

    public func gradeChanged() async {
        selectedMajorCode = ""
        majorSearchText = ""
        majors = []
        guard selectedCalendarId != 0, selectedGrade != 0 else { return }
        await loadMajors()
    }

    public func search() async {
        guard canSearch else {
            error = "请至少填写一个检索条件"
            return
        }
        await runSearch {
            try await schedulerRepo.searchCourses(
                calendarId: selectedCalendarId,
                courseName: courseName.trimmed,
                courseCode: courseCode.trimmed,
                teacherName: teacherName.trimmed,
                campus: selectedCampusId,
                faculty: selectedFacultyId
            ).courses
        }
    }

    public func loadMajorCourses() async {
        guard selectedCalendarId != 0, selectedGrade != 0, !selectedMajorCode.isEmpty else {
            error = "请先选择学期、年级和专业"
            return
        }
        guard !isLoadingMajorCourses else { return }

        isLoadingMajorCourses = true
        error = nil
        expandedCourseCode = nil
        detailsByCourseCode = [:]
        clearTimetableLookup()
        defer { isLoadingMajorCourses = false }

        do {
            let majorCourses = try await schedulerRepo.findCoursesByMajor(
                calendarId: selectedCalendarId,
                grade: selectedGrade,
                code: selectedMajorCode
            )
            var summaries: [SchedulerCourseSummary] = []
            var details: [String: [SchedulerTeachingClass]] = [:]
            for item in majorCourses {
                let summary = item.summary
                summaries.append(summary)
                details[summary.courseCode] = item.courses
            }
            searchResults = summaries
            detailsByCourseCode = details
        } catch {
            logger.error("Failed to load major courses: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    public func findCoursesBySelectedTime() async {
        guard selectedCalendarId != 0 else {
            error = "请先选择学期"
            return
        }
        await runSearch {
            try await schedulerRepo.findCoursesByTime(
                calendarId: selectedCalendarId,
                day: selectedDay,
                section: selectedSectionGroup
            )
        }
    }

    public func loadTimetableLookup(day: Int, section: Int) async {
        guard selectedCalendarId != 0 else {
            error = "请先选择学期"
            return
        }
        guard !isLoadingTimetableLookup else { return }

        let slotId = SchedulerTimetableSlot(day: day, section: section).id
        if timetableLookupSlotId == slotId, !timetableLookupResults.isEmpty {
            return
        }

        isLoadingTimetableLookup = true
        error = nil
        timetableLookupSlotId = slotId
        timetableLookupExpandedCourseCode = nil
        timetableLookupDetailsByCourseCode = [:]
        defer { isLoadingTimetableLookup = false }

        do {
            timetableLookupResults = try await schedulerRepo.findCoursesByTime(
                calendarId: selectedCalendarId,
                day: day,
                section: Self.sectionGroup(for: section)
            )
        } catch {
            logger.error("Failed to load timetable slot courses: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    public func toggleTimetableLookupDetails(
        for course: SchedulerCourseSummary,
        day: Int,
        section: Int
    ) async {
        if timetableLookupExpandedCourseCode == course.courseCode {
            timetableLookupExpandedCourseCode = nil
            return
        }

        timetableLookupExpandedCourseCode = course.courseCode

        // Already loaded (e.g. expanded before): still ensure review info is hydrated.
        if let cached = timetableLookupDetailsByCourseCode[course.courseCode] {
            hydrateClassReviewInfoInBackground(courseCode: course.courseCode, classes: cached)
            return
        }

        loadingTimetableLookupDetailsCourseCode = course.courseCode
        defer { loadingTimetableLookupDetailsCourseCode = nil }

        do {
            let classes = try await schedulerRepo.findCourseDetails(
                calendarId: selectedCalendarId,
                courseCode: course.courseCode
            )
            timetableLookupDetailsByCourseCode[course.courseCode] = classes
            hydrateClassReviewInfoInBackground(courseCode: course.courseCode, classes: classes)
        } catch {
            logger.error("Failed to load timetable slot course details: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    public func toggleDetails(for course: SchedulerCourseSummary) async {
        if expandedCourseCode == course.courseCode {
            expandedCourseCode = nil
            return
        }

        expandedCourseCode = course.courseCode

        // Teaching-class details may already be cached (e.g. preloaded by the major
        // course table or a previous expand). Hydrate review info regardless, since
        // it is fetched lazily per teaching class and may not have run yet.
        if let cached = detailsByCourseCode[course.courseCode] {
            hydrateClassReviewInfoInBackground(courseCode: course.courseCode, classes: cached)
            return
        }

        loadingDetailsCourseCode = course.courseCode
        defer { loadingDetailsCourseCode = nil }

        do {
            let classes = try await schedulerRepo.findCourseDetails(
                calendarId: selectedCalendarId,
                courseCode: course.courseCode
            )
            detailsByCourseCode[course.courseCode] = classes
            hydrateClassReviewInfoInBackground(courseCode: course.courseCode, classes: classes)
        } catch {
            logger.error("Failed to load scheduler course details: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    public func classes(for course: SchedulerCourseSummary) -> [SchedulerTeachingClass] {
        detailsByCourseCode[course.courseCode] ?? []
    }

    public func refreshFavorites() {
        favoriteCourses = favoriteStore.load()
    }

    /// Imports a favorited course together with the teaching class taught by the
    /// favorited teacher. A favorite is teacher-specific, so the import only
    /// succeeds when the current semester actually offers that teacher's class.
    func importFavorite(_ favorite: FavoriteCourse) async -> SchedulerFavoriteImportResult {
        guard selectedCalendarId != 0 else {
            return .failed("请先选择学期")
        }

        let summary = SchedulerCourseSummary(favorite: favorite)
        let courseCode = summary.courseCode

        let teachingClasses: [SchedulerTeachingClass]
        if let cached = detailsByCourseCode[courseCode] {
            teachingClasses = cached
        } else {
            do {
                teachingClasses = try await schedulerRepo.findCourseDetails(
                    calendarId: selectedCalendarId,
                    courseCode: courseCode
                )
            } catch {
                logger.error("Failed to resolve favorite teaching classes for \(courseCode): \(error.localizedDescription)")
                return .failed("无法获取「\(favorite.name)」本学期的教学班")
            }
        }

        let matchedClasses = teachingClasses.filter { teacherMatches(favorite: favorite, teachingClass: $0) }
        guard !matchedClasses.isEmpty else {
            return .noTeachingClass
        }

        // Keep all teaching classes available so the user sees the full picture,
        // while the favorited teacher's class is highlighted via favorite matching.
        detailsByCourseCode[courseCode] = teachingClasses
        // Seed the matched classes' rating from the favorite snapshot so it shows
        // immediately; network hydration will refresh it per class afterwards.
        for matched in matchedClasses {
            let key = classReviewKey(courseCode: courseCode, teachingClass: matched)
            if reviewInfoByClassKey[key] == nil {
                reviewInfoByClassKey[key] = SchedulerCourseReviewInfo(favorite: favorite)
            }
        }

        let alreadyPresent = searchResults.contains { $0.courseCode == courseCode }
        if !alreadyPresent {
            searchResults.insert(summary, at: 0)
        }
        expandedCourseCode = courseCode
        hydrateClassReviewInfoInBackground(courseCode: courseCode, classes: teachingClasses)

        return alreadyPresent ? .alreadyPresent : .imported
    }

    /// Imports every favorite, reporting how many landed and how many could not be
    /// matched to a teaching class this semester.
    func importAllFavorites() async -> (imported: Int, skipped: Int, failed: Int) {
        refreshFavorites()
        var imported = 0
        var skipped = 0
        var failed = 0
        for favorite in favoriteCourses {
            switch await importFavorite(favorite) {
            case .imported: imported += 1
            case .alreadyPresent: skipped += 1
            case .noTeachingClass, .failed: failed += 1
            }
        }
        return (imported, skipped, failed)
    }

    fileprivate func reviewInfo(
        course: SchedulerCourseSummary,
        teachingClass: SchedulerTeachingClass
    ) -> SchedulerCourseReviewInfo? {
        reviewInfoByClassKey[classReviewKey(courseCode: course.courseCode, teachingClass: teachingClass)]
    }

    fileprivate func isFavorite(
        course: SchedulerCourseSummary,
        teachingClass: SchedulerTeachingClass
    ) -> Bool {
        favoriteCourses.contains { favorite in
            favorite.code == course.courseCode && teacherMatches(favorite: favorite, teachingClass: teachingClass)
        }
    }

    /// Review info is keyed per *teaching class* (course code + class code), not
    /// per teacher, so two classes never share a review entry — even when they are
    /// taught by the same teacher or have no teacher listed.
    private func classReviewKey(courseCode: String, teachingClass: SchedulerTeachingClass) -> String {
        "\(courseCode)|\(teachingClass.code)"
    }

    private func teacherMatches(favorite: FavoriteCourse, teachingClass: SchedulerTeachingClass) -> Bool {
        let favoriteTokens = Self.teacherTokens(from: favorite.teacherName)
        // Without a teacher name we cannot disambiguate; treat as a match so the
        // favorite still surfaces rather than silently disappearing.
        guard !favoriteTokens.isEmpty else { return true }
        let classTokens = teachingClass.teacherMatchTokens
        guard !classTokens.isEmpty else { return false }
        return !favoriteTokens.isDisjoint(with: classTokens)
    }

    private static func teacherTokens(from value: String) -> Set<String> {
        Set(
            value
                .split(whereSeparator: { "/、,，; ；".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    public func timetableLookupClasses(
        for course: SchedulerCourseSummary,
        day: Int,
        section: Int
    ) -> [SchedulerTeachingClass] {
        (timetableLookupDetailsByCourseCode[course.courseCode] ?? [])
            .filter { $0.occupies(day: day, section: section) }
    }

    public func selectedClass(day: Int, section: Int) -> SchedulerSelectedClass? {
        selectedClasses.first { item in
            item.teachingClass.occupies(day: day, section: section)
        }
    }

    fileprivate func loadedCandidateClasses(
        day: Int,
        section: Int,
        excluding excluded: SchedulerSelectedClass? = nil
    ) -> [SchedulerClassCandidate] {
        searchResults.flatMap { course in
            (detailsByCourseCode[course.courseCode] ?? [])
                .filter { $0.occupies(day: day, section: section) }
                .map { SchedulerClassCandidate(course: course, teachingClass: $0) }
        }
        .filter { candidate in
            let selectedId = SchedulerSelectedClass(
                course: candidate.course,
                teachingClass: candidate.teachingClass
            ).id
            return selectedId != excluded?.id
        }
    }

    fileprivate func selectionState(
        course: SchedulerCourseSummary,
        teachingClass: SchedulerTeachingClass
    ) -> TeachingClassSelectionState {
        selectionState(course: course, teachingClass: teachingClass, replacing: nil)
    }

    fileprivate func selectionState(
        course: SchedulerCourseSummary,
        teachingClass: SchedulerTeachingClass,
        replacing selectedItem: SchedulerSelectedClass?
    ) -> TeachingClassSelectionState {
        let selectedClassId = SchedulerSelectedClass(course: course, teachingClass: teachingClass).id
        let comparableClasses = selectedItem.map { item in
            selectedClasses.filter { $0.id != item.id }
        } ?? selectedClasses
        if comparableClasses.contains(where: { $0.id == selectedClassId }) {
            return .selected
        }
        if comparableClasses.contains(where: { $0.course.courseCode == course.courseCode }) {
            return .sameCourseSelected
        }
        return .none
    }

    @discardableResult
    public func add(course: SchedulerCourseSummary, teachingClass: SchedulerTeachingClass) -> Bool {
        let candidate = SchedulerSelectedClass(course: course, teachingClass: teachingClass)
        if selectedClasses.contains(where: { $0.id == candidate.id }) {
            error = "这门教学班已经在课表中"
            return false
        }
        if let sameCourse = selectedClasses.first(where: { $0.course.courseCode == course.courseCode }) {
            error = "已选择 \(sameCourse.course.courseName)，请先移除原教学班"
            return false
        }
        if let conflict = selectedClasses.first(where: { $0.conflicts(with: candidate) }) {
            error = "\(course.courseName) 与 \(conflict.course.courseName) 时间冲突"
            return false
        }
        selectedClasses.append(candidate)
        persistSelectedClasses()
        return true
    }

    @discardableResult
    public func replace(
        _ selectedItem: SchedulerSelectedClass,
        course: SchedulerCourseSummary,
        teachingClass: SchedulerTeachingClass
    ) -> Bool {
        let candidate = SchedulerSelectedClass(course: course, teachingClass: teachingClass)
        guard selectedItem.id != candidate.id else {
            error = "这门教学班已经在课表中"
            return false
        }

        guard let replacementIndex = selectedClasses.firstIndex(where: { $0.id == selectedItem.id }) else {
            return add(course: course, teachingClass: teachingClass)
        }

        let remaining = selectedClasses.filter { $0.id != selectedItem.id }
        if remaining.contains(where: { $0.id == candidate.id }) {
            error = "这门教学班已经在课表中"
            return false
        }
        if let sameCourse = remaining.first(where: { $0.course.courseCode == course.courseCode }) {
            error = "已选择 \(sameCourse.course.courseName)，请先移除原教学班"
            return false
        }
        if let conflict = remaining.first(where: { $0.conflicts(with: candidate) }) {
            error = "\(course.courseName) 与 \(conflict.course.courseName) 时间冲突"
            return false
        }

        var updated = remaining
        updated.insert(candidate, at: min(replacementIndex, updated.count))
        selectedClasses = updated
        persistSelectedClasses()
        return true
    }

    public func remove(_ item: SchedulerSelectedClass) {
        selectedClasses.removeAll { $0.id == item.id }
        persistSelectedClasses()
    }

    public func remove(course: SchedulerCourseSummary, teachingClass: SchedulerTeachingClass) {
        remove(SchedulerSelectedClass(course: course, teachingClass: teachingClass))
    }

    public func clearSelectedClasses() {
        selectedClasses.removeAll()
        persistSelectedClasses()
    }

    public func clearPlannerData() {
        searchResults = []
        expandedCourseCode = nil
        detailsByCourseCode = [:]
        clearTimetableLookup()
        clearSelectedClasses()
    }

    public func dismissError() {
        error = nil
    }

    /// Run a sync check covering both selected and candidate classes.
    /// Run a sync check covering both selected and candidate classes.
    public func syncSelectedClasses() async {
        guard !isSyncing else { return }
        guard selectedCalendarId != 0 else {
            syncResult = nil
            unacknowledgedChangeCount = 0
            return
        }
        guard !selectedClasses.isEmpty || hasCandidateDetails else {
            syncResult = nil
            unacknowledgedChangeCount = 0
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let snapshot = syncEngine.captureCheckpoint(from: selectedClasses, calendarId: selectedCalendarId)
        let candidateCheckpoints = captureCandidateCheckpoints()
        var result = await syncEngine.sync(
            selectedSnapshot: snapshot,
            candidateCheckpoints: candidateCheckpoints,
            calendarId: selectedCalendarId
        )

        if result.changes.contains(where: { $0.changeType == .infoChanged && $0.detail.contains("上课安排") }) {
            let conflictChecked = await syncEngine.detectConflicts(
                changes: result.changes,
                selectedClasses: selectedClasses,
                calendarId: selectedCalendarId
            )
            result = SyncResult(changes: conflictChecked, checkedAt: result.checkedAt)
        }

        await applySyncUpdates(result.changes)
        syncResult = result

        let unacknowledged = syncStore.unacknowledgedChanges(in: result, checkpointId: snapshot.checkpointId)
        unacknowledgedChangeCount = unacknowledged.count
    }

    /// Mark all current unacknowledged changes as seen.
    public func acknowledgeSyncChanges() {
        guard let result = syncResult else { return }
        let ids = Set(result.changes.map(\.id))
        syncStore.acknowledgeChanges(ids, checkpointId: nil)
        unacknowledgedChangeCount = 0
    }

    /// Acknowledge changes and save the checkpoint ID to suppress future notifications for same data.
    public func acknowledgeAndSaveSyncCheckpoint() {
        guard let result = syncResult else { return }
        let snapshot = syncEngine.captureCheckpoint(from: selectedClasses, calendarId: selectedCalendarId)
        let ids = Set(result.changes.map(\.id))
        syncStore.acknowledgeChanges(ids, checkpointId: snapshot.checkpointId)
        unacknowledgedChangeCount = 0
    }

    public func scheduleEntry(day: Int, section: Int) -> SchedulerScheduleEntry? {
        for item in selectedClasses {
            for arrangement in item.teachingClass.arrangementInfo {
                guard arrangement.occupyDay == day else { continue }
                guard arrangement.occupyTime?.contains(section) == true else { continue }
                return SchedulerScheduleEntry(
                    courseName: item.course.courseName,
                    classCode: item.teachingClass.code,
                    campus: item.teachingClass.campus,
                    room: arrangement.occupyRoom,
                    weekText: arrangement.weekText
                )
            }
        }
        return nil
    }

    private var hasCandidateDetails: Bool {
        !detailsByCourseCode.values.allSatisfy(\.isEmpty)
    }

    private func captureCandidateCheckpoints() -> [SyncCheckpoint] {
        let courseMap = Dictionary(uniqueKeysWithValues: searchResults.map { ($0.courseCode, $0) })
        let selectedKeys = Set(selectedClasses.map(\.id))
        var checkpoints: [SyncCheckpoint] = []

        for (courseCode, classes) in detailsByCourseCode {
            guard let summary = courseMap[courseCode] else { continue }
            for tc in classes {
                let key = "\(courseCode)|\(tc.code)"
                guard !selectedKeys.contains(key) else { continue }
                checkpoints.append(SyncCheckpoint(
                    courseCode: courseCode,
                    courseName: summary.courseName,
                    credit: summary.credit,
                    classCode: tc.code,
                    teacherNames: tc.teacherNames,
                    campus: tc.campus,
                    teachingLanguage: tc.teachingLanguage,
                    arrangementHashes: tc.arrangementInfo.map { arr in
                        "\(arr.occupyDay ?? 0)-\(arr.occupyRoom ?? "")-\(arr.occupyTime ?? [])-\(arr.occupyWeek ?? [])"
                    },
                    isExclusive: tc.isExclusive,
                    capturedAt: Date()
                ))
            }
        }
        return checkpoints
    }

    private func applySyncUpdates(_ changes: [CourseChange]) async {
        let changedCourses = changes.filter { $0.changeType == .infoChanged || $0.changeType == .conflictAfterUpdate }
        guard !changedCourses.isEmpty else { return }

        let courseCodes = Array(Set(changedCourses.map(\.courseCode)))
        let freshData = await schedulerRepo.findCourseDetailsBatch(
            calendarId: selectedCalendarId,
            courseCodes: courseCodes
        )

        var didUpdate = false
        for change in changedCourses {
            guard let index = selectedClasses.firstIndex(where: {
                $0.course.courseCode == change.courseCode && $0.teachingClass.code == change.classCode
            }) else { continue }

            if change.changeType == .conflictAfterUpdate {
                // Deselect conflict courses (matching Web版 status=0)
                selectedClasses.remove(at: index)
                didUpdate = true
                continue
            }

            let freshClasses = freshData[change.courseCode] ?? []
            guard let freshClass = freshClasses.first(where: { $0.code == change.classCode }) else { continue }

            let existing = selectedClasses[index]
            if freshClass != existing.teachingClass {
                selectedClasses[index] = SchedulerSelectedClass(
                    course: existing.course,
                    teachingClass: freshClass
                )
                didUpdate = true
            }
        }

        // Always refresh the detail cache, even if no selections mutated
        detailsByCourseCode.merge(freshData) { _, new in new }
        if didUpdate {
            persistSelectedClasses()
        }
    }

    private var hasSearchCriteria: Bool {
        !courseName.trimmed.isEmpty
            || !courseCode.trimmed.isEmpty
            || !teacherName.trimmed.isEmpty
            || !selectedCampusId.isEmpty
            || !selectedFacultyId.isEmpty
    }

    private static func sectionGroup(for section: Int) -> Int {
        switch section {
        case 1, 2: 1
        case 3, 4: 2
        case 5, 6: 3
        case 7, 8: 4
        case 9: 5
        default: 6
        }
    }

    private func loadGrades() async {
        guard selectedCalendarId != 0, !isLoadingMajorOptions else { return }
        isLoadingMajorOptions = true
        defer { isLoadingMajorOptions = false }

        do {
            grades = try await schedulerRepo.findGrades(calendarId: selectedCalendarId)
            selectedGrade = grades.first ?? 0
            await loadMajors()
        } catch {
            logger.error("Failed to load scheduler grades: \(error.localizedDescription)")
        }
    }

    private func loadMajors() async {
        guard selectedCalendarId != 0, selectedGrade != 0 else { return }

        do {
            majors = try await schedulerRepo.findMajors(calendarId: selectedCalendarId, grade: selectedGrade)
            majorSearchText = ""
        } catch {
            logger.error("Failed to load scheduler majors: \(error.localizedDescription)")
        }
    }

    private func runSearch(_ operation: () async throws -> [SchedulerCourseSummary]) async {
        guard !isSearching else { return }
        isSearching = true
        error = nil
        expandedCourseCode = nil
        detailsByCourseCode = [:]
        candidateCampusFilter = ""
        clearTimetableLookup()
        defer { isSearching = false }

        do {
            searchResults = try await operation()
        } catch {
            logger.error("Scheduler search failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    private func hydrateClassReviewInfoInBackground(
        courseCode: String,
        classes: [SchedulerTeachingClass]
    ) {
        guard !classes.isEmpty else { return }
        Task { [weak self] in
            await self?.hydrateClassReviewInfo(courseCode: courseCode, classes: classes)
        }
    }

    private func hydrateClassReviewInfo(
        courseCode: String,
        classes: [SchedulerTeachingClass]
    ) async {
        for teachingClass in classes {
            let key = classReviewKey(courseCode: courseCode, teachingClass: teachingClass)
            if hydratedClassKeys.contains(key) { continue }
            let teacher = teachingClass.resolvedTeacher
            do {
                let detail = try await courseRepo.getCourseByCode(
                    code: courseCode,
                    teacherName: teacher?.teacherName,
                    teacherCode: teacher?.teacherCode
                )
                reviewInfoByClassKey[key] = SchedulerCourseReviewInfo(
                    course: detail,
                    isFavorite: favoriteStore.isFavorite(courseId: detail.id)
                )
                hydratedClassKeys.insert(key)
            } catch {
                logger.error("Failed to hydrate review info for \(courseCode) (\(teacher?.teacherName ?? "?")): \(error.localizedDescription)")
            }
        }
    }

    private func restoreSelectedClasses() {
        guard selectedCalendarId != 0 else {
            selectedClasses = []
            return
        }
        guard let data = UserDefaults.standard.data(forKey: selectedClassesStorageKey) else {
            selectedClasses = []
            return
        }

        do {
            let stored = try JSONDecoder().decode([String: [SchedulerSelectedClass]].self, from: data)
            selectedClasses = stored[String(selectedCalendarId)] ?? []
        } catch {
            selectedClasses = []
            logger.error("Failed to restore scheduler selections: \(error.localizedDescription)")
        }
    }

    private func persistSelectedClasses() {
        guard selectedCalendarId != 0 else { return }

        var stored: [String: [SchedulerSelectedClass]] = [:]
        if let data = UserDefaults.standard.data(forKey: selectedClassesStorageKey),
           let decoded = try? JSONDecoder().decode([String: [SchedulerSelectedClass]].self, from: data) {
            stored = decoded
        }

        stored[String(selectedCalendarId)] = selectedClasses

        do {
            let data = try JSONEncoder().encode(stored)
            UserDefaults.standard.set(data, forKey: selectedClassesStorageKey)
        } catch {
            logger.error("Failed to persist scheduler selections: \(error.localizedDescription)")
        }
    }

    private func clearTimetableLookup() {
        timetableLookupResults = []
        timetableLookupExpandedCourseCode = nil
        timetableLookupDetailsByCourseCode = [:]
        loadingTimetableLookupDetailsCourseCode = nil
        timetableLookupSlotId = nil
    }
}

public struct SchedulerScheduleEntry: Equatable, Sendable {
    public let courseName: String
    public let classCode: String
    public let campus: String
    public let room: String?
    public let weekText: String
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AppColors.cyan : Color(.systemGray6))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SchedulerCourseResultRow: View {
    let course: SchedulerCourseSummary
    let isExpanded: Bool
    let isLoading: Bool
    let classes: [SchedulerTeachingClass]
    let selectionState: (SchedulerTeachingClass) -> TeachingClassSelectionState
    let reviewInfo: (SchedulerTeachingClass) -> SchedulerCourseReviewInfo?
    let isFavorite: (SchedulerTeachingClass) -> Bool
    let onToggle: () -> Void
    let onAdd: (SchedulerTeachingClass) -> Void
    let onRemove: (SchedulerTeachingClass) -> Void
    let onShowReview: (SchedulerTeachingClass) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onToggle) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.courseName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(metaText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !natureText.isEmpty {
                            Text(natureText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    if isLoading {
                        ProgressView()
                    } else {
                        Label(classCountText, systemImage: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(AppColors.cyan)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "收起 \(course.courseName) 教学班" : "展开 \(course.courseName) 教学班")

            if isExpanded {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("正在加载教学班...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if classes.isEmpty {
                    Text("暂无可用教学班")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(classes) { teachingClass in
                            TeachingClassRow(
                                course: course,
                                teachingClass: teachingClass,
                                selectionState: selectionState(teachingClass),
                                reviewInfo: reviewInfo(teachingClass),
                                isFavorite: isFavorite(teachingClass),
                                onAdd: { onAdd(teachingClass) },
                                onRemove: { onRemove(teachingClass) },
                                onShowReview: { onShowReview(teachingClass) }
                            )
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var metaText: String {
        [course.courseCode, course.facultyI18n, creditText]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var natureText: String {
        (course.courseNature + course.campus).prefix(4).joined(separator: " / ")
    }

    private var classCountText: String {
        if isExpanded { return "收起" }
        return classes.isEmpty ? "教学班" : "\(classes.count) 班"
    }

    private var creditText: String {
        course.credit > 0 ? "\(course.credit.cleanText) 学分" : ""
    }
}

/// Per-teaching-class rating + favorite badge. Reviews target a specific
/// teacher's class, so this is shown inside each teaching class rather than once
/// for the whole course.
private struct SchedulerClassReviewBadge: View {
    let reviewInfo: SchedulerCourseReviewInfo?
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("已收藏")
            }

            Label(reviewInfo?.ratingText ?? "评课未关联", systemImage: "chart.bar.fill")
                .foregroundStyle(ratingColor)
                .labelStyle(.titleAndIcon)
        }
        .font(.caption2.weight(.medium))
    }

    private var ratingColor: Color {
        guard let reviewInfo, reviewInfo.reviewCount > 0 else { return .secondary }
        switch reviewInfo.rating {
        case 4.0...: return AppColors.positive
        case 3.0..<4.0: return .orange
        default: return AppColors.negative
        }
    }
}

private struct TeachingClassRow: View {
    let course: SchedulerCourseSummary
    let teachingClass: SchedulerTeachingClass
    let selectionState: TeachingClassSelectionState
    let reviewInfo: SchedulerCourseReviewInfo?
    let isFavorite: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void
    let onShowReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("教学班 \(teachingClass.code)")
                        .font(.subheadline.bold())
                    Text(teachingClass.teacherNames)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SchedulerClassReviewBadge(reviewInfo: reviewInfo, isFavorite: isFavorite)
                }

                Spacer(minLength: 8)

                Button(action: onSelectionTap) {
                    AppActionButtonLabel(actionTitle, systemImage: actionIcon)
                }
                .buttonStyle(AppActionButtonStyle(role: actionRole, size: .compact, fillsWidth: false))
                .disabled(selectionState == .sameCourseSelected)
            }

            if !teachingClass.campus.isEmpty || !teachingClass.teachingLanguage.isEmpty {
                Text([teachingClass.campus, teachingClass.teachingLanguage].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(teachingClass.arrangementInfo) { arrangement in
                Label(
                    "\(arrangement.dayName) \(arrangement.timeText) · \(arrangement.weekText)"
                        + (arrangement.occupyRoom.map { " · \($0)" } ?? ""),
                    systemImage: "calendar"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if let firstNote = teachingClass.detailNotes.first {
                Label(firstNote, systemImage: "note.text")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(rowBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(rowBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        // Tapping anywhere on the card (except the add/remove button) opens the
        // review detail for this specific teaching class.
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { onShowReview() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("查看 \(teachingClass.teacherNames) 的评课详情")
        .accessibilityAction(named: Text(selectionActionAccessibilityName)) {
            onSelectionTap()
        }
    }

    private func onSelectionTap() {
        switch selectionState {
        case .none: onAdd()
        case .selected: onRemove()
        case .sameCourseSelected: break
        }
    }

    private var selectionActionAccessibilityName: String {
        switch selectionState {
        case .none: "加入课表"
        case .selected: "取消选择"
        case .sameCourseSelected: "已选其他教学班"
        }
    }

    private var actionTitle: String {
        switch selectionState {
        case .none: "加课"
        case .selected: "已选"
        case .sameCourseSelected: "已选其他班"
        }
    }

    private var actionIcon: String {
        switch selectionState {
        case .none: "plus.circle"
        case .selected, .sameCourseSelected: "checkmark.circle.fill"
        }
    }

    private var actionRole: AppActionButtonStyle.Role {
        switch selectionState {
        case .none, .sameCourseSelected: .secondary
        case .selected: .primary
        }
    }

    private var rowBackground: Color {
        switch selectionState {
        case .none: AppColors.cyan.opacity(0.08)
        case .selected: AppColors.cyan.opacity(0.16)
        case .sameCourseSelected: Color.secondary.opacity(0.08)
        }
    }

    private var rowBorder: Color {
        switch selectionState {
        case .none: AppColors.cyan.opacity(0.16)
        case .selected: AppColors.cyan.opacity(0.32)
        case .sameCourseSelected: Color.secondary.opacity(0.18)
        }
    }
}

private struct SchedulerSlotSheet: View {
    let viewModel: SchedulerViewModel
    let slot: SchedulerTimetableSlot
    let onDismiss: () -> Void
    @State private var selectedPage: SchedulerSlotSheetPage = .candidates
    @State private var reviewTarget: SchedulerReviewTarget?
    @State private var ratingFilter: String = ""
    @State private var campusFilter: String = ""
    @State private var dayFilter: Int? = nil
    private var currentSelectedClass: SchedulerSelectedClass? {
        viewModel.selectedClass(day: slot.day, section: slot.section)
    }
    private var unfilteredCandidates: [SchedulerClassCandidate] {
        viewModel.loadedCandidateClasses(
            day: slot.day,
            section: slot.section,
            excluding: currentSelectedClass
        )
    }
    private var availableCampuses: [String] {
        let campuses = Set(unfilteredCandidates.map(\.teachingClass.campus))
            .filter { !$0.isEmpty }
        return Array(campuses).sorted()
    }
    private var availableDays: [Int] {
        let days = Set(
            unfilteredCandidates.flatMap { candidate in
                candidate.teachingClass.arrangementInfo.compactMap(\.occupyDay)
            }
        )
        return Array(days).sorted()
    }
    private var hasActiveFilters: Bool {
        !ratingFilter.isEmpty || !campusFilter.isEmpty || dayFilter != nil
    }
    private var filteredCandidates: [SchedulerClassCandidate] {
        unfilteredCandidates.filter { candidate in
            if !campusFilter.isEmpty, candidate.teachingClass.campus != campusFilter { return false }
            if !ratingFilter.isEmpty {
                guard let info = viewModel.reviewInfo(course: candidate.course, teachingClass: candidate.teachingClass) else { return false }
                if !allowedGradesForFilter(ratingFilter).contains(info.ratingGrade) { return false }
            }
            if let day = dayFilter, !candidate.teachingClass.arrangementInfo.contains(where: { $0.occupyDay == day }) { return false }
            return true
        }
    }
    private func allowedGradesForFilter(_ filter: String) -> Set<String> {
        switch filter {
        case "推荐+": return ["优秀", "推荐"]
        case "中等+": return ["优秀", "推荐", "中等"]
        case "谨慎": return ["谨慎"]
        default: return []
        }
    }
    private func dayName(_ day: Int) -> String {
        ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"][safe: day] ?? "未定"
    }
    private var ratingFilterRow: some View {
        Picker("评分筛选", selection: $ratingFilter) {
            Text("全部").tag("")
            Text("推荐+").tag("推荐+")
            Text("中等+").tag("中等+")
            Text("谨慎").tag("谨慎")
        }
        .pickerStyle(.segmented)
    }
    private var campusFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(title: "全部校区", isSelected: campusFilter.isEmpty) {
                    campusFilter = ""
                }
                ForEach(availableCampuses, id: \.self) { campus in
                    FilterChip(title: campus, isSelected: campusFilter == campus) {
                        campusFilter = campus
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    private var dayFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(title: "全部星期", isSelected: dayFilter == nil) {
                    dayFilter = nil
                }
                ForEach(availableDays, id: \.self) { day in
                    FilterChip(title: dayName(day), isSelected: dayFilter == day) {
                        dayFilter = day
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let selectedClass = viewModel.selectedClass(day: slot.day, section: slot.section) {
                    selectedClassSection(selectedClass)
                    loadedCandidateSection(replacing: selectedClass)
                } else {
                    Section {
                        Picker("查找范围", selection: $selectedPage) {
                            ForEach(SchedulerSlotSheetPage.allCases) { page in
                                Text(page.title).tag(page)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if selectedPage == .candidates {
                        Section {
                            ratingFilterRow
                            if availableCampuses.count > 1 {
                                campusFilterRow
                            }
                            if availableDays.count > 1 {
                                dayFilterRow
                            }
                        }
                    }

                    switch selectedPage {
                    case .candidates:
                        loadedCandidateSection(replacing: nil)
                    case .timeLookup:
                        timetableLookupSection
                    }
                }
            }
            .navigationTitle(slot.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $reviewTarget) { target in
                SchedulerCourseByCodeView(
                    courseCode: target.courseCode,
                    teacherName: target.teacherName,
                    teacherCode: target.teacherCode
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成", action: onDismiss)
                }
            }
            .task(id: "\(slot.id)-\(selectedPage.rawValue)") {
                guard viewModel.selectedClass(day: slot.day, section: slot.section) == nil else { return }
                guard selectedPage == .timeLookup else { return }
                await viewModel.loadTimetableLookup(day: slot.day, section: slot.section)
            }
        }
    }

    private func selectedClassSection(_ selectedClass: SchedulerSelectedClass) -> some View {
        Section("当前课程") {
            SchedulerSelectedClassSummaryRow(item: selectedClass)

            Button(role: .destructive) {
                viewModel.remove(selectedClass)
                onDismiss()
            } label: {
                AppActionButtonLabel("移除这门课", systemImage: "trash")
            }
            .buttonStyle(.appDestructiveAction)
        }
    }

    private func loadedCandidateSection(replacing selectedClass: SchedulerSelectedClass?) -> some View {
        let candidates = filteredCandidates
        let headerTitle = selectedClass == nil ? "该时段候选课程" : "可替换候选课程"

        return Section {
            if candidates.isEmpty && hasActiveFilters {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("没有匹配的课程")
                        .font(.headline)
                    Text("当前筛选条件下没有候选课程，请调整筛选条件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else if candidates.isEmpty {
                ContentUnavailableView(
                    selectedClass == nil ? "暂无候选课程" : "暂无可替换候选",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("候选页中已加载的教学班没有匹配这个时段。")
                )
            } else {
                ForEach(candidates) { candidate in
                    SchedulerSlotCandidateRow(
                        candidate: candidate,
                        selectionState: viewModel.selectionState(
                            course: candidate.course,
                            teachingClass: candidate.teachingClass,
                            replacing: selectedClass
                        ),
                        reviewInfo: viewModel.reviewInfo(
                            course: candidate.course,
                            teachingClass: candidate.teachingClass
                        ),
                        isFavorite: viewModel.isFavorite(
                            course: candidate.course,
                            teachingClass: candidate.teachingClass
                        ),
                        actionTitle: selectedClass == nil ? "加课" : "替换",
                        actionIcon: selectedClass == nil ? "plus.circle" : "arrow.triangle.2.circlepath",
                        onSelect: {
                            let didSucceed: Bool
                            if let selectedClass {
                                didSucceed = viewModel.replace(
                                    selectedClass,
                                    course: candidate.course,
                                    teachingClass: candidate.teachingClass
                                )
                            } else {
                                didSucceed = viewModel.add(
                                    course: candidate.course,
                                    teachingClass: candidate.teachingClass
                                )
                            }
                            if didSucceed {
                                onDismiss()
                            }
                        },
                        onShowReview: {
                            reviewTarget = SchedulerReviewTarget(
                                courseCode: candidate.course.courseCode,
                                teachingClass: candidate.teachingClass
                            )
                        }
                    )
                }
            }
        } header: {
            if hasActiveFilters {
                HStack {
                    Text(headerTitle)
                    Spacer()
                    Text("\(candidates.count)/\(unfilteredCandidates.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppColors.cyan.opacity(0.15))
                        .clipShape(Capsule())
                }
            } else {
                Text(headerTitle)
            }
        }
    }

    @ViewBuilder
    private var timetableLookupSection: some View {
        Section {
            if viewModel.isLoadingTimetableLookup {
                HStack {
                    ProgressView()
                    Text("正在查询这个时段的课程...")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.timetableLookupResults.isEmpty {
                ContentUnavailableView(
                    "暂无课程",
                    systemImage: "clock.badge.questionmark",
                    description: Text("后端未返回这个时段的可选课程。")
                )
            } else {
                ForEach(viewModel.timetableLookupResults) { course in
                    SchedulerCourseResultRow(
                        course: course,
                        isExpanded: viewModel.timetableLookupExpandedCourseCode == course.courseCode,
                        isLoading: viewModel.loadingTimetableLookupDetailsCourseCode == course.courseCode,
                        classes: viewModel.timetableLookupClasses(
                            for: course,
                            day: slot.day,
                            section: slot.section
                        ),
                        selectionState: { teachingClass in
                            viewModel.selectionState(course: course, teachingClass: teachingClass)
                        },
                        reviewInfo: { teachingClass in
                            viewModel.reviewInfo(course: course, teachingClass: teachingClass)
                        },
                        isFavorite: { teachingClass in
                            viewModel.isFavorite(course: course, teachingClass: teachingClass)
                        },
                        onToggle: {
                            Task {
                                await viewModel.toggleTimetableLookupDetails(
                                    for: course,
                                    day: slot.day,
                                    section: slot.section
                                )
                            }
                        },
                        onAdd: { teachingClass in
                            if viewModel.add(course: course, teachingClass: teachingClass) {
                                onDismiss()
                            }
                        },
                        onRemove: { teachingClass in
                            viewModel.remove(course: course, teachingClass: teachingClass)
                        },
                        onShowReview: { teachingClass in
                            reviewTarget = SchedulerReviewTarget(
                                courseCode: course.courseCode,
                                teachingClass: teachingClass
                            )
                        }
                    )
                }
            }
        } header: {
            Text("空段找课")
        } footer: {
            Text("空段找课按该课节所属大节查询，展开课程后可选择具体教学班。")
        }
    }
}

private enum SchedulerCourseByCodePhase: Equatable {
    case loading
    case loaded(Int)
    case failed(String)
}

private struct SchedulerCourseByCodeView: View {
    let courseCode: String
    let teacherName: String?
    let teacherCode: String?

    @State private var phase: SchedulerCourseByCodePhase = .loading
    private let repository = CourseRepository()

    init(
        courseCode: String,
        teacherName: String? = nil,
        teacherCode: String? = nil
    ) {
        self.courseCode = courseCode
        self.teacherName = teacherName?.trimmed.nilIfEmpty
        self.teacherCode = teacherCode?.trimmed.nilIfEmpty
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                LoadingView(message: "正在查找评课...")
            case .loaded(let courseId):
                // The user already picked a specific teaching class, so don't show
                // the "same course other teachers" related section (which lists the
                // course's other parallel teaching classes).
                CourseDetailView(courseId: courseId, showsRelatedCourses: false)
            case .failed(let message):
                ErrorStateView(message: message) {
                    Task { await load() }
                }
            }
        }
        .navigationTitle("评课")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: lookupKey) {
            await load()
        }
    }

    private var lookupKey: String {
        [courseCode, teacherName ?? "", teacherCode ?? ""].joined(separator: "|")
    }

    @MainActor
    private func load() async {
        phase = .loading
        do {
            let detail = try await repository.getCourseByCode(
                code: courseCode,
                teacherName: teacherName,
                teacherCode: teacherCode
            )
            phase = .loaded(detail.id)
        } catch {
            phase = .failed("没有找到这门课的评课数据，或网络请求失败。")
        }
    }
}

private struct SchedulerFavoriteImportSheet: View {
    let viewModel: SchedulerViewModel
    let onDismiss: () -> Void
    @State private var message: String?
    @State private var importingCode: String?
    @State private var isImportingAll = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.favoriteCourses.isEmpty {
                    ContentUnavailableView(
                        "暂无收藏课程",
                        systemImage: "star",
                        description: Text("在评课详情页点击收藏后，可将课程导入排课候选。")
                    )
                } else {
                    Section {
                        Button {
                            Task { await importAll() }
                        } label: {
                            AppActionButtonLabel(
                                isImportingAll ? "正在导入..." : "导入全部收藏",
                                systemImage: "square.and.arrow.down",
                                isLoading: isImportingAll
                            )
                        }
                        .disabled(isImportingAll || importingCode != nil)

                        if let message {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("收藏是针对教学班（课程 + 教师）的。导入会带入本学期该教师的教学班；若本学期没有对应教学班则会导入失败。")
                    }

                    Section("收藏课程") {
                        ForEach(viewModel.favoriteCourses) { favorite in
                            SchedulerFavoriteImportRow(
                                favorite: favorite,
                                isImported: viewModel.searchResults.contains { $0.courseCode == favorite.code },
                                isImporting: importingCode == favorite.code,
                                onImport: {
                                    Task { await importOne(favorite) }
                                }
                            )
                            .disabled(isImportingAll)
                        }
                    }
                }
            }
            .navigationTitle("导入收藏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成", action: onDismiss)
                }
            }
            .onAppear {
                viewModel.refreshFavorites()
            }
        }
    }

    private func importOne(_ favorite: FavoriteCourse) async {
        guard importingCode == nil, !isImportingAll else { return }
        importingCode = favorite.code
        defer { importingCode = nil }

        switch await viewModel.importFavorite(favorite) {
        case .imported:
            message = "已导入 \(favorite.name)（\(favorite.teacherName)）"
        case .alreadyPresent:
            message = "\(favorite.name) 已在候选中"
        case .noTeachingClass:
            message = "本学期没有 \(favorite.teacherName) 的「\(favorite.name)」教学班，导入失败"
        case .failed(let reason):
            message = reason
        }
    }

    private func importAll() async {
        guard !isImportingAll, importingCode == nil else { return }
        isImportingAll = true
        defer { isImportingAll = false }

        let result = await viewModel.importAllFavorites()
        var parts: [String] = []
        if result.imported > 0 { parts.append("已导入 \(result.imported) 门") }
        if result.skipped > 0 { parts.append("\(result.skipped) 门已在候选") }
        if result.failed > 0 { parts.append("\(result.failed) 门无教学班") }
        message = parts.isEmpty ? "没有可导入的收藏课程" : parts.joined(separator: "，")
    }
}

private struct SchedulerFavoriteImportRow: View {
    let favorite: FavoriteCourse
    let isImported: Bool
    let isImporting: Bool
    let onImport: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.name)
                    .font(.subheadline.weight(.semibold))
                Text([favorite.code, favorite.teacherName, favorite.department].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Label(ratingText, systemImage: "chart.bar.fill")
                    if favorite.credit > 0 {
                        Label("\(favorite.credit.cleanText) 学分", systemImage: "number")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onImport) {
                AppActionButtonLabel(
                    isImported ? "已导入" : "导入",
                    systemImage: isImported ? "checkmark.circle.fill" : "plus.circle",
                    isLoading: isImporting
                )
            }
            .buttonStyle(AppActionButtonStyle(role: isImported ? .primary : .secondary, size: .compact, fillsWidth: false))
            .disabled(isImported || isImporting)
        }
        .padding(.vertical, 4)
    }

    private var ratingText: String {
        guard favorite.reviewCount > 0 else { return "暂无评课" }
        return "\(String(format: "%.1f", favorite.rating)) · \(favorite.reviewCount) 评"
    }
}

private struct SchedulerSelectedClassSummaryRow: View {
    let item: SchedulerSelectedClass

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.course.courseName)
                .font(.headline)
            Text("\(item.course.courseCode) · \(item.teachingClass.code)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(item.teachingClass.teacherNames)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(item.teachingClass.scheduleSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
            SchedulerTeachingClassDetailBlock(teachingClass: item.teachingClass)
        }
        .padding(.vertical, 4)
    }
}

private struct SchedulerTeachingClassDetailBlock: View {
    let teachingClass: SchedulerTeachingClass

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !teachingClass.campus.isEmpty || !teachingClass.teachingLanguage.isEmpty || teachingClass.isExclusive {
                HStack(spacing: 8) {
                    if !teachingClass.campus.isEmpty {
                        Label(teachingClass.campus, systemImage: "mappin.and.ellipse")
                    }
                    if !teachingClass.teachingLanguage.isEmpty {
                        Label(teachingClass.teachingLanguage, systemImage: "globe.asia.australia")
                    }
                    if teachingClass.isExclusive {
                        Label("专属", systemImage: "lock")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if let remark = teachingClass.remark {
                Label(remark, systemImage: "note.text")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if teachingClass.arrangementInfo.isEmpty {
                Label("时间地点未定", systemImage: "calendar.badge.questionmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(teachingClass.arrangementInfo) { arrangement in
                    SchedulerArrangementDetailRow(arrangement: arrangement)
                }
            }
        }
    }
}

private struct SchedulerArrangementDetailRow: View {
    let arrangement: SchedulerArrangement

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(summaryText, systemImage: "calendar")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            ForEach(arrangement.detailLines, id: \.self) { line in
                Text(line)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var summaryText: String {
        [
            Optional(arrangement.dayName),
            Optional(arrangement.timeText),
            Optional(arrangement.weekText),
            arrangement.occupyRoom
        ]
        .compactMap { $0?.trimmed.nilIfEmpty }
        .joined(separator: " · ")
    }
}

private struct SchedulerSlotCandidateRow: View {
    let candidate: SchedulerClassCandidate
    let selectionState: TeachingClassSelectionState
    let reviewInfo: SchedulerCourseReviewInfo?
    let isFavorite: Bool
    let actionTitle: String
    let actionIcon: String
    let onSelect: () -> Void
    let onShowReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.course.courseName)
                        .font(.subheadline.weight(.semibold))
                    Text("\(candidate.course.courseCode) · 教学班 \(candidate.teachingClass.code)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(candidate.teachingClass.teacherNames)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SchedulerClassReviewBadge(reviewInfo: reviewInfo, isFavorite: isFavorite)
                }

                Spacer(minLength: 8)

                Button(action: onSelect) {
                    AppActionButtonLabel(displayActionTitle, systemImage: displayActionIcon)
                }
                .buttonStyle(AppActionButtonStyle(role: actionRole, size: .compact, fillsWidth: false))
                .disabled(selectionState != .none)
            }

            SchedulerTeachingClassDetailBlock(teachingClass: candidate.teachingClass)
        }
        .padding(.vertical, 4)
        // Tap anywhere on the card (except the action button) to view the review.
        .contentShape(Rectangle())
        .onTapGesture { onShowReview() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("查看 \(candidate.teachingClass.teacherNames) 的评课详情")
        .accessibilityAction(named: Text(displayActionTitle)) {
            if selectionState == .none { onSelect() }
        }
    }

    private var displayActionTitle: String {
        switch selectionState {
        case .none: actionTitle
        case .selected: "已选"
        case .sameCourseSelected: "已选其他班"
        }
    }

    private var displayActionIcon: String {
        switch selectionState {
        case .none: actionIcon
        case .selected, .sameCourseSelected: "checkmark.circle.fill"
        }
    }

    private var actionRole: AppActionButtonStyle.Role {
        switch selectionState {
        case .none: .secondary
        case .selected: .primary
        case .sameCourseSelected: .secondary
        }
    }
}

private struct TimetableCell: View {
    let entry: SchedulerScheduleEntry?

    var body: some View {
        Group {
            if let entry {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.courseName)
                        .font(.caption2.bold())
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(entry.classCode)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let room = entry.room, !room.isEmpty {
                        Text(room)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if !entry.campus.isEmpty {
                        Text(entry.campus)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(5)
                .background(AppColors.cyan.opacity(0.14))
            } else {
                Text("")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.06))
            }
        }
        .frame(width: 92, height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private extension SchedulerTeachingClass {
    var primaryTeacher: SchedulerTeacher? {
        teachers.first { !$0.teacherName.trimmed.isEmpty || !$0.teacherCode.trimmed.isEmpty }
    }

    /// Best-effort teacher for review lookup. Prefers the structured `teachers`
    /// list, but falls back to parsing the name out of an arrangement's
    /// `teacherAndCode` (e.g. "张老师 1001") when the list is empty — otherwise
    /// every class of the course would resolve to the same (nil) teacher and
    /// share one review page.
    var resolvedTeacher: SchedulerTeacher? {
        if let teacher = primaryTeacher {
            return teacher
        }
        for arrangement in arrangementInfo {
            guard let raw = arrangement.teacherAndCode?.trimmed, !raw.isEmpty else { continue }
            let firstEntry = raw.split(separator: ",").first.map(String.init) ?? raw
            // The numeric suffix is not the review system's teacher code, so only
            // the name is reliable here.
            let name = firstEntry.split(separator: " ").first.map(String.init) ?? firstEntry
            let trimmedName = name.trimmed
            if !trimmedName.isEmpty {
                return SchedulerTeacher(teacherCode: "", teacherName: trimmedName)
            }
        }
        return nil
    }

    /// Teacher name tokens used for matching favorites to teaching classes.
    var teacherMatchTokens: Set<String> {
        let listed = Set(teachers.flatMap { Self.nameTokens(from: $0.teacherName) })
        if !listed.isEmpty { return listed }
        if let resolved = resolvedTeacher {
            return Self.nameTokens(from: resolved.teacherName)
        }
        return []
    }

    private static func nameTokens(from value: String) -> Set<String> {
        Set(
            value
                .split(whereSeparator: { "/、,，; ；".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    func occupies(day: Int, section: Int) -> Bool {
        arrangementInfo.contains { arrangement in
            arrangement.occupyDay == day && arrangement.occupyTime?.contains(section) == true
        }
    }
}

private extension SchedulerCourseSummary {
    init(favorite: FavoriteCourse) {
        self.init(
            courseCode: favorite.code,
            courseName: favorite.name,
            faculty: favorite.department,
            facultyI18n: favorite.department,
            courseNature: [],
            campus: [],
            credit: favorite.credit
        )
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

private extension Double {
    var cleanText: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(format: "%.1f", self)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Sync Change Sheet

struct SyncChangeSheet: View {
    let viewModel: SchedulerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let result = viewModel.syncResult, result.hasChanges {
                    ForEach(result.changes) { change in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(change.courseName)
                                    .font(.headline)
                                Spacer()
                                changeBadge(change.changeType)
                            }
                            Text("教学班 \(change.classCode)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(change.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    ContentUnavailableView(
                        "暂无课程变动",
                        systemImage: "checkmark.circle",
                        description: Text("所有已选课程与后端数据一致")
                    )
                }
            }
            .navigationTitle("课程变动检测")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("我已了解") {
                        viewModel.acknowledgeAndSaveSyncCheckpoint()
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func changeBadge(_ type: CourseChangeType) -> some View {
        switch type {
        case .closed:
            Text("已关闭").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                .background(.red.opacity(0.15)).foregroundStyle(.red).clipShape(Capsule())
        case .infoChanged:
            Text("已变更").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                .background(.orange.opacity(0.15)).foregroundStyle(.orange).clipShape(Capsule())
        case .conflictAfterUpdate:
            Text("冲突").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                .background(.red.opacity(0.15)).foregroundStyle(.red).clipShape(Capsule())
        }
    }
}

#Preview {
    SchedulerView()
}
