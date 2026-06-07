import SwiftUI
import DesignSystem

public struct WalletView: View {
    @State private var viewModel = WalletViewModel()
    @State private var showingDeleteConfirmation = false

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

                case .restore:
                    restoreWalletView
                }
            }
            .navigationTitle("我的")
            .toolbar {
                if viewModel.phase == .ready || viewModel.phase == .exists {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isRefreshing)
                    .accessibilityLabel("刷新钱包")
                }
            }
            .task { await viewModel.checkWallet() }
            .alert("提示", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )) {
                Button("好", role: .cancel) { viewModel.dismissError() }
            } message: {
                Text(viewModel.error ?? "")
            }
            .alert("删除钱包？", isPresented: $showingDeleteConfirmation) {
                Button("删除钱包", role: .destructive) {
                    viewModel.deleteWallet()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后将无法在本机继续编辑已用此钱包发表的评价。请确认已备份助记词。")
            }
        }
    }

    // MARK: - Create Wallet

    private var createWalletView: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "wallet.pass")
                        .font(.system(size: 40))
                        .foregroundStyle(.cyan)

                    Text("登录 / 注册积分钱包")
                        .font(.title2.bold())

                    Text("使用学号和 PIN 登录或注册 credit 钱包。未注册的组合会创建新钱包；已注册的组合会恢复同一个钱包。学号、PIN 和助记词不会上传。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                TextField("学号", text: $viewModel.studentId)
                    .textContentType(.username)
                    .keyboardType(.numberPad)

                SecureField("PIN 码（6-32 位）", text: $viewModel.pin)
                    .textContentType(.password)

                Button {
                    Task { await viewModel.loginOrRegisterWallet() }
                } label: {
                    AppActionButtonLabel(
                        viewModel.isProcessing ? "处理中..." : "登录 / 注册钱包",
                        systemImage: "sparkles",
                        isLoading: viewModel.isProcessing
                    )
                }
                .buttonStyle(.appPrimaryAction)
                .disabled(viewModel.isProcessing || viewModel.studentId.isEmpty || viewModel.pin.isEmpty)
            } header: {
                Text("登录 / 注册")
            } footer: {
                Text("同一个学号 + PIN 会生成同一个 3 词助记词，可与 credit.yourtj.de 钱包互通。请妥善保管 PIN，遗失无法找回。")
            }

            Section {
                Button {
                    viewModel.startRestore()
                } label: {
                    Label("导入已有 3 词助记词", systemImage: "square.and.arrow.down")
                }
            }
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

                    Text("Credit 尚未找到这个钱包。请先安全保存以下 3 个助记词，这是恢复新钱包的唯一方式。\n不要截图、不要通过网络传输。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)

                if viewModel.showMnemonic {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(Array(viewModel.mnemonic.enumerated()), id: \.offset) { index, word in
                            VStack(spacing: 6) {
                                Text("\(index + 1).")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(word)
                                    .font(.headline)
                                    .bold()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.cyan.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal)
                } else {
                    Button(action: { viewModel.revealMnemonic() }) {
                        AppActionButtonLabel("显示助记词", systemImage: "eye")
                    }
                    .buttonStyle(.appSecondaryAction)
                    .padding(.horizontal, 40)
                }

                if viewModel.showMnemonic {
                    Button {
                        Task { await viewModel.confirmBackedUp() }
                    } label: {
                        AppActionButtonLabel(
                            viewModel.isProcessing ? "正在启用..." : "我已安全备份并启用",
                            isLoading: viewModel.isProcessing
                        )
                    }
                    .buttonStyle(.appPrimaryAction)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .disabled(viewModel.isProcessing)
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

            Text("请输入 3 个词，支持用 -、空格或换行分隔")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: {
                Task { await viewModel.restoreWallet() }
            }) {
                AppActionButtonLabel(
                    viewModel.isProcessing ? "恢复中..." : "恢复钱包",
                    systemImage: "arrow.clockwise",
                    isLoading: viewModel.isProcessing
                )
            }
            .buttonStyle(.appPrimaryAction)
            .padding(.horizontal, 40)
            .disabled(viewModel.isProcessing || viewModel.restoreInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("返回") {
                viewModel.cancelRestore()
            }
            .disabled(viewModel.isProcessing)

            Spacer()
        }
        .padding(.top)
    }

    // MARK: - Wallet Ready

    private var walletReadyView: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(viewModel.balance ?? 0)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("小济元")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.isRefreshing {
                        Label("正在刷新积分数据", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let remoteError = viewModel.remoteError {
                        Label(remoteError, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Label("已连接 YOURTJ Credit", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("今日积分") {
                metricRow(
                    title: "预计合计",
                    value: signed(todayEstimated),
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                metricRow(
                    title: "评课激励",
                    value: signed(viewModel.summary?.today.reviewReward ?? 0),
                    systemImage: "text.bubble"
                )
                metricRow(
                    title: "点赞待结算",
                    value: signed(viewModel.summary?.today.likePendingPoints ?? 0),
                    systemImage: "hand.thumbsup"
                )
            }

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
                    showingDeleteConfirmation = true
                } label: {
                    Label("删除钱包", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }

            Section("提示") {
                Text("50 字以上点评可获得 +10 小济元；点赞激励按 credit 服务的 JCourse 结算规则展示。删除钱包后将无法编辑已发表的评价。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var userHash: String { viewModel.userHash }

    private var todayEstimated: Int {
        let today = viewModel.summary?.today
        return (today?.reviewReward ?? 0) + (today?.likePendingPoints ?? 0)
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func metricRow(title: String, value: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(value.hasPrefix("-") ? .red : .primary)
        }
    }
}

// MARK: - Previews

#Preview("Creating") {
    WalletView()
}

#Preview("Ready") {
    WalletView()
}
