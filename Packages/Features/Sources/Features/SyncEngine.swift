import Foundation
import DomainKit
import DataKit

/// Provider protocol for fetching teaching class details by course code.
/// Extracted for testability — conform `SchedulerRepository` via the extension below.
public protocol CourseDetailProvider: Sendable {
    func findCourseDetailsBatch(calendarId: Int, courseCodes: [String]) async -> [String: [SchedulerTeachingClass]]
}

extension SchedulerRepository: CourseDetailProvider {}

/// Engine that compares current teaching class data against a saved checkpoint
/// and produces a list of CourseChange items.
public struct SyncEngine: Sendable {
    private let repo: CourseDetailProvider

    public init(repo: CourseDetailProvider = SchedulerRepository()) {
        self.repo = repo
    }

    // MARK: - Checkpoint capture

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
            checkpointId: Self.stableCheckpointId(for: checkpoints),
            calendarId: calendarId,
            checkpoints: checkpoints,
            capturedAt: Date()
        )
    }

    // MARK: - Sync

    /// Run a sync: fetch latest data and compare against a saved snapshot.
    public func sync(snapshot: SyncSnapshot, calendarId: Int) async -> SyncResult {
        await compareCheckpoints(snapshot.checkpoints, calendarId: calendarId)
    }

    /// Expanded sync that includes both selected and candidate (not-yet-selected) checkpoints.
    public func sync(
        selectedSnapshot: SyncSnapshot,
        candidateCheckpoints: [SyncCheckpoint],
        calendarId: Int
    ) async -> SyncResult {
        await compareCheckpoints(selectedSnapshot.checkpoints + candidateCheckpoints, calendarId: calendarId)
    }

    // MARK: - Shared comparison

    private func compareCheckpoints(_ checkpoints: [SyncCheckpoint], calendarId: Int) async -> SyncResult {
        guard !checkpoints.isEmpty else {
            return SyncResult(changes: [], checkedAt: Date())
        }

        let courseCodes = Array(Set(checkpoints.map(\.courseCode)))
        let freshData = (try? await repo.findCourseDetailsBatch(calendarId: calendarId, courseCodes: courseCodes)) ?? [:]

        var changes: [CourseChange] = []
        let now = Date()

        for checkpoint in checkpoints {
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

            let detailParts = buildDetailParts(checkpoint: checkpoint, fresh: tc)
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

    // MARK: - Detail comparison

    /// Build human-readable change descriptions between a checkpoint and fresh teaching class data.
    nonisolated func buildDetailParts(checkpoint: SyncCheckpoint, fresh tc: SchedulerTeachingClass) -> [String] {
        var parts: [String] = []

        if tc.teacherNames != checkpoint.teacherNames {
            parts.append("授课教师: \(checkpoint.teacherNames) → \(tc.teacherNames)")
        }
        if tc.campus != checkpoint.campus {
            parts.append("校区: \(checkpoint.campus) → \(tc.campus)")
        }
        if tc.teachingLanguage != checkpoint.teachingLanguage {
            parts.append("教学语言: \(checkpoint.teachingLanguage) → \(tc.teachingLanguage)")
        }
        if tc.isExclusive != checkpoint.isExclusive {
            parts.append("专属状态已变更")
        }

        let newHashes = tc.arrangementInfo.map { arr in
            "\(arr.occupyDay ?? 0)-\(arr.occupyRoom ?? "")-\(arr.occupyTime ?? [])-\(arr.occupyWeek ?? [])"
        }
        if newHashes != checkpoint.arrangementHashes {
            let oldDesc = checkpoint.arrangementHashes.compactMap { h -> String? in
                let parts = h.split(separator: "-")
                guard let first = parts.first, let day = Int(first) else { return nil }
                return "周\(dayNames[safe: day] ?? "?")"
            }.joined(separator: ", ")
            let newDesc = newHashes.compactMap { h -> String? in
                let parts = h.split(separator: "-")
                guard let first = parts.first, let day = Int(first) else { return nil }
                return "周\(dayNames[safe: day] ?? "?")"
            }.joined(separator: ", ")
            parts.append("上课安排: \(oldDesc) → \(newDesc)")
        }

        return parts
    }

    // MARK: - Conflict detection

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

        let freshData = (try? await repo.findCourseDetailsBatch(
            calendarId: calendarId,
            courseCodes: Array(arrangementChangedCodes)
        )) ?? [:]

        var updatedChanges = changes
        let changedKeys = Set(
            changes.filter { $0.changeType == .infoChanged && $0.detail.contains("上课安排") }
                .map { "\($0.courseCode)|\($0.classCode)" }
        )
        var processedChangedKeys: Set<String> = []

        for (index, change) in changes.enumerated()
        where change.changeType == .infoChanged && change.detail.contains("上课安排") {
            let changeKey = "\(change.courseCode)|\(change.classCode)"
            processedChangedKeys.insert(changeKey)

            let freshClasses = freshData[change.courseCode] ?? []
            guard let freshClass = freshClasses.first(where: { $0.code == change.classCode }) else { continue }

            for selected in selectedClasses {
                let selectedKey = "\(selected.course.courseCode)|\(selected.teachingClass.code)"
                guard selectedKey != changeKey else { continue }
                guard freshClass.conflicts(with: selected.teachingClass) else { continue }

                // Mark this course as conflicted
                updatedChanges[index] = CourseChange(
                    courseCode: change.courseCode,
                    courseName: change.courseName,
                    classCode: change.classCode,
                    changeType: .conflictAfterUpdate,
                    detail: "\(change.detail)\n\n与已选课程「\(selected.course.courseName)」时间冲突",
                    detectedAt: change.detectedAt,
                    conflictWith: selected.course.courseName
                )

                // Bidirectional: if the conflicting selected class is ALSO a changed course, mark it too
                if changedKeys.contains(selectedKey), !processedChangedKeys.contains(selectedKey) {
                    if let selectedIdx = updatedChanges.firstIndex(where: {
                        "\($0.courseCode)|\($0.classCode)" == selectedKey
                    }) {
                        let selChange = updatedChanges[selectedIdx]
                        updatedChanges[selectedIdx] = CourseChange(
                            courseCode: selChange.courseCode,
                            courseName: selChange.courseName,
                            classCode: selChange.classCode,
                            changeType: .conflictAfterUpdate,
                            detail: "\(selChange.detail)\n\n与同样变更的课程「\(change.courseName)」冲突",
                            detectedAt: selChange.detectedAt,
                            conflictWith: change.courseName
                        )
                    }
                }

                break
            }
        }

        return updatedChanges
    }

    // MARK: - Stable IDs

    /// Compute a deterministic checkpoint ID based on checkpoint content.
    static func stableCheckpointId(for checkpoints: [SyncCheckpoint]) -> String {
        let sorted = checkpoints.sorted {
            $0.courseCode < $1.courseCode || ($0.courseCode == $1.courseCode && $0.classCode < $1.classCode)
        }
        var hasher = FixedHasher()
        for cp in sorted {
            hasher.combine(cp.courseCode)
            hasher.combine(cp.classCode)
            hasher.combine(cp.teacherNames)
            hasher.combine(cp.campus)
            hasher.combine(cp.teachingLanguage)
            hasher.combine(cp.arrangementHashes)
            hasher.combine(cp.isExclusive)
        }
        return hasher.finalize()
    }
}

// MARK: - SyncStore (persistence)

/// Manages persistent state for sync acknowledgments in UserDefaults.
public struct SyncStore: Sendable {
    private let defaultsKey = "com.yourtj.course.scheduler.syncAck"

    public init() {}

    public func loadAcknowledgment() -> SyncAcknowledgment {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let ack = try? JSONDecoder().decode(SyncAcknowledgment.self, from: data)
        else {
            return SyncAcknowledgment()
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

// MARK: - FixedHasher (stable content-addressable hash)

/// Simple non-cryptographic hash for stable content addressing.
/// Uses FNV-1a so results are deterministic across runs.
private struct FixedHasher {
    private var hash: UInt64 = 14695981039346656037

    mutating func combine(_ value: String) {
        combine(Data(value.utf8))
    }

    mutating func combine(_ value: Bool) {
        combine(value ? "1" : "0")
    }

    mutating func combine(_ value: [String]) {
        for s in value.sorted() { combine(s) }
    }

    private mutating func combine(_ data: Data) {
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
    }

    func finalize() -> String {
        String(hash, radix: 36)
    }
}

private let dayNames = ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"]

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
