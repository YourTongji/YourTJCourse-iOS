import Foundation
import CryptoKit

public enum HMACHelper: Sendable {
    /// Computes `edit_token = HMAC-SHA256(userSecret, "jcourse:edit-review:" + reviewId)`.
    ///
    /// This algorithm must remain consistent with the backend implementation
    /// in `YourTJCourse-Serverless` (see `routes/public.ts`).
    ///
    /// - Parameters:
    ///   - reviewId: The review's numeric ID.
    ///   - userSecret: The wallet-derived user secret.
    /// - Returns: Lowercase hex-encoded HMAC-SHA256 digest.
    public static func editToken(reviewId: Int, userSecret: String) -> String {
        let key = SymmetricKey(data: Data(userSecret.utf8))
        let message = Data("jcourse:edit-review:\(reviewId)".utf8)
        let mac = HMAC<SHA256>.authenticationCode(for: message, using: key)
        return mac.map { String(format: "%02x", $0) }.joined()
    }
}
