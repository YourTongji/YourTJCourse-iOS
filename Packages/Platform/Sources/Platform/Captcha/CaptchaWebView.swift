import SwiftUI
import WebKit

/// A SwiftUI wrapper around WKWebView for captcha verification.
///
/// Loads a minimal HTML page with the captcha widget and communicates
/// the token back via `WKScriptMessageHandler`.
public struct CaptchaWebView: UIViewRepresentable {
    let config: CaptchaConfig
    let onToken: @Sendable (String) -> Void
    let onError: @Sendable (CaptchaError) -> Void

    public init(
        config: CaptchaConfig,
        onToken: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (CaptchaError) -> Void
    ) {
        self.config = config
        self.onToken = onToken
        self.onError = onError
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onToken: onToken, onError: onError)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()

        userContentController.add(
            context.coordinator,
            name: CaptchaMessageHandler.name
        )

        config.userContentController = userContentController

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false

        loadCaptcha(in: webView)

        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        // No-op; the captcha is loaded once on creation.
    }

    // MARK: - HTML Generation

    private func loadCaptcha(in webView: WKWebView) {
        let html = CaptchaHTMLBuilder.build(for: config)
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - Coordinator

extension CaptchaWebView {
    public final class Coordinator: NSObject, WKScriptMessageHandler {
        private let onToken: @Sendable (String) -> Void
        private let onError: @Sendable (CaptchaError) -> Void

        init(
            onToken: @escaping @Sendable (String) -> Void,
            onError: @escaping @Sendable (CaptchaError) -> Void
        ) {
            self.onToken = onToken
            self.onError = onError
        }

        public func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == CaptchaMessageHandler.name else { return }

            let result: CaptchaResult
            if let token = message.body as? String, !token.isEmpty {
                result = .success(token)
            } else if let dict = message.body as? [String: Any],
                      let errorMessage = dict["error"] as? String {
                result = .failure(.providerError(errorMessage))
            } else {
                result = .failure(.invalidToken)
            }

            // WKScriptMessageHandler can be called from a background thread;
            // dispatch to the main actor since callbacks typically update UI state.
            Task { @MainActor in
                switch result {
                case let .success(token):
                    onToken(token)
                case let .failure(error):
                    onError(error)
                }
            }
        }
    }
}

// MARK: - Internal Types

private enum CaptchaResult {
    case success(String)
    case failure(CaptchaError)
}

private enum CaptchaMessageHandler {
    static let name = "captchaBridge"
}

// MARK: - HTML Builder

private enum CaptchaHTMLBuilder {
    static func build(for config: CaptchaConfig) -> String {
        switch config {
        case .turnstile:
            turnstileHTML(config: config)
        case .tongjiCaptcha:
            tongjiHTML(config: config)
        }
    }

    private static func turnstileHTML(config: CaptchaConfig) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
            <script src="\(config.scriptURL)" async defer></script>
            <style>
                body { margin: 0; display: flex; justify-content: center; align-items: center; min-height: 100vh; background: transparent; }
                .cf-turnstile { transform: scale(0.85); transform-origin: center; }
            </style>
        </head>
        <body>
            <div class="cf-turnstile" \(config.renderAttributes) data-callback="\(config.callbackName)"></div>
            <script>
                function \(config.callbackName)(token) {
                    window.webkit.messageHandlers.\(CaptchaMessageHandler.name).postMessage(token);
                }
                window.addEventListener('error', function(e) {
                    window.webkit.messageHandlers.\(CaptchaMessageHandler.name).postMessage({ error: e.message || 'Unknown error' });
                });
            </script>
        </body>
        </html>
        """
    }

    private static func tongjiHTML(config: CaptchaConfig) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
            <script src="\(config.scriptURL)"></script>
            <style>
                body { margin: 0; display: flex; justify-content: center; align-items: center; min-height: 100vh; background: transparent; }
            </style>
        </head>
        <body>
            <div id="captcha-container"></div>
            <script>
                function \(config.callbackName)(token) {
                    window.webkit.messageHandlers.\(CaptchaMessageHandler.name).postMessage(token);
                }
                function initCaptcha() {
                    if (typeof turnstile !== 'undefined') {
                        turnstile.render('#captcha-container', {
                            callback: \(config.callbackName)
                        });
                    } else {
                        window.webkit.messageHandlers.\(CaptchaMessageHandler.name).postMessage({ error: 'Captcha SDK not loaded' });
                    }
                }
                document.addEventListener('DOMContentLoaded', initCaptcha);
                window.addEventListener('error', function(e) {
                    window.webkit.messageHandlers.\(CaptchaMessageHandler.name).postMessage({ error: e.message || 'Unknown error' });
                });
            </script>
        </body>
        </html>
        """
    }
}

// MARK: - Errors

/// Errors that can occur during captcha verification.
public enum CaptchaError: Error, Sendable {
    /// The captcha provider returned an error message.
    case providerError(String)
    /// The received token was empty or invalid.
    case invalidToken
    /// The captcha widget failed to load.
    case loadFailed(description: String)
}

extension CaptchaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .providerError(message):
            "Captcha error: \(message)"
        case .invalidToken:
            "Invalid captcha token received."
        case let .loadFailed(description):
            "Failed to load captcha: \(description)"
        }
    }
}
