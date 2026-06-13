import SwiftUI
import DomainKit
import DesignSystem

public struct WalletTransactionView: View {
    let userHash: String
    @State private var viewModel: WalletViewModel

    public init(userHash: String, viewModel: WalletViewModel) {
        self.userHash = userHash
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        transactionContent
            .navigationTitle("积分流水")
            .task { await viewModel.loadTransactions() }
    }

    @ViewBuilder
    private var transactionContent: some View {
        if viewModel.isLoadingTransactions && viewModel.transactions.isEmpty {
            ProgressView("加载交易记录...")
        } else if let error = viewModel.transactionError, viewModel.transactions.isEmpty {
            ErrorStateView(
                message: error,
                retryTitle: "重试",
                retryAction: { Task { await viewModel.loadTransactions() } }
            )
        } else if viewModel.transactions.isEmpty {
            EmptyStateView(
                icon: "list.bullet.rectangle",
                message: "暂无交易记录"
            )
        } else {
            listContent
        }
    }

    private var listContent: some View {
        List {
            ForEach(viewModel.transactions) { tx in
                TransactionRow(tx: tx, isIncome: tx.toUserHash == userHash)
            }
            if viewModel.transactionHasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .task { await viewModel.loadMoreTransactions() }
            } else if !viewModel.transactions.isEmpty {
                Text("仅展示近期记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.refreshTransactions() }
    }
}

private struct TransactionRow: View {
    let tx: WalletTransaction
    let isIncome: Bool

    private var dateText: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "MM/dd HH:mm"

        let calendar = Calendar.current
        if calendar.isDateInToday(tx.createdAt) {
            return "今天 " + dateFormatter.string(from: tx.createdAt).suffix(5)
        } else if calendar.isDateInYesterday(tx.createdAt) {
            return "昨天 " + dateFormatter.string(from: tx.createdAt).suffix(5)
        } else {
            return dateFormatter.string(from: tx.createdAt)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isIncome ? Color.green : Color.red)
                .frame(width: 32, height: 32)
                .overlay {
                    Text(isIncome ? "+" : "-")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.title)
                    .font(.subheadline.weight(.medium))
                if let desc = tx.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(dateText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("\(isIncome ? "+" : "-")\(tx.amount) 小济元")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isIncome ? Color.green : Color.red)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        WalletTransactionView(
            userHash: "preview_hash",
            viewModel: WalletViewModel()
        )
    }
}
