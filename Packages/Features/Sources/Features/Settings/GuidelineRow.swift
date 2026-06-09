import SwiftUI

// MARK: - Guideline Row

struct GuidelineRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.cyan)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview("Guideline Row") {
    GuidelineRow(icon: "heart", text: "尊重他人")
}
