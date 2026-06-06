import Foundation

/// A helper for reading the app version and build number from `Info.plist`.
public enum AppVersion {

    /// The semantic version string (e.g. "1.2.3").
    ///
    /// Reads `CFBundleShortVersionString` from the main bundle's `Info.plist`.
    /// Returns `"0.0.0"` if the key is missing.
    public static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.0.0"
    }

    /// The build number string (e.g. "42").
    ///
    /// Reads `CFBundleVersion` from the main bundle's `Info.plist`.
    /// Returns `"0"` if the key is missing.
    public static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "0"
    }

    /// A combined display string (e.g. "1.2.3 (42)").
    public static var displayString: String {
        "\(version) (\(build))"
    }
}
