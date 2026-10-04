import SwiftData
import SwiftUI

struct DebtDetailView: View {
    @Bindable var debt: Debt
    var onDelete: () -> Void = {}
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false
    @State private var showingNewPayment = false
    @State private var editingPayment: Payment?
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    EmojiBadge(emoji: debt.emoji, size: 72)
                    Text(debt.title.isEmpty ? String(localized: "Untitled") : debt.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Label(directionText, systemImage: debt.direction == .owedToMe ? "arrow.down.left" : "arrow.up.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(tint)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                amountRow("Total", debt.totalUnits)
                amountRow(debt.direction == .owedToMe ? "Received" : "Paid", debt.paidUnits)
                if debt.pendingUnits < 0 {
                    amountRow("Overpaid", -debt.pendingUnits, emphasized: true)
                } else {
                    amountRow("Pending", debt.pendingUnits, emphasized: true)
                }
                ProgressView(value: debt.progress) {
                    Text(debt.isSettled ? "Settled" : "\(Int((debt.progress * 100).rounded()))% paid")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tint(tint)
                LabeledContent("Since", value: debt.date.formatted(date: .long, time: .omitted))
                if !debt.note.isEmpty {
                    Text(debt.note)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if debt.sortedPayments.isEmpty {
                    Text("No payments yet. Add the first one with the button below.")
                        .foregroundStyle(.secondary)
                }
                ForEach(debt.sortedPayments) { payment in
                    Button { editingPayment = payment } label: { PaymentRow(payment: payment, currency: debt.currencyCode) }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) { context.delete(payment) }
                        }
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) { context.delete(payment) }
                        }
                }
            } header: {
                Text("Payments (\(debt.payments?.count ?? 0))")
            }
        }
        .navigationTitle(debt.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .safeAreaInset(edge: .bottom) {
            Button { showingNewPayment = true } label: {
                Label("Add payment", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis") {
                    Button("Edit", systemImage: "pencil") { showingEdit = true }
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .sheet(isPresented: $showingEdit) { DebtEditor(debt: debt) }
        .sheet(isPresented: $showingNewPayment) { PaymentEditor(debt: debt, payment: nil) }
        .sheet(item: $editingPayment) { PaymentEditor(debt: debt, payment: $0) }
        .confirmationDialog("Delete this account and all its payments?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
                context.delete(debt)
                dismiss()
            }
        }
    }

    private var tint: Color { debt.direction == .owedToMe ? .green : .orange }

    private var directionText: String {
        let who = debt.person?.name ?? String(localized: "No one")
        return debt.direction == .owedToMe ? String(localized: "\(who) owes you") : String(localized: "You owe \(who)")
    }

    private func amountRow(_ title: LocalizedStringKey, _ minor: Int64, emphasized: Bool = false) -> some View {
        LabeledContent {
            Text(Money.format(minor, currency: debt.currencyCode))
                .monospacedDigit()
                .fontWeight(emphasized ? .bold : .regular)
                .foregroundStyle(emphasized ? tint : .primary)
        } label: {
            Text(title).fontWeight(emphasized ? .semibold : .regular)
        }
    }
}

struct PaymentRow: View {
    let payment: Payment
    let currency: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: payment.method.symbol)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(Money.format(payment.amountUnits, currency: currency))
                        .font(.headline)
                        .monospacedDigit()
                    Spacer()
                    Text(payment.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(payment.method.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !payment.note.isEmpty {
                    Text(payment.note)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                if !payment.sortedAttachments.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(payment.sortedAttachments.prefix(4)) { attachment in
                            AttachmentThumbnail(attachment: attachment, size: 44)
                        }
                        if payment.sortedAttachments.count > 4 {
                            Text("+\(payment.sortedAttachments.count - 4)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .contentShape(.rect)
        .padding(.vertical, 2)
    }
}

extension PaymentMethod {
    var title: String {
        switch self {
        case .transfer: String(localized: "Bank transfer")
        case .cash: String(localized: "Cash")
        case .card: String(localized: "Card")
        case .wallet: String(localized: "Digital wallet")
        case .other: String(localized: "Other")
        }
    }
}
