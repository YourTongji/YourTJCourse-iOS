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

    private let reviewRepo: ReviewRepository
    private let walletRepo: WalletRepository

    public init(reviewRepo: ReviewRepository = .init(), walletRepo: WalletRepository = .init()) {
        self.reviewRepo = reviewRepo
        self.walletRepo = walletRepo
    }

    public func loadMyReviews() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let userHash = walletRepo.loadWallet()?.userHash else {
            error = "请先创建积分钱包"
            return
        }

        do {
            entries = try await reviewRepo.getMyReviews(walletUserHash: userHash)
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func refresh() async {
        entries = []
        await loadMyReviews()
    }
}
