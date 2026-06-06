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
    public private(set) var isProcessing = false

    // Restore flow
    public var restoreInput: String = ""

    private let walletRepo: WalletRepository
    private let logger = AppLogger(category: "Wallet")

    public enum WalletPhase: Equatable {
        case checking     // initial loading
        case exists       // wallet already created
        case create       // show create/restore options
        case newWallet    // show new mnemonic for backup
        case confirmBackup // verify user backed up mnemonic
        case restore      // enter mnemonic to restore
        case ready        // wallet is ready
    }

    public init(walletRepo: WalletRepository = .init()) {
        self.walletRepo = walletRepo
    }

    public func checkWallet() async {
        phase = .checking
        if walletRepo.hasWallet() {
            if let wallet = walletRepo.loadWallet() {
                userHash = wallet.userHash
                userSecret = wallet.userSecret
                phase = .exists
            }
        } else {
            phase = .create
        }
    }

    public func createNewWallet() {
        do {
            let wallet = try walletRepo.generateWallet()
            mnemonic = wallet.mnemonic
            userHash = wallet.userHash
            userSecret = wallet.userSecret
            showMnemonic = false
            error = nil
            phase = .newWallet
        } catch {
            logger.error("Failed to generate wallet: \(error.localizedDescription)")
            self.error = "生成钱包失败，请稍后重试"
        }
    }

    public func revealMnemonic() {
        showMnemonic = true
    }

    public func startRestore() {
        phase = .restore
    }

    public func startBackupConfirmation() {
        phase = .confirmBackup
    }

    public func confirmBackedUp() {
        phase = .ready
        do {
            try walletRepo.saveWallet(mnemonic: mnemonic, userHash: userHash, userSecret: userSecret)
            logger.info("Wallet saved to Keychain")
        } catch {
            logger.error("Failed to save wallet: \(error.localizedDescription)")
            self.error = "保存钱包失败"
        }
    }

    public func restoreWallet() async {
        let words = restoreInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)

        guard let wallet = walletRepo.restoreWallet(from: words) else {
            error = "助记词无效，请检查后重试"
            return
        }

        userHash = wallet.userHash
        userSecret = wallet.userSecret
        mnemonic = words
        showMnemonic = false

        do {
            try walletRepo.saveWallet(mnemonic: words, userHash: userHash, userSecret: userSecret)
            phase = .ready
            logger.info("Wallet restored from mnemonic")
        } catch {
            logger.error("Failed to save restored wallet: \(error.localizedDescription)")
            self.error = "恢复钱包失败"
        }
    }

    public func deleteWallet() {
        do {
            try walletRepo.deleteWallet()
            phase = .create
            userHash = ""
            userSecret = ""
            mnemonic = []
            showMnemonic = false
        } catch {
            self.error = "删除钱包失败"
        }
    }

    public func dismissError() {
        error = nil
    }
}
