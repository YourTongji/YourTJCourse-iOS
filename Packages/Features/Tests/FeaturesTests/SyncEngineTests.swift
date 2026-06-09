import Testing
import Foundation
import DomainKit
@testable import Features

// MARK: - Mock Provider

final class MockCourseDetailProvider: CourseDetailProvider, @unchecked Sendable {
    var stubbedResult: [String: [SchedulerTeachingClass]] = [:]

    func findCourseDetailsBatch(calendarId: Int, courseCodes: [String]) async -> [String: [SchedulerTeachingClass]] {
        stubbedResult
    }
}

// MARK: - Fixtures

let sampleTeacher = SchedulerTeacher(teacherCode: "T001", teacherName: "张教授")
let sampleCourse = SchedulerCourseSummary(
    courseCode: "CS101", courseName: "数据结构", faculty: "计算机",
    facultyI18n: "计算机系", courseNature: ["专业必修"], campus: ["四平路"], credit: 4.0
)

func makeTeachingClass(
    code: String = "001",
    teacherNames: String = "张教授",
    campus: String = "四平路",
    teachingLanguage: String = "中文",
    isExclusive: Bool = false,
    arrangementInfo: [SchedulerArrangement] = []
) -> SchedulerTeachingClass {
    let teachers = teacherNames.components(separatedBy: " / ").enumerated().map { i, name in
        SchedulerTeacher(teacherCode: "T\(i)", teacherName: name)
    }
    return SchedulerTeachingClass(
        code: code,
        teachers: teachers,
        campus: campus,
        teachingLanguage: teachingLanguage,
        arrangementInfo: arrangementInfo,
        isExclusive: isExclusive
    )
}

func makeArrangement(day: Int = 1, time: [Int] = [1, 2], room: String = "A101", week: [Int] = [1, 2, 3, 4]) -> SchedulerArrangement {
    SchedulerArrangement(
        occupyDay: day,
        occupyTime: time,
        occupyRoom: room,
        occupyWeek: week,
        weekText: "1-4周"
    )
}

// MARK: - Tests

@Test("captureCheckpoint produces correct Snapshots")
func captureCheckpoint() {
    let engine = SyncEngine()
    let tc = makeTeachingClass()
    let selected = SchedulerSelectedClass(course: sampleCourse, teachingClass: tc)
    let snapshot = engine.captureCheckpoint(from: [selected], calendarId: 1)

    #expect(snapshot.calendarId == 1)
    #expect(snapshot.checkpoints.count == 1)
    #expect(snapshot.checkpoints[0].courseCode == "CS101")
    #expect(snapshot.checkpoints[0].classCode == "001")
    #expect(snapshot.checkpoints[0].teacherNames == "张教授")
    #expect(snapshot.checkpoints[0].campus == "四平路")
    #expect(snapshot.checkpoints[0].isExclusive == false)
}

@Test("sync with identical data produces no changes")
func syncNoChanges() async {
    let arr = makeArrangement()
    let tc = makeTeachingClass(code: "001", arrangementInfo: [arr])
    let selected = SchedulerSelectedClass(course: sampleCourse, teachingClass: tc)

    // Provider returns identical data
    let mock = MockCourseDetailProvider()
    mock.stubbedResult = ["CS101": [tc]]

    let engine = SyncEngine(repo: mock)
    let snapshot = engine.captureCheckpoint(from: [selected], calendarId: 1)
    let result = await engine.sync(snapshot: snapshot, calendarId: 1)

    #expect(result.hasChanges == false)
    #expect(result.changes.isEmpty)
}

@Test("sync detects teacher change")
func syncTeacherChange() async {
    let oldTc = makeTeachingClass(code: "001", teacherNames: "李老师")
    let newTc = makeTeachingClass(code: "001", teacherNames: "张教授")
    let selected = SchedulerSelectedClass(course: sampleCourse, teachingClass: oldTc)

    let mock = MockCourseDetailProvider()
    mock.stubbedResult = ["CS101": [newTc]]

    let engine = SyncEngine(repo: mock)
    let snapshot = engine.captureCheckpoint(from: [selected], calendarId: 1)
    let result = await engine.sync(snapshot: snapshot, calendarId: 1)

    #expect(result.hasChanges == true)
    #expect(result.changes.count == 1)
    #expect(result.changes[0].changeType == .infoChanged)
    #expect(result.changes[0].detail.contains("授课教师"))
    #expect(result.changes[0].detail.contains("李老师"))
    #expect(result.changes[0].detail.contains("张教授"))
}

@Test("sync detects arrangement change")
func syncArrangementChange() async {
    let oldArr = makeArrangement(day: 1, room: "A101")
    let newArr = makeArrangement(day: 2, room: "B201")
    let oldTc = makeTeachingClass(code: "001", arrangementInfo: [oldArr])
    let newTc = makeTeachingClass(code: "001", arrangementInfo: [newArr])
    let selected = SchedulerSelectedClass(course: sampleCourse, teachingClass: oldTc)

    let mock = MockCourseDetailProvider()
    mock.stubbedResult = ["CS101": [newTc]]

    let engine = SyncEngine(repo: mock)
    let snapshot = engine.captureCheckpoint(from: [selected], calendarId: 1)
    let result = await engine.sync(snapshot: snapshot, calendarId: 1)

    #expect(result.hasChanges == true)
    #expect(result.changes[0].changeType == .infoChanged)
    #expect(result.changes[0].detail.contains("上课安排"))
}

@Test("sync detects closed class")
func syncClosedClass() async {
    let oldTc = makeTeachingClass(code: "001")
    let selected = SchedulerSelectedClass(course: sampleCourse, teachingClass: oldTc)

    // Provider returns empty — class no longer exists
    let mock = MockCourseDetailProvider()
    mock.stubbedResult = ["CS101": []]

    let engine = SyncEngine(repo: mock)
    let snapshot = engine.captureCheckpoint(from: [selected], calendarId: 1)
    let result = await engine.sync(snapshot: snapshot, calendarId: 1)

    #expect(result.hasChanges == true)
    #expect(result.changes.count == 1)
    #expect(result.changes[0].changeType == .closed)
}

@Test("sync with empty checkpoints returns empty result")
func syncEmptyCheckpoints() async {
    let mock = MockCourseDetailProvider()
    let engine = SyncEngine(repo: mock)

    let snapshot = SyncSnapshot(checkpointId: "empty", calendarId: 1, checkpoints: [], capturedAt: Date())
    let result = await engine.sync(snapshot: snapshot, calendarId: 1)

    #expect(result.hasChanges == false)
    #expect(result.changes.isEmpty)
}

@Test("detectConflicts with no related selected classes produces no conflicts")
func detectConflictsNoConflict() async {
    let arr = makeArrangement(day: 1, time: [1, 2])
    let tc = makeTeachingClass(code: "001", arrangementInfo: [arr])
    let arr2 = makeArrangement(day: 3, time: [5, 6])
    let selected = SchedulerSelectedClass(
        course: sampleCourse,
        teachingClass: makeTeachingClass(code: "002", arrangementInfo: [arr2])
    )

    let engine = SyncEngine()
    let changes = [
        CourseChange(courseCode: "CS101", courseName: "数据结构", classCode: "001",
                      changeType: .infoChanged, detail: "上课安排: 周一 → 周二", detectedAt: Date())
    ]
    let result = await engine.detectConflicts(changes: changes, selectedClasses: [selected], calendarId: 1)
    #expect(result.count == 1)
    #expect(result[0].changeType == .infoChanged) // Not changed to conflict
}

@Test("detectConflicts marks conflicting class")
func detectConflictsConflict() async {
    let arr = makeArrangement(day: 1, time: [1, 2])
    let changedTc = makeTeachingClass(code: "001", arrangementInfo: [arr])
    let conflictTc = makeTeachingClass(code: "002", arrangementInfo: [arr]) // Same time slot → conflict

    let mock = MockCourseDetailProvider()
    mock.stubbedResult = ["CS101": [changedTc]]

    let engine = SyncEngine(repo: mock)
    let changes = [
        CourseChange(courseCode: "CS101", courseName: "数据结构", classCode: "001",
                      changeType: .infoChanged, detail: "上课安排: 周三 → 周一", detectedAt: Date())
    ]
    let selected = SchedulerSelectedClass(course: sampleCourse, teachingClass: conflictTc)
    let result = await engine.detectConflicts(changes: changes, selectedClasses: [selected], calendarId: 1)

    #expect(result.count == 1)
    #expect(result[0].changeType == .conflictAfterUpdate)
    #expect(result[0].conflictWith == "数据结构")
}

@Test("detectConflicts bidirectional marks both when both are changed")
func detectConflictsBidirectional() async {
    let arr = makeArrangement(day: 1, time: [1, 2])
    let tcA = makeTeachingClass(code: "001", arrangementInfo: [arr])
    let tcB = makeTeachingClass(code: "002", arrangementInfo: [arr])

    let mock = MockCourseDetailProvider()
    mock.stubbedResult = ["CS101": [tcA], "MATH": [tcB]]

    let engine = SyncEngine(repo: mock)
    let courseA = SchedulerCourseSummary(
        courseCode: "CS101", courseName: "数据结构", faculty: "计算机",
        facultyI18n: "计算机系", courseNature: [], campus: [], credit: 4.0
    )
    let courseB = SchedulerCourseSummary(
        courseCode: "MATH", courseName: "高等数学", faculty: "数学",
        facultyI18n: "数学系", courseNature: [], campus: [], credit: 5.0
    )

    let changes = [
        CourseChange(courseCode: "CS101", courseName: "数据结构", classCode: "001",
                      changeType: .infoChanged, detail: "上课安排: 周三 → 周一", detectedAt: Date()),
        CourseChange(courseCode: "MATH", courseName: "高等数学", classCode: "002",
                      changeType: .infoChanged, detail: "上课安排: 周四 → 周一", detectedAt: Date())
    ]
    let selected = [
        SchedulerSelectedClass(course: courseB, teachingClass: tcB)
    ]
    let result = await engine.detectConflicts(changes: changes, selectedClasses: selected, calendarId: 1)

    #expect(result.count == 2)
    // First: CS101 should be conflictAfterUpdate (conflicts with selected MATH)
    #expect(result[0].changeType == .conflictAfterUpdate)
    #expect(result[0].conflictWith == "高等数学")
}

@Test("stableCheckpointId is deterministic")
func stableCheckpointIdDeterministic() {
    let cp1 = SyncCheckpoint(
        courseCode: "CS101", courseName: "数据结构", credit: 4.0,
        classCode: "001", teacherNames: "张教授", campus: "四平路",
        teachingLanguage: "中文", arrangementHashes: ["1-A101-[1,2]-[1,2]"], isExclusive: false,
        capturedAt: Date()
    )
    let cp2 = SyncCheckpoint(
        courseCode: "CS101", courseName: "数据结构", credit: 4.0,
        classCode: "001", teacherNames: "张教授", campus: "四平路",
        teachingLanguage: "中文", arrangementHashes: ["1-A101-[1,2]-[1,2]"], isExclusive: false,
        capturedAt: Date().addingTimeInterval(3600)
    )

    let id1 = SyncEngine.stableCheckpointId(for: [cp1])
    let id2 = SyncEngine.stableCheckpointId(for: [cp2])
    #expect(id1 == id2)
}

@Test("stableCheckpointId changes when data changes")
func stableCheckpointIdChangesOnDataChange() {
    let cp1 = SyncCheckpoint(
        courseCode: "CS101", courseName: "数据结构", credit: 4.0,
        classCode: "001", teacherNames: "张教授", campus: "四平路",
        teachingLanguage: "中文", arrangementHashes: ["1-A101-[1,2]-[1,2]"], isExclusive: false,
        capturedAt: Date()
    )
    let cp2 = SyncCheckpoint(
        courseCode: "CS101", courseName: "数据结构", credit: 4.0,
        classCode: "001", teacherNames: "李老师", campus: "四平路",
        teachingLanguage: "中文", arrangementHashes: ["1-A101-[1,2]-[1,2]"], isExclusive: false,
        capturedAt: Date()
    )

    let id1 = SyncEngine.stableCheckpointId(for: [cp1])
    let id2 = SyncEngine.stableCheckpointId(for: [cp2])
    #expect(id1 != id2)
}

@Test("SyncStore save and load round-trip")
func syncStoreRoundTrip() {
    let store = SyncStore()
    store.acknowledgeChanges(["id1", "id2"], checkpointId: "cp1")

    let ack = store.loadAcknowledgment()
    #expect(ack.acknowledgedChangeIds == ["id1", "id2"])
    #expect(ack.lastAcknowledgedCheckpointId == "cp1")
}

@Test("SyncStore unacknowledgedChanges filters acknowledged")
func syncStoreUnacknowledgedFilters() {
    let store = SyncStore()
    let date = Date()
    let changes = [
        CourseChange(courseCode: "CS101", courseName: "数据结构", classCode: "001",
                      changeType: .infoChanged, detail: "test", detectedAt: date),
        CourseChange(courseCode: "CS102", courseName: "算法", classCode: "002",
                      changeType: .closed, detail: "closed", detectedAt: date)
    ]
    let result = SyncResult(changes: changes, checkedAt: date)

    // Acknowledge only the first
    store.acknowledgeChanges([changes[0].id], checkpointId: nil)

    let unacknowledged = store.unacknowledgedChanges(in: result, checkpointId: nil)
    #expect(unacknowledged.count == 1)
    #expect(unacknowledged[0].courseCode == "CS102")
}

@Test("SyncStore checkpointId suppresses all changes when matching")
func syncStoreCheckpointSuppression() {
    let store = SyncStore()
    store.acknowledgeChanges([], checkpointId: "cp-unchanged")

    let result = SyncResult(changes: [CourseChange(
        courseCode: "CS101", courseName: "数据结构", classCode: "001",
        changeType: .infoChanged, detail: "test", detectedAt: Date()
    )], checkedAt: Date())

    let unacknowledged = store.unacknowledgedChanges(in: result, checkpointId: "cp-unchanged")
    #expect(unacknowledged.isEmpty)
}

@Test("CourseChange.id includes detail hash for distinctness")
func courseChangeIdHashDistinct() {
    let date = Date()
    let change1 = CourseChange(courseCode: "CS101", courseName: "数据结构", classCode: "001",
                                changeType: .infoChanged, detail: "教师: A→B", detectedAt: date)
    let change2 = CourseChange(courseCode: "CS101", courseName: "数据结构", classCode: "001",
                                changeType: .infoChanged, detail: "教师: A→C", detectedAt: date)
    // Same type same keys but different detail => different ID
    #expect(change1.id != change2.id)
}

@Test("buildDetailParts teacher change")
func buildDetailPartsTeacherChange() {
    let cp = SyncCheckpoint(
        courseCode: "CS101", courseName: "数据结构", credit: 4.0,
        classCode: "001", teacherNames: "李老师", campus: "四平路",
        teachingLanguage: "中文", arrangementHashes: [], isExclusive: false,
        capturedAt: Date()
    )
    let tc = makeTeachingClass(teacherNames: "张教授")

    let engine = SyncEngine()
    let parts = engine.buildDetailParts(checkpoint: cp, fresh: tc)
    #expect(parts.count == 1)
    #expect(parts[0].contains("授课教师"))
    #expect(parts[0].contains("李老师"))
    #expect(parts[0].contains("张教授"))
}

@Test("buildDetailParts no change returns empty")
func buildDetailPartsNoChange() {
    let arr = makeArrangement()
    let tc = makeTeachingClass(teacherNames: "张教授", arrangementInfo: [arr])
    let cp = SyncCheckpoint(
        courseCode: "CS101", courseName: "数据结构", credit: 4.0,
        classCode: "001", teacherNames: "张教授", campus: "四平路",
        teachingLanguage: "中文",
        arrangementHashes: ["1-A101-[1, 2]-[1, 2, 3, 4]"],
        isExclusive: false,
        capturedAt: Date()
    )

    let engine = SyncEngine()
    let parts = engine.buildDetailParts(checkpoint: cp, fresh: tc)
    #expect(parts.isEmpty)
}

@Test("buildDetailParts campus change")
func buildDetailPartsCampusChange() {
    let cp = SyncCheckpoint(
        courseCode: "CS101", courseName: "数据结构", credit: 4.0,
        classCode: "001", teacherNames: "张教授", campus: "嘉定",
        teachingLanguage: "中文", arrangementHashes: [], isExclusive: false,
        capturedAt: Date()
    )
    let tc = makeTeachingClass(campus: "四平路")

    let engine = SyncEngine()
    let parts = engine.buildDetailParts(checkpoint: cp, fresh: tc)
    #expect(parts.count == 1)
    #expect(parts[0].contains("校区"))
}

@Test("sync detects campus change")
func syncCampusChange() async {
    let oldTc = makeTeachingClass(code: "001", campus: "嘉定")
    let newTc = makeTeachingClass(code: "001", campus: "四平路")
    let selected = SchedulerSelectedClass(course: sampleCourse, teachingClass: oldTc)

    let mock = MockCourseDetailProvider()
    mock.stubbedResult = ["CS101": [newTc]]

    let engine = SyncEngine(repo: mock)
    let snapshot = engine.captureCheckpoint(from: [selected], calendarId: 1)
    let result = await engine.sync(snapshot: snapshot, calendarId: 1)

    #expect(result.hasChanges == true)
    #expect(result.changes[0].detail.contains("校区"))
}

@Test("sync with multiple courses detects changes independently")
func syncMultipleCourses() async {
    let courseA = SchedulerCourseSummary(
        courseCode: "CS101", courseName: "数据结构", faculty: "计算机",
        facultyI18n: "计算机系", courseNature: [], campus: [], credit: 4.0
    )
    let courseB = SchedulerCourseSummary(
        courseCode: "MATH101", courseName: "高等数学", faculty: "数学",
        facultyI18n: "数学系", courseNature: [], campus: [], credit: 5.0
    )

    let oldTcA = makeTeachingClass(code: "001", teacherNames: "李老师")
    let newTcA = makeTeachingClass(code: "001", teacherNames: "张教授")
    let oldTcB = makeTeachingClass(code: "001", teacherNames: "王老师")

    let selected = [
        SchedulerSelectedClass(course: courseA, teachingClass: oldTcA),
        SchedulerSelectedClass(course: courseB, teachingClass: oldTcB)
    ]

    let mock = MockCourseDetailProvider()
    mock.stubbedResult = ["CS101": [newTcA], "MATH101": [oldTcB]]

    let engine = SyncEngine(repo: mock)
    let snapshot = engine.captureCheckpoint(from: selected, calendarId: 1)
    let result = await engine.sync(snapshot: snapshot, calendarId: 1)

    #expect(result.hasChanges == true)
    #expect(result.changes.count == 1) // Only CS101 changed
    #expect(result.changes[0].courseCode == "CS101")
}

@Test("sync handles provider failure gracefully")
func syncProviderFailure() async {
    let tc = makeTeachingClass(code: "001")
    let selected = SchedulerSelectedClass(course: sampleCourse, teachingClass: tc)

    // Empty result simulates provider failure
    let mock = MockCourseDetailProvider()
    mock.stubbedResult = [:]

    let engine = SyncEngine(repo: mock)
    let snapshot = engine.captureCheckpoint(from: [selected], calendarId: 1)
    let result = await engine.sync(snapshot: snapshot, calendarId: 1)

    // All checkpoints should be marked as closed (no data returned)
    #expect(result.hasChanges == true)
    #expect(result.changes.count == 1)
    #expect(result.changes[0].changeType == .closed)
}
