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

                Section("开课院系") {
                    if viewModel.departments.isEmpty {
                        ProgressView("加载院系...")
                    } else {
                        ForEach(viewModel.departments, id: \.self) { department in
                            Button {
                                toggleDepartment(department)
                            } label: {
                                HStack {
                                    Text(department)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if viewModel.selectedDepartments.contains(department) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.cyan)
                                    }
                                }
                            }
                        }
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
            .task {
                await viewModel.loadDepartments()
            }
        }
    }

    private func toggleDepartment(_ department: String) {
        if viewModel.selectedDepartments.contains(department) {
            viewModel.selectedDepartments.removeAll { $0 == department }
        } else {
            viewModel.selectedDepartments.append(department)
        }
    }
}

// MARK: - Previews

#Preview("FilterSheetView") {
    FilterSheetView(viewModel: CatalogViewModel())
}
