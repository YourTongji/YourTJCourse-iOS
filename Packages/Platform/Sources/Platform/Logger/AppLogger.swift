import OSLog

/// A lightweight wrapper around `os.Logger` providing structured logging
/// with a consistent subsystem identifier.
///
/// Usage:
/// ```swift
/// let logger = AppLogger(category: "catalog")
/// logger.info("Loaded \(count) courses")
/// logger.error("Failed to fetch: \(error.localizedDescription)")
/// ```
public struct AppLogger {
    private let logger: Logger

    /// Creates a logger for the given category.
    ///
    /// All loggers share the subsystem `com.yourtj.course`.
    /// The category helps filter logs by feature area (e.g. `catalog`,
    /// `review`, `wallet`, `captcha`).
    public init(category: String) {
        self.logger = Logger(
            subsystem: AppLogger.subsystem,
            category: category
        )
    }

    /// Logs a debug-level message.
    public func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    /// Logs an info-level message.
    public func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    /// Logs an error-level message.
    public func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    /// Logs a fault-level message.
    public func fault(_ message: String) {
        logger.fault("\(message, privacy: .public)")
    }
}

// MARK: - Constants

extension AppLogger {
    /// The subsystem identifier used by all app loggers.
    static let subsystem = "com.yourtj.course"
}
