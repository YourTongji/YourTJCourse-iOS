import SwiftUI
import DomainKit
import DesignSystem

public struct CatalogView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel = CatalogViewModel()
    @State private var showFilter = false
    @State private var selectedCourseId: Int?
    @State private var detailPath: [CourseDetailDestination] = []

    public init() {}

    public var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                splitCatalog
            } else {
                compactCatalog
            }
        }
        .sheet(isPresented: $showFilter) {
            FilterSheetView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadInitialIfNeeded()
            reconcileSelectedCourse()
        }
        .onChange(of: viewModel.courses.map(\.id)) { _, _ in
            reconcileSelectedCourse()
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            if !isLoading {
                reconcileSelectedCourse()
            }
        }
    }

    private var compactCatalog: some View {
        NavigationStack {
            catalogContent(mode: .compact)
            .navigationDestination(for: CourseDetailDestination.self) { dest in
                CourseDetailView(courseId: dest.courseId, showsRelatedCourses: dest.loadsRelatedCourses)
            }
            .catalogChrome(
                searchText: $viewModel.searchText,
                showFilter: $showFilter
            )
        }
    }

    private var splitCatalog: some View {
        NavigationSplitView {
            catalogContent(mode: .split)
                .catalogChrome(
                    searchText: $viewModel.searchText,
                    showFilter: $showFilter
                )
        } detail: {
            NavigationStack(path: $detailPath) {
                if let selectedCourseId {
                    CourseDetailView(courseId: selectedCourseId)
                        .id(selectedCourseId)
                } else {
                    ContentUnavailableView(
                        "选择课程",
                        systemImage: "book.closed",
                        description: Text("从左侧列表选择一门课程查看详情和课评。")
                    )
                }
            }
            .navigationDestination(for: CourseDetailDestination.self) { dest in
                CourseDetailView(courseId: dest.courseId, showsRelatedCourses: dest.loadsRelatedCourses)
                    .id(dest.courseId)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func catalogContent(mode: CatalogNavigationMode) -> some View {
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
            courseList(mode: mode)
        }
    }

    private func courseList(mode: CatalogNavigationMode) -> some View {
        List {
            ForEach(viewModel.courses) { course in
                courseRow(course, mode: mode)
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

    @ViewBuilder
    private func courseRow(_ course: Course, mode: CatalogNavigationMode) -> some View {
        switch mode {
        case .compact:
            NavigationLink(value: CourseDetailDestination(courseId: course.id)) {
                courseCard(course)
            }
            .buttonStyle(.plain)
        case .split:
            Button {
                selectCourse(course.id)
            } label: {
                courseCard(course)
            }
            .buttonStyle(.plain)
            .listRowBackground(course.id == selectedCourseId ? AppColors.cyan.opacity(0.08) : Color.clear)
        }
    }

    private func courseCard(_ course: Course) -> CourseCard {
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

    private func reconcileSelectedCourse() {
        if viewModel.courses.isEmpty {
            guard !viewModel.isLoading else { return }
            selectedCourseId = nil
            detailPath = []
            return
        }

        let courseIds = Set(viewModel.courses.map(\.id))
        if let selectedCourseId, courseIds.contains(selectedCourseId) {
            return
        }
        if let firstCourseId = viewModel.courses.first?.id {
            selectCourse(firstCourseId)
        }
    }

    private func selectCourse(_ courseId: Int) {
        selectedCourseId = courseId
        detailPath = []
    }
}

private enum CatalogNavigationMode {
    case compact
    case split
}

private struct CatalogChromeModifier: ViewModifier {
    @Binding var searchText: String
    @Binding var showFilter: Bool

    func body(content: Content) -> some View {
        content
            .navigationTitle("课程")
            .searchable(text: $searchText, prompt: "搜索课程、教师、课号")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilter = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("筛选")
                }
            }
    }
}

private extension View {
    func catalogChrome(searchText: Binding<String>, showFilter: Binding<Bool>) -> some View {
        modifier(CatalogChromeModifier(searchText: searchText, showFilter: showFilter))
    }
}

// MARK: - Previews

#Preview("CatalogView - Loading") {
    CatalogView()
}
