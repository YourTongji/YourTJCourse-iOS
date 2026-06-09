import Foundation
import Observation
import DataKit
import DomainKit

/// Monitors the backend runtime state for mid-session maintenance detection.
///
/// Call `startPolling()`/`stopPolling()` from the app layer in response to
/// `UIApplication.didBecomeActiveNotification` / `didEnterBackgroundNotification`,
/// or use `check()` for a single-shot refresh.
///
/// Exposes `isEnabled` and `config` as @Observable properties so SwiftUI views
/// can react to mid-session maintenance state changes.
@MainActor
@Observable
public final class MaintenanceMonitor {
    public static let shared = MaintenanceMonitor()

    public private(set) var isEnabled = false
    public private(set) var config: MaintenanceConfig?

    private let settingsRepo: SettingsRepository
    private let pollInterval: TimeInterval
    private var pollingTask: Task<Void, Never>?

    public init(
        settingsRepo: SettingsRepository = .init(),
        pollInterval: TimeInterval = 30
    ) {
        self.settingsRepo = settingsRepo
        self.pollInterval = pollInterval
    }

    /// Starts a recurring polling loop that checks maintenance state every `pollInterval`.
    public func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await check()
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }
    }

    /// Stops the polling loop.
    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Single-shot check of the current runtime state.
    public func check() async {
        do {
            let state = try await settingsRepo.getRuntimeState()
            isEnabled = state.maintenance.enabled
            config = state.maintenance.config
        } catch {
            // Silently fail — transient network errors should not change UI state.
        }
    }
}
