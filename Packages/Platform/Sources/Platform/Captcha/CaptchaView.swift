import SwiftUI
import WebKit

/// A SwiftUI view that wraps `CaptchaWebView` with loading and error states.
///
/// Shows a progress indicator while the captcha loads, transitions to
/// the web view, and displays an error with retry if something goes wrong.
public struct CaptchaView: View {
    let config: CaptchaConfig
    let onToken: (String) -> Void

    @State private var isLoading = true
    @State private var error: CaptchaError?
    @State private var viewID = UUID()

    public init(config: CaptchaConfig, onToken: @escaping (String) -> Void) {
        self.config = config
        self.onToken = onToken
    }

    public var body: some View {
        VStack(spacing: 16) {
            if let error {
                errorView(error)
            } else if isLoading {
                loadingView
            }

            CaptchaWebView(
                config: config,
                onToken: { token in
                    isLoading = false
                    error = nil
                    onToken(token)
                },
                onError: { captchaError in
                    isLoading = false
                    error = captchaError
                }
            )
            .id(viewID)
            .frame(height: 80)
            .opacity(isLoading ? 0 : 1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ProgressView("Loading captcha…")
            .progressViewStyle(.circular)
    }

    // MARK: - Error View

    private func errorView(_ error: CaptchaError) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                retry()
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Actions

    private func retry() {
        isLoading = true
        error = nil
        viewID = UUID()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CaptchaView(
            config: .turnstile(siteKey: "1x00000000000000000000AA", action: "preview"),
            onToken: { print("Token: \($0)") }
        )
        .padding()

        Divider()

        CaptchaView(
            config: .tongjiCaptcha(action: "preview"),
            onToken: { print("Token: \($0)") }
        )
        .padding()
    }
}
