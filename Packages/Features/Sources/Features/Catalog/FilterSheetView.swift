import SwiftUI
import DomainKit
import DesignSystem

struct FilterSheetView: View {
    @Bindable var viewModel: CatalogViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("筛选条件") {
                    Toggle(isOn: $viewModel.onlyWithReviews) {
                        Label("只看有评价", systemImage: "text.bubble")
                    }
                }

                Section {
                    Button("应用筛选") {
                        Task { await viewModel.loadInitial() }
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.glassProminent)

                    Button("重置") {
                        viewModel.onlyWithReviews = false
                        viewModel.selectedDepartments = []
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("FilterSheetView") {
    FilterSheetView(viewModel: CatalogViewModel())
}
