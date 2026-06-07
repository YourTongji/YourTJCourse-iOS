import Foundation
import Observation
import DomainKit
import DataKit
import Platform

@MainActor
@Observable
public final class StartupViewModel {
    public enum FailureRecovery: Equatable {
        case runtimeState
        case captcha
    }

    public enum Phase: Equatable {
        case loading
        case maintenance(maintenance: MaintenanceConfig?)
        case captcha
        case verifying
        case failed(String, recovery: FailureRecovery)
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
            phase = .failed("无法获取运行状态，请检查网络后重试", recovery: .runtimeState)
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
                if response.bypassed == "maintenance_mode" {
                    await enterMaintenanceModeAfterBypass()
                } else {
                    phase = .completed
                }
            } else {
                phase = .failed("验证失败，请重试", recovery: .captcha)
            }
        } catch {
            logger.error("Startup verify failed: \(error.localizedDescription)")
            phase = .failed(error.localizedDescription, recovery: .captcha)
        }
    }

    public func retry() async {
        switch phase {
        case .failed(_, recovery: .runtimeState):
            await checkRuntimeState()
        default:
            phase = .captcha
        }
    }

    private func enterMaintenanceModeAfterBypass() async {
        do {
            let state = try await settingsRepo.getRuntimeState()
            announcements = state.announcements
            phase = .maintenance(maintenance: state.maintenance.config)
        } catch {
            logger.error("Failed to load maintenance config after bypass: \(error.localizedDescription)")
            phase = .maintenance(maintenance: nil)
        }
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
