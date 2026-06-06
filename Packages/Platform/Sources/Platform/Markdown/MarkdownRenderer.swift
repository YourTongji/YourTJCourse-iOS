import SwiftUI
import MarkdownUI

/// A view that renders markdown content natively using `swift-markdown-ui`.
///
/// Uses the app's custom `.custom` theme and is safe to embed inside cards
/// and other containers (no background on the outer container).
public struct MarkdownRenderer: View {
    let content: String

    public init(_ content: String) {
        self.content = content
    }

    public var body: some View {
        Markdown(content)
            .markdownTheme(.custom)
    }
}

// MARK: - Preview

#Preview("Simple Markdown") {
    ScrollView {
        MarkdownRenderer("""
        # Hello
        This is **bold** and *italic* text.

        > A wise quote.
        """)
        .padding()
    }
}

#Preview("Full Example") {
    ScrollView {
        MarkdownRenderer("""
        # Heading 1
        ## Heading 2
        ### Heading 3

        Regular body text with a [link to somewhere](https://example.com).

        - List item one
        - List item two
        - List item three

        ```
        let code = "Hello, world!"
        print(code)
        ```

        > Blockquote with some italic wisdom.
        """)
        .padding()
    }
}
