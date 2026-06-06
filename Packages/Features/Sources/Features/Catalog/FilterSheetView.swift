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
                    TextField("课名", text: $viewModel.courseNameFilter)
                        .textInputAutocapitalization(.never)
                    TextField("课号", text: $viewModel.courseCodeFilter)
                        .textInputAutocapitalization(.never)
                    TextField("教师", text: $viewModel.teacherNameFilter)
                        .textInputAutocapitalization(.never)
                    TextField("校区", text: $viewModel.campusFilter)
                        .textInputAutocapitalization(.never)
                    TextField("开课院系", text: $viewModel.facultyFilter)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("高级检索")
                } footer: {
                    Text("这些条件直接使用后端高级检索能力，可与首页关键词搜索同时生效。")
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
                    Button("应用筛选", action: applyFilters)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.glassProminent)

                    Button("重置") {
                        viewModel.resetFilters()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: applyFilters)
                }
            }
            .task {
                await viewModel.loadDepartments()
            }
        }
    }

    private func applyFilters() {
        Task { await viewModel.loadInitial() }
        dismiss()
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
