import SwiftUI

#if canImport(MarkdownUI)
import MarkdownUI
#endif

// MARK: - MarkdownContentView

/// Renders markdown-formatted text, preferring `swift-markdown-ui` when
/// available, falling back to `AttributedString`-based rendering.
///
/// In the future, the Platform package will provide a more sophisticated
/// implementation. This basic version ensures reviews are never rendered
/// via WKWebView (preventing XSS as required by AGENTS.md).
public struct MarkdownContentView: View {

    private let content: String

    public init(_ content: String) {
        self.content = content
    }

    public var body: some View {
#if canImport(MarkdownUI)
        if #available(iOS 15, *) {
            Markdown(content)
                .textSelection(.enabled)
        } else {
            attributedStringBody
        }
#else
        attributedStringBody
#endif
    }

    // MARK: - AttributedString Fallback

    /// Renders markdown by converting to `AttributedString`.
    /// This handles bold, italic, links, and paragraphs.
    private var attributedStringBody: some View {
        Group {
            if let attributed = try? AttributedString(markdown: content) {
                Text(attributed)
                    .textSelection(.enabled)
            } else {
                Text(content)
                    .textSelection(.enabled)
            }
        }
    }
}

// MARK: - Previews

#Preview("MarkdownContentView") {
    VStack(alignment: .leading, spacing: 16) {
        MarkdownContentView("""
        老师讲课**非常清晰**，板书工整。
        * 知识点覆盖全面
        * 作业量适中
        * 给分友好
        """)
    }
    .padding()
}
