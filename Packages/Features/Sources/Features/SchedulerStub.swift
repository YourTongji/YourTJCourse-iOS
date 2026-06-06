import Foundation
import SwiftUI
import Observation
import DomainKit
import DataKit
import DesignSystem
import Platform

public typealias SchedulerStubView = SchedulerView

public struct SchedulerView: View {
    @State private var viewModel = SchedulerViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                filterSection
                majorSection
                timeLookupSection
                selectedSection
                timetableSection
                resultsSection
            }
            .navigationTitle("排课")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .onChange(of: viewModel.selectedCalendarId) { _, _ in
                Task { await viewModel.calendarChanged() }
            }
            .onChange(of: viewModel.selectedGrade) { _, _ in
                Task { await viewModel.gradeChanged() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.clearSelectedClasses()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.selectedClasses.isEmpty)
                    .accessibilityLabel("清空已选课程")
                }
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
                Task { await viewModel.search() }
            } label: {
                schedulerButtonLabel(
                    viewModel.isSearching ? "搜索中..." : "搜索课程",
                    systemImage: "magnifyingglass"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .controlSize(.large)
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
                Task { await viewModel.loadMajorCourses() }
            } label: {
                schedulerButtonLabel(
                    viewModel.isLoadingMajorCourses ? "加载中..." : "加载专业课表",
                    systemImage: "list.bullet.rectangle"
                )
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
            .controlSize(.large)
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
                Task { await viewModel.findCoursesBySelectedTime() }
            } label: {
                schedulerButtonLabel("按时间找可选课", systemImage: "clock")
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
            .controlSize(.large)
            .disabled(viewModel.isSearching || viewModel.selectedCalendarId == 0)
        } header: {
            Text("空段找课")
        } footer: {
            Text("按后端可选课程范围查询，不会自动避开已选课程冲突；加课时会再次检测。")
        }
    }

    @ViewBuilder
    private var selectedSection: some View {
        if !viewModel.selectedClasses.isEmpty {
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
                                TimetableCell(entry: viewModel.scheduleEntry(day: day, section: section))
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

    private func schedulerButtonLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .font(.headline)
        .frame(maxWidth: .infinity, minHeight: 44)
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
    private let selectedClassesStorageKey = "com.yourtj.course.scheduler.selectedClassesByCalendar"

    public init(schedulerRepo: SchedulerRepository = .init()) {
        self.schedulerRepo = schedulerRepo
    }

    public var canSearch: Bool {
        selectedCalendarId != 0 && hasSearchCriteria
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

    public func add(course: SchedulerCourseSummary, teachingClass: SchedulerTeachingClass) {
        let candidate = SchedulerSelectedClass(course: course, teachingClass: teachingClass)
        if selectedClasses.contains(where: { $0.id == candidate.id }) {
            error = "这门教学班已经在课表中"
            return
        }
        if let sameCourse = selectedClasses.first(where: { $0.course.courseCode == course.courseCode }) {
            error = "已选择 \(sameCourse.course.courseName)，请先移除原教学班"
            return
        }
        if let conflict = selectedClasses.first(where: { $0.conflicts(with: candidate) }) {
            error = "\(course.courseName) 与 \(conflict.course.courseName) 时间冲突"
            return
        }
        selectedClasses.append(candidate)
        persistSelectedClasses()
    }

    public func remove(_ item: SchedulerSelectedClass) {
        selectedClasses.removeAll { $0.id == item.id }
        persistSelectedClasses()
    }

    public func clearSelectedClasses() {
        selectedClasses.removeAll()
        persistSelectedClasses()
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
                            TeachingClassRow(teachingClass: teachingClass) {
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
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                        Text("加课")
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(.cyan)
                .controlSize(.small)
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
        .background(AppColors.cyanLight.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

#Preview {
    SchedulerView()
}
