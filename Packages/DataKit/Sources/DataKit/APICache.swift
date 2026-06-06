import Foundation

public struct APICache: Sendable {
    /// Configures shared URLCache settings.
    /// The primary URLCache is already configured inside `APIClient`.
    /// This method is available for any additional cache setup.
    public static func configureCache() {
        // URLCache is configured in APIClient's URLSessionConfiguration.
        // Additional tuning can be added here if needed in the future.
    }

    /// Evicts all cached responses from the shared URL cache.
    public static func removeAllCachedResponses() {
        URLCache.shared.removeAllCachedResponses()
    }
}
