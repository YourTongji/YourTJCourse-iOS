import Foundation

public enum CourseChangeType: String, Codable, Sendable {
    case closed = "Closed"
    case infoChanged = "InfoChanged"
    case conflictAfterUpdate = "ConflictAfterUpdate"
}

public struct CourseChange: Identifiable, Codable, Sendable {
    public let id: String
    public let courseCode: String
    public let courseName: String
    public let classCode: String
    public let changeType: CourseChangeType
    public let detail: String
    public let detectedAt: Date
    /// If changeType is .conflictAfterUpdate, the name of the conflicting course.
    public let conflictWith: String?

    public init(
        courseCode: String,
        courseName: String,
        classCode: String,
        changeType: CourseChangeType,
        detail: String,
        detectedAt: Date,
        conflictWith: String? = nil
    ) {
        self.courseCode = courseCode
        self.courseName = courseName
        self.classCode = classCode
        self.changeType = changeType
        self.detail = detail
        self.detectedAt = detectedAt
        self.conflictWith = conflictWith
        self.id = "\(courseCode)|\(classCode)|\(Int(detectedAt.timeIntervalSince1970))"
    }
}

public struct SyncCheckpoint: Codable, Sendable {
    public let courseCode: String
    public let courseName: String
    public let credit: Double
    public let classCode: String
    public let teacherNames: String
    public let campus: String
    public let teachingLanguage: String
    public let arrangementHashes: [String]
    public let isExclusive: Bool
    public let capturedAt: Date

    public init(
        courseCode: String,
        courseName: String,
        credit: Double,
        classCode: String,
        teacherNames: String,
        campus: String,
        teachingLanguage: String,
        arrangementHashes: [String],
        isExclusive: Bool,
        capturedAt: Date
    ) {
        self.courseCode = courseCode
        self.courseName = courseName
        self.credit = credit
        self.classCode = classCode
        self.teacherNames = teacherNames
        self.campus = campus
        self.teachingLanguage = teachingLanguage
        self.arrangementHashes = arrangementHashes
        self.isExclusive = isExclusive
        self.capturedAt = capturedAt
    }
}

public struct SyncSnapshot: Codable, Sendable {
    public let checkpointId: String
    public let calendarId: Int
    public let checkpoints: [SyncCheckpoint]
    public let capturedAt: Date

    public init(
        checkpointId: String,
        calendarId: Int,
        checkpoints: [SyncCheckpoint],
        capturedAt: Date
    ) {
        self.checkpointId = checkpointId
        self.calendarId = calendarId
        self.checkpoints = checkpoints
        self.capturedAt = capturedAt
    }
}

public struct SyncResult: Sendable {
    public let changes: [CourseChange]
    public let hasChanges: Bool
    public let checkedAt: Date

    public init(changes: [CourseChange], checkedAt: Date) {
        self.changes = changes
        self.hasChanges = !changes.isEmpty
        self.checkedAt = checkedAt
    }
}

public struct SyncAcknowledgment: Codable, Sendable {
    public var acknowledgedChangeIds: Set<String>
    public var lastAcknowledgedCheckpointId: String?

    public init(
        acknowledgedChangeIds: Set<String> = [],
        lastAcknowledgedCheckpointId: String? = nil
    ) {
        self.acknowledgedChangeIds = acknowledgedChangeIds
        self.lastAcknowledgedCheckpointId = lastAcknowledgedCheckpointId
    }
}
