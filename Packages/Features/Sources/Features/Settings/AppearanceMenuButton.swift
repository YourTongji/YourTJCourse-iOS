import SwiftUI
import DesignSystem

// MARK: - Appearance Menu Button

/// A circular toolbar button that expands into a menu for choosing the app's
/// light/dark/system appearance. The icon reflects the current selection.
struct AppearanceMenuButton: View {
    @Binding var selectionRawValue: String

    private var selection: AppAppearancePreference {
        AppAppearancePreference.resolve(selectionRawValue)
    }

    var body: some View {
        Menu {
            Picker("外观", selection: $selectionRawValue) {
                ForEach(AppAppearancePreference.allCases) { preference in
                    Label(preference.title, systemImage: preference.iconName)
                        .tag(preference.rawValue)
                }
            }
        } label: {
            Image(systemName: selection.iconName)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppColors.cyan)
                .frame(width: 32, height: 32)
                .background(AppColors.cyan.opacity(0.14), in: Circle())
                .overlay(Circle().stroke(AppColors.cyan.opacity(0.25), lineWidth: 1))
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel("外观模式")
        .accessibilityValue(selection.title)
    }
}
