import Foundation
import DomainKit
import DataKit

/// Engine that compares current teaching class data against a saved checkpoint
/// and produces a list of CourseChange items.
public struct SyncEngine: Sendable {
    private let repo: SchedulerRepository

    public init(repo: SchedulerRepository = .init()) {
        self.repo = repo
    }

    /// Create checkpoints from the user's selected classes.
    public func captureCheckpoint(from selectedClasses: [SchedulerSelectedClass], calendarId: Int) -> SyncSnapshot {
        let checkpoints = selectedClasses.map { selected -> SyncCheckpoint in
            let tc = selected.teachingClass
            let arrHashes = tc.arrangementInfo.map { arr in
                "\(arr.occupyDay ?? 0)-\(arr.occupyRoom ?? "")-\(arr.occupyTime ?? [])-\(arr.occupyWeek ?? [])"
            }
            return SyncCheckpoint(
                courseCode: selected.course.courseCode,
                courseName: selected.course.courseName,
                credit: selected.course.credit,
                classCode: tc.code,
                teacherNames: tc.teacherNames,
                campus: tc.campus,
                teachingLanguage: tc.teachingLanguage,
                arrangementHashes: arrHashes,
                isExclusive: tc.isExclusive,
                capturedAt: Date()
            )
        }
        return SyncSnapshot(
            checkpointId: UUID().uuidString,
            calendarId: calendarId,
            checkpoints: checkpoints,
            capturedAt: Date()
        )
    }

    /// Run a sync: fetch latest data and compare against checkpoints.
    public func sync(
        snapshot: SyncSnapshot,
        calendarId: Int
    ) async -> SyncResult {
        guard !snapshot.checkpoints.isEmpty else {
            return SyncResult(changes: [], checkedAt: Date())
        }

        let courseCodes = Array(Set(snapshot.checkpoints.map(\.courseCode)))
        let freshData: [String: [SchedulerTeachingClass]]
        do {
            freshData = try await repo.findCourseDetailsBatch(calendarId: calendarId, courseCodes: courseCodes)
        } catch {
            return SyncResult(changes: [], checkedAt: Date())
        }

        var changes: [CourseChange] = []
        let now = Date()

        for checkpoint in snapshot.checkpoints {
            let classes = freshData[checkpoint.courseCode] ?? []
            let matchingClass = classes.first { $0.code == checkpoint.classCode }

            if matchingClass == nil {
                changes.append(CourseChange(
                    courseCode: checkpoint.courseCode,
                    courseName: checkpoint.courseName,
                    classCode: checkpoint.classCode,
                    changeType: .closed,
                    detail: "此教学班已关闭或本学期不再开设",
                    detectedAt: now
                ))
                continue
            }

            guard let tc = matchingClass else { continue }

            var detailParts: [String] = []

            if tc.teacherNames != checkpoint.teacherNames {
                detailParts.append("授课教师: \(checkpoint.teacherNames) → \(tc.teacherNames)")
            }

            if tc.campus != checkpoint.campus {
                detailParts.append("校区: \(checkpoint.campus) → \(tc.campus)")
            }

            if tc.teachingLanguage != checkpoint.teachingLanguage {
                detailParts.append("教学语言: \(checkpoint.teachingLanguage) → \(tc.teachingLanguage)")
            }

            if tc.isExclusive != checkpoint.isExclusive {
                detailParts.append("专属状态已变更")
            }

            let newHashes = tc.arrangementInfo.map { arr in
                "\(arr.occupyDay ?? 0)-\(arr.occupyRoom ?? "")-\(arr.occupyTime ?? [])-\(arr.occupyWeek ?? [])"
            }
            if newHashes != checkpoint.arrangementHashes {
                let oldDesc = checkpoint.arrangementHashes.map { h in
                    let parts = h.split(separator: "-")
                    let day = Int(parts[0]) ?? 0
                    return "周\(dayNames[safe: day] ?? "?")"
                }.joined(separator: ", ")
                let newDesc = newHashes.map { h in
                    let parts = h.split(separator: "-")
                    let day = Int(parts[0]) ?? 0
                    return "周\(dayNames[safe: day] ?? "?")"
                }.joined(separator: ", ")
                detailParts.append("上课安排: \(oldDesc) → \(newDesc)")
            }

            if !detailParts.isEmpty {
                changes.append(CourseChange(
                    courseCode: checkpoint.courseCode,
                    courseName: checkpoint.courseName,
                    classCode: checkpoint.classCode,
                    changeType: .infoChanged,
                    detail: detailParts.joined(separator: "\n"),
                    detectedAt: now
                ))
            }
        }

        return SyncResult(changes: changes, checkedAt: now)
    }

    /// Expanded sync that includes both selected and candidate (not-yet-selected) checkpoints.
    public func sync(
        selectedSnapshot: SyncSnapshot,
        candidateCheckpoints: [SyncCheckpoint],
        calendarId: Int
    ) async -> SyncResult {
        let allCheckpoints = selectedSnapshot.checkpoints + candidateCheckpoints
        guard !allCheckpoints.isEmpty else {
            return SyncResult(changes: [], checkedAt: Date())
        }

        let courseCodes = Array(Set(allCheckpoints.map(\.courseCode)))
        let freshData: [String: [SchedulerTeachingClass]]
        do {
            freshData = try await repo.findCourseDetailsBatch(calendarId: calendarId, courseCodes: courseCodes)
        } catch {
            return SyncResult(changes: [], checkedAt: Date())
        }

        var changes: [CourseChange] = []
        let now = Date()

        for checkpoint in allCheckpoints {
            let classes = freshData[checkpoint.courseCode] ?? []
            let matchingClass = classes.first { $0.code == checkpoint.classCode }

            if matchingClass == nil {
                changes.append(CourseChange(
                    courseCode: checkpoint.courseCode,
                    courseName: checkpoint.courseName,
                    classCode: checkpoint.classCode,
                    changeType: .closed,
                    detail: "此教学班已关闭或本学期不再开设",
                    detectedAt: now
                ))
                continue
            }

            guard let tc = matchingClass else { continue }

            var detailParts: [String] = []

            if tc.teacherNames != checkpoint.teacherNames {
                detailParts.append("授课教师: \(checkpoint.teacherNames) → \(tc.teacherNames)")
            }

            if tc.campus != checkpoint.campus {
                detailParts.append("校区: \(checkpoint.campus) → \(tc.campus)")
            }

            if tc.teachingLanguage != checkpoint.teachingLanguage {
                detailParts.append("教学语言: \(checkpoint.teachingLanguage) → \(tc.teachingLanguage)")
            }

            if tc.isExclusive != checkpoint.isExclusive {
                detailParts.append("专属状态已变更")
            }

            let newHashes = tc.arrangementInfo.map { arr in
                "\(arr.occupyDay ?? 0)-\(arr.occupyRoom ?? "")-\(arr.occupyTime ?? [])-\(arr.occupyWeek ?? [])"
            }
            if newHashes != checkpoint.arrangementHashes {
                let oldDesc = checkpoint.arrangementHashes.map { h in
                    let parts = h.split(separator: "-")
                    let day = Int(parts[0]) ?? 0
                    return "周\(dayNames[safe: day] ?? "?")"
                }.joined(separator: ", ")
                let newDesc = newHashes.map { h in
                    let parts = h.split(separator: "-")
                    let day = Int(parts[0]) ?? 0
                    return "周\(dayNames[safe: day] ?? "?")"
                }.joined(separator: ", ")
                detailParts.append("上课安排: \(oldDesc) → \(newDesc)")
            }

            if !detailParts.isEmpty {
                changes.append(CourseChange(
                    courseCode: checkpoint.courseCode,
                    courseName: checkpoint.courseName,
                    classCode: checkpoint.classCode,
                    changeType: .infoChanged,
                    detail: detailParts.joined(separator: "\n"),
                    detectedAt: now
                ))
            }
        }

        return SyncResult(changes: changes, checkedAt: now)
    }

    /// Detect time conflicts between arrangement-changed classes and the user's current selections.
    public func detectConflicts(
        changes: [CourseChange],
        selectedClasses: [SchedulerSelectedClass],
        calendarId: Int
    ) async -> [CourseChange] {
        let arrangementChangedCodes = Set(
            changes
                .filter { $0.changeType == .infoChanged && $0.detail.contains("上课安排") }
                .map(\.courseCode)
        )
        guard !arrangementChangedCodes.isEmpty else { return changes }

        let freshData: [String: [SchedulerTeachingClass]]
        do {
            freshData = try await repo.findCourseDetailsBatch(
                calendarId: calendarId,
                courseCodes: Array(arrangementChangedCodes)
            )
        } catch {
            return changes
        }

        var updatedChanges = changes

        for (index, change) in changes.enumerated() where change.changeType == .infoChanged && change.detail.contains("上课安排") {
            let freshClasses = freshData[change.courseCode] ?? []
            guard let freshClass = freshClasses.first(where: { $0.code == change.classCode }) else { continue }

            for selected in selectedClasses {
                let selectedKey = "\(selected.course.courseCode)|\(selected.teachingClass.code)"
                let changeKey = "\(change.courseCode)|\(change.classCode)"
                guard selectedKey != changeKey else { continue }

                if freshClass.conflicts(with: selected.teachingClass) {
                    updatedChanges[index] = CourseChange(
                        courseCode: change.courseCode,
                        courseName: change.courseName,
                        classCode: change.classCode,
                        changeType: .conflictAfterUpdate,
                        detail: "\(change.detail)\n\n与已选课程「\(selected.course.courseName)」时间冲突",
                        detectedAt: change.detectedAt,
                        conflictWith: selected.course.courseName
                    )
                    break
                }
            }
        }

        return updatedChanges
    }
}

/// Manages persistent state for sync acknowledgments in UserDefaults.
public struct SyncStore: Sendable {
    private let defaultsKey = "com.yourtj.course.scheduler.syncAck"

    public init() {}

    public func loadAcknowledgment() -> SyncAcknowledgment {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let ack = try? JSONDecoder().decode(SyncAcknowledgment.self, from: data)
        else {
            return SyncAcknowledgment(acknowledgedChangeIds: [], lastAcknowledgedCheckpointId: nil)
        }
        return ack
    }

    public func saveAcknowledgment(_ ack: SyncAcknowledgment) {
        guard let data = try? JSONEncoder().encode(ack) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    public func acknowledgeChanges(_ changeIds: Set<String>, checkpointId: String?) {
        var ack = loadAcknowledgment()
        ack.acknowledgedChangeIds.formUnion(changeIds)
        if let cid = checkpointId {
            ack.lastAcknowledgedCheckpointId = cid
        }
        saveAcknowledgment(ack)
    }

    public func unacknowledgedChanges(in result: SyncResult, checkpointId: String?) -> [CourseChange] {
        let ack = loadAcknowledgment()
        if let cid = checkpointId, ack.lastAcknowledgedCheckpointId == cid {
            return []
        }
        return result.changes.filter { !ack.acknowledgedChangeIds.contains($0.id) }
    }
}

private let dayNames = ["", "一", "二", "三", "四", "五", "六", "日"]

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
