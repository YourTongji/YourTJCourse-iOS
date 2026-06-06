import SwiftUI

// MARK: - RatingView

/// A read-only star-rating display on a 0–5 scale.
///
/// Uses SF Symbols: `star.fill` (filled), `star.leadinghalf.filled` (half),
/// and `star` (empty). Supports customizable size and color.
public struct RatingView: View {

    private let rating: Double
    private let size: CGFloat
    private let color: Color
    private let maxStars: Int

    public init(
        rating: Double,
        size: CGFloat = 14,
        color: Color = AppColors.accent,
        maxStars: Int = 5
    ) {
        self.rating = rating
        self.size = size
        self.color = color
        self.maxStars = maxStars
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maxStars, id: \.self) { index in
                image(for: index)
                    .font(.system(size: size))
                    .foregroundStyle(color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(String(format: "%.1f", rating)) out of \(maxStars) stars")
    }

    // MARK: Helpers

    private func image(for index: Int) -> Image {
        let starValue = Double(index) + 1.0
        if rating >= starValue {
            return Image(systemName: "star.fill")
        } else if rating >= starValue - 0.5 {
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            return Image(systemName: "star")
        }
    }
}

// MARK: - Previews

#Preview("RatingView - Full") {
    RatingView(rating: 4.5, size: 20)
}

#Preview("RatingView - Various") {
    VStack(spacing: 8) {
        RatingView(rating: 5.0, size: 16)
        RatingView(rating: 3.5, size: 16)
        RatingView(rating: 2.0, size: 16)
        RatingView(rating: 0.5, size: 16)
        RatingView(rating: 0.0, size: 16)
    }
}

#Preview("RatingView - Custom Color") {
    RatingView(rating: 3.0, size: 24, color: .orange)
}
