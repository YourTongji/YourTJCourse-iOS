import Foundation
import Observation
import DomainKit
import DataKit
import Platform

@MainActor
@Observable
public final class WalletViewModel {
    public private(set) var phase: WalletPhase = .checking
    public private(set) var userHash: String = ""
    public private(set) var userSecret: String = ""
    public private(set) var mnemonic: [String] = []
    public private(set) var showMnemonic = false
    public private(set) var error: String?
    public private(set) var remoteError: String?
    public private(set) var isProcessing = false
    public private(set) var isRefreshing = false
    public private(set) var balance: Int?
    public private(set) var summary: WalletSummary?
    public private(set) var transactions: [WalletTransaction] = []
    public private(set) var transactionPage = 1
    public private(set) var transactionHasMore = false
    public private(set) var isLoadingTransactions = false
    public private(set) var transactionError: String?

    public var studentId: String = ""
    public var pin: String = ""
    public var restoreInput: String = ""

    private let walletRepo: WalletRepository
    private let logger = AppLogger(category: "Wallet")
    private var pendingWallet: WalletCredentials?

    public enum WalletPhase: Equatable {
        case checking     // initial loading
        case exists       // wallet already created
        case create       // show create/restore options
        case newWallet    // show new mnemonic for backup
        case restore      // enter mnemonic to restore
        case ready        // wallet is ready
    }

    public init(walletRepo: WalletRepository = .init()) {
        self.walletRepo = walletRepo
    }

    public func checkWallet() async {
        phase = .checking
        if let wallet = walletRepo.loadWallet() {
            userHash = wallet.userHash
            userSecret = wallet.userSecret
            phase = .ready
            await refreshRemoteState(register: true)
        } else {
            userHash = ""
            userSecret = ""
            balance = nil
            summary = nil
            resetTransactionHistory()
            phase = .create
        }
    }

    public func loginOrRegisterWallet() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        error = nil

        do {
            let repo = walletRepo
            let studentId = studentId.trimmingCharacters(in: .whitespacesAndNewlines)
            let pin = pin
            let wallet = try await Task.detached(priority: .userInitiated) {
                try repo.generateWallet(studentId: studentId, pin: pin)
            }.value

            if try await walletExists(userHash: wallet.userHash) {
                let remoteWallet = try await walletRepo.registerWallet(wallet)
                try walletRepo.saveWallet(wallet)
                userHash = wallet.userHash
                userSecret = wallet.userSecret
                mnemonic = []
                pendingWallet = nil
                showMnemonic = false
                balance = remoteWallet.balance
                phase = .ready
                await refreshRemoteState(register: false)
                logger.info("Wallet logged in from student ID and PIN")
            } else {
                pendingWallet = wallet
                mnemonic = wallet.mnemonic.components(separatedBy: "-")
                userHash = wallet.userHash
                userSecret = wallet.userSecret
                showMnemonic = false
                phase = .newWallet
            }
        } catch {
            logger.error("Failed to generate wallet: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    public func revealMnemonic() {
        showMnemonic = true
    }

    public func startRestore() {
        restoreInput = ""
        error = nil
        phase = .restore
    }

    public func cancelRestore() {
        restoreInput = ""
        error = nil
        phase = .create
    }

    public func confirmBackedUp() async {
        guard !isProcessing else { return }
        guard let wallet = pendingWallet else {
            error = "钱包状态异常，请重新生成"
            phase = .create
            return
        }

        isProcessing = true
        error = nil

        do {
            let remoteWallet = try await walletRepo.registerWallet(wallet)
            try walletRepo.saveWallet(wallet)
            mnemonic = []
            pendingWallet = nil
            showMnemonic = false
            balance = remoteWallet.balance
            phase = .ready
            await refreshRemoteState(register: false)
            logger.info("Wallet saved to Keychain")
        } catch {
            logger.error("Failed to save wallet: \(error.localizedDescription)")
            self.error = error.localizedDescription
            phase = .newWallet
            showMnemonic = true
        }

        isProcessing = false
    }

    public func restoreWallet() async {
        guard !isProcessing else { return }
        isProcessing = true
        error = nil

        do {
            let repo = walletRepo
            let input = restoreInput
            let wallet = try await Task.detached(priority: .userInitiated) {
                try repo.restoreWallet(from: repo.normalizeMnemonic(input))
            }.value
            let remoteWallet = try await walletRepo.registerWallet(wallet)
            try walletRepo.saveWallet(wallet)
            userHash = wallet.userHash
            userSecret = wallet.userSecret
            mnemonic = []
            pendingWallet = nil
            restoreInput = ""
            showMnemonic = false
            balance = remoteWallet.balance
            phase = .ready
            await refreshRemoteState(register: false)
            logger.info("Wallet restored from mnemonic")
        } catch {
            logger.error("Failed to save restored wallet: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }

        isProcessing = false
    }

    public func deleteWallet() {
        do {
            try walletRepo.deleteWallet()
            phase = .create
            userHash = ""
            userSecret = ""
            mnemonic = []
            pendingWallet = nil
            showMnemonic = false
            balance = nil
            summary = nil
            remoteError = nil
            resetTransactionHistory()
            studentId = ""
            pin = ""
            restoreInput = ""
        } catch {
            self.error = "删除钱包失败"
        }
    }

    public func refresh() async {
        await refreshRemoteState(register: false)
    }

    public func dismissError() {
        error = nil
    }

    public func loadTransactions() async {
        let hash = userHash
        guard !hash.isEmpty else {
            resetTransactionHistory()
            return
        }
        isLoadingTransactions = true
        transactionError = nil
        transactionPage = 1
        transactions = []
        transactionHasMore = false
        defer { isLoadingTransactions = false }
        do {
            let resp = try await walletRepo.fetchTransactionHistory(userHash: hash, page: 1)
            guard userHash == hash else { return }
            transactions = resp.data
            transactionHasMore = resp.hasMore
        } catch {
            guard userHash == hash else { return }
            transactionError = error.localizedDescription
        }
    }

    public func loadMoreTransactions() async {
        let hash = userHash
        guard !hash.isEmpty, transactionHasMore, !isLoadingTransactions else { return }
        isLoadingTransactions = true
        defer { isLoadingTransactions = false }
        do {
            let nextPage = transactionPage + 1
            let resp = try await walletRepo.fetchTransactionHistory(userHash: hash, page: nextPage)
            guard userHash == hash else { return }
            transactions += resp.data
            transactionPage = nextPage
            transactionHasMore = resp.hasMore
        } catch {
            guard userHash == hash else { return }
            transactionError = error.localizedDescription
        }
    }

    public func refreshTransactions() async {
        await loadTransactions()
    }

    private func resetTransactionHistory() {
        transactions = []
        transactionPage = 1
        transactionHasMore = false
        isLoadingTransactions = false
        transactionError = nil
    }

    private func walletExists(userHash: String) async throws -> Bool {
        do {
            _ = try await walletRepo.fetchWallet(userHash: userHash)
            return true
        } catch APIError.notFound {
            return false
        } catch APIError.httpError(let statusCode, _) where statusCode == 404 {
            return false
        } catch {
            throw error
        }
    }

    private func refreshRemoteState(register: Bool) async {
        guard !userHash.isEmpty else { return }

        isRefreshing = true
        remoteError = nil
        defer { isRefreshing = false }

        if register, !userSecret.isEmpty {
            do {
                let credentials = WalletCredentials(mnemonic: "", userHash: userHash, userSecret: userSecret)
                let remoteWallet = try await walletRepo.registerWallet(credentials)
                balance = remoteWallet.balance
            } catch {
                remoteError = "钱包同步失败：\(error.localizedDescription)"
                logger.error("Failed to register wallet with Credit service: \(error.localizedDescription)")
            }
        }

        do {
            let balanceResponse = try await walletRepo.fetchBalance(userHash: userHash)
            balance = balanceResponse.balance
        } catch {
            remoteError = "余额刷新失败：\(error.localizedDescription)"
            logger.error("Failed to fetch wallet balance: \(error.localizedDescription)")
        }

        do {
            summary = try await walletRepo.fetchJCourseSummary(userHash: userHash)
            if let summary {
                balance = summary.balance
            }
        } catch {
            if remoteError == nil {
                remoteError = "今日积分刷新失败：\(error.localizedDescription)"
            }
            logger.error("Failed to fetch wallet summary: \(error.localizedDescription)")
        }
    }
}
