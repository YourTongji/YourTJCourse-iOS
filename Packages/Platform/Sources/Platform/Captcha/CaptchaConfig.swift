import Foundation

/// Configuration for captcha providers supported by the app.
public enum CaptchaConfig: Sendable {
    /// Cloudflare Turnstile with a site key and action name.
    case turnstile(siteKey: String, action: String)
    /// Tongji captcha with an action name.
    case tongjiCaptcha(action: String)

    /// The URL used for server-side verification of the captcha token.
    public var siteVerifyURL: String {
        switch self {
        case .turnstile:
            "https://challenges.cloudflare.com/turnstile/v0/siteverify"
        case .tongjiCaptcha:
            "https://captcha.tongji.edu.cn/api/verify"
        }
    }

    /// The JavaScript source URL for the captcha widget.
    var scriptURL: String {
        switch self {
        case .turnstile:
            "https://challenges.cloudflare.com/turnstile/v0/api.js"
        case .tongjiCaptcha:
            "https://captcha.tongji.edu.cn/captcha/script/api.js"
        }
    }

    /// The JavaScript callback name used by the captcha provider.
    var callbackName: String {
        switch self {
        case .turnstile:
            "turnstileCallback"
        case .tongjiCaptcha:
            "tongjiCallback"
        }
    }

    /// The render parameters to embed into the captcha div.
    var renderAttributes: String {
        switch self {
        case let .turnstile(siteKey, action):
            #"data-sitekey="\#(siteKey)" data-action="\#(action)""#
        case let .tongjiCaptcha(action):
            #"data-action="\#(action)""#
        }
    }
}
