import SwiftUI
import MarkdownUI

extension Theme {

    /// Custom theme for the YourTJCourse app.
    ///
    /// Styling decisions:
    /// - Body text: standard size, primary color
    /// - Headings: bold, larger with increased spacing
    /// - Links: brand cyan
    /// - Code blocks: monospace with subtle background
    /// - Blockquotes: italic with left border
    /// - Lists: proper spacing
    /// - Container: transparent for embedding in cards
    @MainActor
    static var custom: Theme {
        Theme()
        .text {
            ForegroundColor(.textPrimary)
            FontSize(16)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
            BackgroundColor(.codeBackground)
        }
        .strong {
            FontWeight(.semibold)
        }
        .link {
            ForegroundColor(.cyan)
        }
        .heading1 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.125))
                .markdownMargin(top: 24, bottom: 16)
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(2))
                }
        }
        .heading2 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.125))
                .markdownMargin(top: 20, bottom: 16)
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(1.5))
                }
        }
        .heading3 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.125))
                .markdownMargin(top: 16, bottom: 12)
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(1.25))
                }
        }
        .heading4 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.125))
                .markdownMargin(top: 16, bottom: 12)
                .markdownTextStyle {
                    FontWeight(.bold)
                }
        }
        .heading5 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.125))
                .markdownMargin(top: 12, bottom: 12)
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(0.875))
                }
        }
        .heading6 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.125))
                .markdownMargin(top: 12, bottom: 12)
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(0.85))
                }
        }
        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.25))
                .markdownMargin(top: 0, bottom: 16)
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.cyan.opacity(0.5))
                    .relativeFrame(width: .em(0.2))
                configuration.label
                    .markdownTextStyle {
                        FontStyle(.italic)
                        ForegroundColor(.textSecondary)
                    }
                    .relativePadding(.horizontal, length: .em(1))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .codeBlock { configuration in
            ScrollView(.horizontal) {
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.225))
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.85))
                    }
                    .padding(16)
            }
            .background(Color.codeBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .markdownMargin(top: 0, bottom: 16)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.25))
        }
        .taskListMarker { configuration in
            Image(systemName: configuration.isCompleted ? "checkmark.square.fill" : "square")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.cyan, Color.codeBackground)
                .imageScale(.small)
                .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
        }
        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .markdownTableBorderStyle(.init(color: .border))
                .markdownTableBackgroundStyle(
                    .alternatingRows(Color.clear, Color.codeBackground)
                )
                .markdownMargin(top: 0, bottom: 16)
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    if configuration.row == 0 {
                        FontWeight(.semibold)
                    }
                    BackgroundColor(nil)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
                .padding(.horizontal, 13)
                .relativeLineSpacing(.em(0.25))
        }
        .thematicBreak {
            Divider()
                .relativeFrame(height: .em(0.25))
                .overlay(Color.border)
                .markdownMargin(top: 24, bottom: 24)
        }
    }
}

// MARK: - Color Helpers

private extension Color {
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let codeBackground = Color(.systemGray6)
    static let border = Color(.separator)
}
