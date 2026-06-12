import Foundation
import Observation
import DomainKit
import DataKit
import Platform

@MainActor
@Observable
public final class SettingsViewModel {
    public private(set) var announcements: [Announcement] = []
    public private(set) var isLoading = false
    public private(set) var error: String?
    public var showAnnouncements = false
    public var showEULA = false
    public var showCommunityGuidelines = false
    public var showFeedback = false
    public var showAbout = false
    public var showMyReviews = false

    private let settingsRepo: SettingsRepository
    private let logger = AppLogger(category: "Settings")

    public init(settingsRepo: SettingsRepository = .init()) {
        self.settingsRepo = settingsRepo
    }

    public func loadAnnouncements() async {
        isLoading = true
        do {
            let state = try await settingsRepo.getRuntimeState()
            announcements = state.announcements
        } catch {
            self.error = error.localizedDescription
            logger.error("Failed to load announcements: \(error.localizedDescription)")
        }
        isLoading = false
    }
}
