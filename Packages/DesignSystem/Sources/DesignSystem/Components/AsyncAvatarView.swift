import SwiftUI

// MARK: - AsyncAvatarView

/// A circular avatar view that loads an image asynchronously from a URL.
///
/// Displays the first letters of the provided name as a monogram fallback
/// while the image loads or if loading fails.
public struct AsyncAvatarView: View {

    private let url: URL?
    private let name: String
    private let size: CGFloat

    public init(
        url: URL?,
        name: String,
        size: CGFloat = 40
    ) {
        self.url = url
        self.name = name
        self.size = size
    }

    public var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(.circle)
            case .failure, .empty:
                monogramView
            @unknown default:
                monogramView
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: Monogram Fallback

    private var monogramView: some View {
        ZStack {
            Circle()
                .fill(AppColors.cyanLight)

            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(AppColors.cyanDark)
        }
        .frame(width: size, height: size)
    }

    private var initials: String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        let prefix = parts.prefix(2).compactMap { $0.first.map(String.init) }
        return prefix.isEmpty ? "?" : prefix.joined()
    }
}

// MARK: - Previews

#Preview("AsyncAvatarView - With URL") {
    AsyncAvatarView(
        url: URL(string: "https://i.pravatar.cc/80"),
        name: "John Doe",
        size: 60
    )
}

#Preview("AsyncAvatarView - Fallback") {
    AsyncAvatarView(
        url: nil,
        name: "李华",
        size: 60
    )
}

#Preview("AsyncAvatarView - Sizes") {
    HStack(spacing: 12) {
        AsyncAvatarView(url: nil, name: "Alice", size: 32)
        AsyncAvatarView(url: nil, name: "Bob", size: 40)
        AsyncAvatarView(url: nil, name: "Charlie", size: 56)
    }
}
