import Foundation
import Observation
import DataKit
import DomainKit

@MainActor
@Observable
public final class MyReviewsViewModel {
    public private(set) var entries: [MyReviewEntry] = []
    public private(set) var isLoading = true
    public private(set) var error: String?
    public var editingEntry: MyReviewEntry?

    private let localReviewStore: LocalReviewStore

    public init(localReviewStore: LocalReviewStore = .init()) {
        self.localReviewStore = localReviewStore
    }

    public func loadMyReviews() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        entries = localReviewStore.loadMine()
    }

    public func reloadFromLocalStore() {
        error = nil
        entries = localReviewStore.loadMine()
        isLoading = false
    }

    public func refresh() async {
        entries = []
        await loadMyReviews()
    }
}
