import Testing
import Foundation
@testable import DomainKit

@Test("CourseChange.id is stable across instances")
func stableCourseChangeId() async {
    let date = Date()
    let a = CourseChange(courseCode: "CS101", courseName: "数据结构", classCode: "001",
                          changeType: .infoChanged, detail: "教师变了", detectedAt: date)
    let b = CourseChange(courseCode: "CS101", courseName: "数据结构", classCode: "001",
                          changeType: .infoChanged, detail: "教师变了", detectedAt: date.addingTimeInterval(3600))
    #expect(a.id == b.id, "ID must be based on content, not time")

    let closed = CourseChange(courseCode: "CS101", courseName: "数据结构", classCode: "001",
                               changeType: .closed, detail: "关闭", detectedAt: date)
    #expect(a.id != closed.id, "Different changeType = different ID")
}

@Test("CourseChange.id format")
func courseChangeIdFormat() {
    let c = CourseChange(courseCode: "CS101", courseName: "数据结构", classCode: "001",
                          changeType: .infoChanged, detail: "test", detectedAt: Date())
    #expect(c.id.hasPrefix("InfoChanged|CS101|001|"), "ID must start with changeType|coursecode|classcode|")
    #expect(c.id != "InfoChanged|CS101|001", "ID must have a hash suffix")
}

@Test("SyncCheckpoint round-trip Codable")
func checkpointCodable() throws {
    let cp = SyncCheckpoint(
        courseCode: "CS101", courseName: "数据结构", credit: 4.0,
        classCode: "001", teacherNames: "张老师", campus: "四平路",
        teachingLanguage: "中文", arrangementHashes: ["h1", "h2"], isExclusive: false,
        capturedAt: Date()
    )
    let data = try JSONEncoder().encode(cp)
    let decoded = try JSONDecoder().decode(SyncCheckpoint.self, from: data)
    #expect(decoded.courseCode == cp.courseCode)
    #expect(decoded.teacherNames == cp.teacherNames)
    #expect(decoded.arrangementHashes == cp.arrangementHashes)
    #expect(decoded.isExclusive == cp.isExclusive)
}

@Test("SyncSnapshot round-trip Codable")
func snapshotCodable() throws {
    let cp = SyncCheckpoint(
        courseCode: "CS101", courseName: "数据结构", credit: 4.0,
        classCode: "001", teacherNames: "张老师", campus: "四平路",
        teachingLanguage: "中文", arrangementHashes: [], isExclusive: false,
        capturedAt: Date()
    )
    let snapshot = SyncSnapshot(checkpointId: "stable-id-abc", calendarId: 1, checkpoints: [cp], capturedAt: Date())
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(SyncSnapshot.self, from: data)
    #expect(decoded.checkpointId == "stable-id-abc")
    #expect(decoded.checkpoints.count == 1)
}

@Test("SyncAcknowledgment Codable")
func acknowledgmentCodable() throws {
    var ack = SyncAcknowledgment()
    #expect(ack.acknowledgedChangeIds.isEmpty)
    #expect(ack.lastAcknowledgedCheckpointId == nil)

    ack.acknowledgedChangeIds = ["id1", "id2"]
    ack.lastAcknowledgedCheckpointId = "cp1"

    let data = try JSONEncoder().encode(ack)
    let decoded = try JSONDecoder().decode(SyncAcknowledgment.self, from: data)
    #expect(decoded.acknowledgedChangeIds == ["id1", "id2"])
    #expect(decoded.lastAcknowledgedCheckpointId == "cp1")
}

@Test("CourseChange.conflictWith populated correctly")
func conflictWith() {
    let change = CourseChange(
        courseCode: "CS101", courseName: "数据结构", classCode: "001",
        changeType: .conflictAfterUpdate,
        detail: "安排变更\n\n与高等数学时间冲突",
        detectedAt: Date(),
        conflictWith: "高等数学"
    )
    #expect(change.conflictWith == "高等数学")
    #expect(change.changeType == .conflictAfterUpdate)
}
