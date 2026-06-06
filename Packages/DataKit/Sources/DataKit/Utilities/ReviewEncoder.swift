import Foundation

/// Utility for converting between review IDs and their Sqid-encoded strings.
///
/// The backend uses Sqids (https://sqids.org) to encode review IDs into
/// short, URL-safe strings. On the iOS side, Sqid strings are primarily
/// used for display and sharing; direct ID-to-sqid conversion is handled
/// by the corresponding DomainKit model when applicable.
///
/// This type serves as a placeholder for future Sqid encoding/decoding
/// if the iOS client ever needs to generate or validate Sqid strings
/// independently.
public enum ReviewEncoder: Sendable {
    /// Placeholder: returns the integer as a string.
    /// Replace with actual Sqid encoding when needed.
    public static func encode(_ id: Int) -> String {
        String(id)
    }

    /// Placeholder: parses the string as an integer.
    /// Replace with actual Sqid decoding when needed.
    public static func decode(_ sqid: String) -> Int? {
        Int(sqid)
    }
}
