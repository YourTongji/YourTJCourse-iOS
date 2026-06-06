import Foundation
import Observation
import DomainKit
import DataKit
import Platform

@MainActor
@Observable
public final class StartupViewModel {
    public enum Phase: Equatable {
        case loading
        case maintenance(maintenance: MaintenanceConfig?)
        case captcha
        case verifying
        case failed(String)
        case completed
    }

    public private(set) var phase: Phase = .loading
    public private(set) var announcements: [Announcement] = []
    private let settingsRepo: SettingsRepository
    private let client: APIClient
    private let logger = AppLogger(category: "Startup")

    public init(
        settingsRepo: SettingsRepository = .init(),
        client: APIClient = .shared,
        initialPhase: Phase = .loading,
        announcements: [Announcement] = []
    ) {
        self.settingsRepo = settingsRepo
        self.client = client
        self.phase = initialPhase
        self.announcements = announcements
    }

    public func checkRuntimeState() async {
        phase = .loading
        do {
            let state = try await settingsRepo.getRuntimeState()
            announcements = state.announcements
            if state.maintenance.enabled {
                phase = .maintenance(maintenance: state.maintenance.config)
            } else {
                phase = .captcha
            }
        } catch {
            logger.error("Runtime state check failed: \(error.localizedDescription)")
            // If we can't reach the server, proceed to captcha anyway
            phase = .captcha
        }
    }

    public func verifyWithTurnstile(token: String) async {
        phase = .verifying
        do {
            let response: StartupVerifyResponse = try await client.post(
                "/api/startup/verify",
                body: StartupVerifyBody(token: token)
            )
            if response.success {
                phase = .completed
            } else {
                phase = .failed("验证失败，请重试")
            }
        } catch {
            logger.error("Startup verify failed: \(error.localizedDescription)")
            phase = .failed("网络连接失败，请检查网络后重试")
        }
    }

    public func retry() {
        phase = .captcha
    }
}

// MARK: - DTOs

private struct StartupVerifyBody: Codable, Sendable {
    let token: String
}

private struct StartupVerifyResponse: Codable, Sendable {
    let success: Bool
    let bypassed: String?
}
