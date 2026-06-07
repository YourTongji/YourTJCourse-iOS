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

public struct SchedulerView: View {
    @State private var viewModel: SchedulerViewModel
    @State private var selectedPage: SchedulerPage = .filters
    @State private var activeTimetableSlot: SchedulerTimetableSlot?
    @State private var showsClearConfirmation = false

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
            .task { await viewModel.load() }
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

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .filters:
            List {
                filterSection
                majorSection
                timeLookupSection
            }
            .refreshable { await viewModel.load() }

        case .candidates:
            List {
                resultsSection
            }
            .refreshable { await viewModel.load() }

        case .selected:
            List {
                selectedPageSection
            }
            .refreshable { await viewModel.load() }

        case .timetable:
            List {
                timetableSection
            }
            .refreshable { await viewModel.load() }
        }
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

            Picker("专业", selection: $viewModel.selectedMajorCode) {
                Text("未选择").tag("")
                ForEach(viewModel.majors) { major in
                    Text("\(major.code) \(major.name)").tag(major.code)
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
                ForEach(viewModel.searchResults) { course in
                    SchedulerCourseResultRow(
                        course: course,
                        isExpanded: viewModel.expandedCourseCode == course.courseCode,
                        isLoading: viewModel.loadingDetailsCourseCode == course.courseCode,
                        classes: viewModel.classes(for: course),
                        selectionState: { teachingClass in
                            viewModel.selectionState(course: course, teachingClass: teachingClass)
                        },
                        onToggle: {
                            Task { await viewModel.toggleDetails(for: course) }
                        },
                        onAdd: { teachingClass in
                            viewModel.add(course: course, teachingClass: teachingClass)
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

    private let schedulerRepo: SchedulerRepository
    private let logger = AppLogger(category: "Scheduler")
    private var detailsByCourseCode: [String: [SchedulerTeachingClass]] = [:]
    private var timetableLookupDetailsByCourseCode: [String: [SchedulerTeachingClass]] = [:]
    private var timetableLookupSlotId: String?
    private let selectedClassesStorageKey = "com.yourtj.course.scheduler.selectedClassesByCalendar"

    public init(schedulerRepo: SchedulerRepository = .init()) {
        self.schedulerRepo = schedulerRepo
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
        guard timetableLookupDetailsByCourseCode[course.courseCode] == nil else { return }
        loadingTimetableLookupDetailsCourseCode = course.courseCode
        defer { loadingTimetableLookupDetailsCourseCode = nil }

        do {
            timetableLookupDetailsByCourseCode[course.courseCode] = try await schedulerRepo.findCourseDetails(
                calendarId: selectedCalendarId,
                courseCode: course.courseCode
            )
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
        guard detailsByCourseCode[course.courseCode] == nil else { return }
        loadingDetailsCourseCode = course.courseCode
        defer { loadingDetailsCourseCode = nil }

        do {
            detailsByCourseCode[course.courseCode] = try await schedulerRepo.findCourseDetails(
                calendarId: selectedCalendarId,
                courseCode: course.courseCode
            )
        } catch {
            logger.error("Failed to load scheduler course details: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    public func classes(for course: SchedulerCourseSummary) -> [SchedulerTeachingClass] {
        detailsByCourseCode[course.courseCode] ?? []
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

    public func scheduleEntry(day: Int, section: Int) -> SchedulerScheduleEntry? {
        for item in selectedClasses {
            for arrangement in item.teachingClass.arrangementInfo {
                guard arrangement.occupyDay == day else { continue }
                guard arrangement.occupyTime?.contains(section) == true else { continue }
                return SchedulerScheduleEntry(
                    courseName: item.course.courseName,
                    classCode: item.teachingClass.code,
                    room: arrangement.occupyRoom,
                    weekText: arrangement.weekText
                )
            }
        }
        return nil
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
            selectedMajorCode = majors.first?.code ?? ""
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
        clearTimetableLookup()
        defer { isSearching = false }

        do {
            searchResults = try await operation()
        } catch {
            logger.error("Scheduler search failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
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
    public let room: String?
    public let weekText: String
}

private struct SchedulerCourseResultRow: View {
    let course: SchedulerCourseSummary
    let isExpanded: Bool
    let isLoading: Bool
    let classes: [SchedulerTeachingClass]
    let selectionState: (SchedulerTeachingClass) -> TeachingClassSelectionState
    let onToggle: () -> Void
    let onAdd: (SchedulerTeachingClass) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(course.courseName)
                        .font(.headline)
                    Text([course.courseCode, course.facultyI18n, creditText].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !course.courseNature.isEmpty || !course.campus.isEmpty {
                        Text((course.courseNature + course.campus).prefix(4).joined(separator: " / "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: onToggle) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "收起教学班" : "展开教学班")
            }

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
                                teachingClass: teachingClass,
                                selectionState: selectionState(teachingClass)
                            ) {
                                onAdd(teachingClass)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var creditText: String {
        course.credit > 0 ? "\(course.credit.cleanText) 学分" : ""
    }
}

private struct TeachingClassRow: View {
    let teachingClass: SchedulerTeachingClass
    let selectionState: TeachingClassSelectionState
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("教学班 \(teachingClass.code)")
                        .font(.subheadline.bold())
                    Text(teachingClass.teacherNames)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onAdd) {
                    AppActionButtonLabel(actionTitle, systemImage: actionIcon)
                }
                .buttonStyle(AppActionButtonStyle(role: actionRole, size: .compact, fillsWidth: false))
                .disabled(selectionState != .none)
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
        }
        .padding(10)
        .background(rowBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(rowBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        let candidates = viewModel.loadedCandidateClasses(
            day: slot.day,
            section: slot.section,
            excluding: selectedClass
        )

        return Section(selectedClass == nil ? "该时段候选课程" : "可替换候选课程") {
            if candidates.isEmpty {
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
                        }
                    )
                }
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
        }
        .padding(.vertical, 4)
    }
}

private struct SchedulerSlotCandidateRow: View {
    let candidate: SchedulerClassCandidate
    let selectionState: TeachingClassSelectionState
    let actionTitle: String
    let actionIcon: String
    let onSelect: () -> Void

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
                }

                Spacer()

                Button(action: onSelect) {
                    AppActionButtonLabel(displayActionTitle, systemImage: displayActionIcon)
                }
                .buttonStyle(AppActionButtonStyle(role: actionRole, size: .compact, fillsWidth: false))
                .disabled(selectionState != .none)
            }

            Text(candidate.teachingClass.scheduleSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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
    func occupies(day: Int, section: Int) -> Bool {
        arrangementInfo.contains { arrangement in
            arrangement.occupyDay == day && arrangement.occupyTime?.contains(section) == true
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
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

#Preview {
    SchedulerView()
}
