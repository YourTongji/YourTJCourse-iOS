import SwiftUI
import DesignSystem

public struct WalletView: View {
    @State private var viewModel = WalletViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .checking:
                    LoadingView(message: "检查钱包...")

                case .create:
                    createWalletView

                case .newWallet:
                    backupMnemonicView

                case .exists, .ready:
                    walletReadyView

                case .confirmBackup:
                    Color.clear
                        .task {
                            viewModel.confirmBackedUp()
                        }

                case .restore:
                    restoreWalletView
                }
            }
            .navigationTitle("我的")
            .task { await viewModel.checkWallet() }
            .alert("提示", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )) {
                Button("好", role: .cancel) { viewModel.dismissError() }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    // MARK: - Create Wallet

    private var createWalletView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "wallet.pass")
                .font(.system(size: 64))
                .foregroundStyle(.cyan)

            Text("积分钱包")
                .font(.title2)
                .bold()

            Text("创建钱包后，发表评价可获得积分奖励")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                Button(action: { viewModel.createNewWallet() }) {
                    Text("创建新钱包")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
                .padding(.horizontal, 40)

                Button(action: { viewModel.startRestore() }) {
                    Text("恢复已有钱包")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.glass)
                .padding(.horizontal, 40)
            }

            Spacer()
                .frame(height: 32)
        }
    }

    // MARK: - Backup Mnemonic

    private var backupMnemonicView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "key.icloud")
                        .font(.system(size: 48))
                        .foregroundStyle(.cyan)

                    Text("备份助记词")
                        .font(.title2)
                        .bold()

                    Text("请安全保存以下助记词，这是恢复钱包的唯一方式。\n不要截图、不要通过网络传输。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)

                if viewModel.showMnemonic {
                    // Grid of words
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(Array(viewModel.mnemonic.enumerated()), id: \.offset) { index, word in
                            HStack(spacing: 4) {
                                Text("\(index + 1).")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(word)
                                    .font(.body.monospaced())
                                    .bold()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.cyan.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal)
                } else {
                    Button(action: { viewModel.revealMnemonic() }) {
                        HStack {
                            Image(systemName: "eye")
                            Text("显示助记词")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.glass)
                    .padding(.horizontal, 40)
                }

                if viewModel.showMnemonic {
                    Button(action: { viewModel.startBackupConfirmation() }) {
                        Text("我已安全备份")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Restore Wallet

    private var restoreWalletView: some View {
        VStack(spacing: 16) {
            Text("输入助记词恢复钱包")
                .font(.headline)
                .padding(.top)

            TextEditor(text: $viewModel.restoreInput)
                .font(.body.monospaced())
                .frame(height: 120)
                .padding(8)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.separator, lineWidth: 1)
                )
                .padding(.horizontal)

            Text("请输入 12 个单词，用空格分隔")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: {
                Task { await viewModel.restoreWallet() }
            }) {
                Text("恢复钱包")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 40)
            .disabled(viewModel.restoreInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()
        }
        .padding(.top)
    }

    // MARK: - Wallet Ready

    private var walletReadyView: some View {
        List {
            Section("钱包") {
                HStack {
                    Label("钱包状态", systemImage: "wallet.pass.fill")
                    Spacer()
                    Text("已就绪")
                        .foregroundStyle(.green)
                        .font(.caption)
                }

                HStack {
                    Label("钱包 ID", systemImage: "person.badge.key")
                    Spacer()
                    Text(String(userHash.prefix(12)) + "...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
            }

            Section("安全") {
                Button(role: .destructive) {
                    viewModel.deleteWallet()
                } label: {
                    Label("删除钱包", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }

            Section("提示") {
                Text("钱包用于评价编辑鉴权和积分奖励。\n删除钱包后将无法编辑已发表的评价。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var userHash: String { viewModel.userHash }
}

// MARK: - Previews

#Preview("Creating") {
    WalletView()
}

#Preview("Ready") {
    WalletView()
}
