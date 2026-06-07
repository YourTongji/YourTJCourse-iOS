import SwiftUI
import DomainKit
import DesignSystem

public struct CatalogView: View {
    @State private var viewModel = CatalogViewModel()
    @State private var showFilter = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.courses.isEmpty {
                    LoadingView(message: "加载课程...")
                } else if let error = viewModel.error, viewModel.courses.isEmpty {
                    ErrorStateView(
                        message: error,
                        retryTitle: "重试",
                        retryAction: { Task { await viewModel.refresh() } }
                    )
                } else if viewModel.courses.isEmpty {
                    EmptyStateView(
                        icon: "book.closed",
                        message: viewModel.searchText.isEmpty ? "暂无课程" : "未找到匹配的课程",
                        actionTitle: nil,
                        action: nil
                    )
                } else {
                    courseList
                }
            }
            .navigationTitle("课程")
            .searchable(text: $viewModel.searchText, prompt: "搜索课程、教师、课号")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilter = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilter) {
                FilterSheetView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadInitialIfNeeded()
            }
        }
    }

    private var courseList: some View {
        List {
            ForEach(viewModel.courses) { course in
                NavigationLink {
                    CourseDetailView(courseId: course.id)
                } label: {
                    CourseCard(
                        name: course.name,
                        code: course.code,
                        teacher: course.teacherName,
                        department: course.department,
                        rating: course.rating,
                        reviewCount: course.reviewCount,
                        credit: course.credit,
                        semesterTags: course.semesters
                    )
                }
                .buttonStyle(.plain)
                .onAppear {
                    if course.id == viewModel.courses.last?.id {
                        Task { await viewModel.loadMore() }
                    }
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Previews

#Preview("CatalogView - Loading") {
    CatalogView()
}
