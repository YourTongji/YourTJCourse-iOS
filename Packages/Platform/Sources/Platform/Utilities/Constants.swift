import Foundation

/// App-wide constants for the YourTJCourse iOS app.
///
/// API base URLs are configured at build time via `Config/*.xcconfig`
/// and exposed through `Info.plist`. The defaults here correspond to
/// the production environment.
public enum AppConstants {

    // MARK: - API

    /// The base URL for the YourTJCourse API.
    /// Override at build time via `API_BASE` in `.xcconfig`.
    public static let apiBaseURL: URL = {
        let production = URL(
            string: "https://jcourse.yourtj.de"
        ) ?? AppConstants.fallbackURL
        guard let configValue = Bundle.main.object(
            forInfoDictionaryKey: "API_BASE"
        ) as? String, let url = URL(string: configValue) else {
            return production
        }
        return url
    }()

    /// The base URL for the Credit service.
    /// Override at build time via `CREDIT_API_BASE` in `.xcconfig`.
    public static let creditBaseURL: URL = {
        let production = URL(
            string: "https://core.credit.yourtj.de"
        ) ?? AppConstants.fallbackURL
        guard let configValue = Bundle.main.object(
            forInfoDictionaryKey: "CREDIT_API_BASE"
        ) as? String, let url = URL(string: configValue) else {
            return production
        }
        return url
    }()

    // MARK: - Captcha

    /// Cloudflare Turnstile site key for the production environment.
    public static let turnstileSiteKey = "0x4AAAAAAAXXX"

    // MARK: - App Group

    /// App group identifier for shared UserDefaults / Keychain access
    /// between the main app and extensions.
    public static let appGroupIdentifier = "group.com.yourtj.course"

    // MARK: - Internal

    /// A guaranteed-valid fallback URL used when the production URL
    /// constant cannot be constructed (should never happen in practice).
    private static let fallbackURL = URL(fileURLWithPath: "/")
}
