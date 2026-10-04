import SwiftData
import SwiftUI

enum DebtFilter: String, CaseIterable, Identifiable {
    case all, owedToMe, iOwe
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all: "All"
        case .owedToMe: "Owed to me"
        case .iOwe: "I owe"
        }
    }
}

struct HomeView: View {
    @Binding var selection: Debt?
    @Environment(\.modelContext) private var context
    @Query(sort: \Debt.date, order: .reverse) private var debts: [Debt]
    @State private var filter: DebtFilter = .all
    @State private var search = ""
    @State private var showingNew = false
    @State private var showingPeople = false
    @State private var showingSettings = false
    @State private var showSettled = false
    @State private var pendingDelete: Debt?

    var body: some View {
        List(selection: $selection) {
            Section {
                SummaryHeader(summary: Summary(debts: debts))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                Picker("Show", selection: $filter) {
                    ForEach(DebtFilter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if debts.isEmpty {
                ContentUnavailableView {
                    Label("No accounts yet", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Add something you sold or lent — or something you owe — and log each payment as it comes in.")
                } actions: {
                    Button("New account") { showingNew = true }
                        .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                let active = visible.filter { !$0.isSettled }
                let settled = visible.filter(\.isSettled)
                Section("Active") {
                    if active.isEmpty {
                        Text(search.isEmpty ? "Nothing pending here." : "No matches.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(active) { row($0) }
                }
                if !settled.isEmpty {
                    Section {
                        if showSettled { ForEach(settled) { row($0) } }
                    } header: {
                        // A tappable header: collapsible sections only show a chevron in sidebar-style lists.
                        Button {
                            withAnimation { showSettled.toggle() }
                        } label: {
                            HStack {
                                Text("Settled (\(settled.count))")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .rotationEffect(.degrees(showSettled ? 90 : 0))
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("Freetab")
        .searchable(text: $search, prompt: "Search by concept or person")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New account", systemImage: "plus") { showingNew = true }
                    .keyboardShortcut("n")
            }
            ToolbarItem {
                Button("People", systemImage: "person.2") { showingPeople = true }
            }
            #if os(iOS)
            ToolbarItem {
                Button("Settings", systemImage: "gearshape") { showingSettings = true }
            }
            #endif
        }
        .sheet(isPresented: $showingNew) {
            DebtEditor(debt: nil) { created in selection = created }
        }
        .sheet(isPresented: $showingPeople) {
            NavigationStack { PeopleView() }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
        }
        .confirmationDialog(
            "Delete this account and all its payments?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let debt = pendingDelete {
                    if selection == debt { selection = nil }
                    context.delete(debt)
                }
                pendingDelete = nil
            }
        }
    }

    private var visible: [Debt] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return debts.filter { debt in
            switch filter {
            case .all: true
            case .owedToMe: debt.direction == .owedToMe
            case .iOwe: debt.direction == .iOwe
            }
        }
        .filter { debt in
            query.isEmpty
                || debt.title.localizedStandardContains(query)
                || (debt.person?.name ?? "").localizedStandardContains(query)
                || debt.note.localizedStandardContains(query)
        }
    }

    private func row(_ debt: Debt) -> some View {
        NavigationLink(value: debt) {
            DebtRow(debt: debt)
        }
        .tag(debt)
        .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = debt }
        }
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = debt }
        }
    }
}

private struct SummaryHeader: View {
    let summary: Summary

    var body: some View {
        HStack(spacing: 12) {
            card("Owed to me", lines: Summary.lines(summary.owedToMe, fallbackCurrency: Money.defaultCurrency),
                 symbol: "arrow.down.left", tint: .green)
            card("I owe", lines: Summary.lines(summary.iOwe, fallbackCurrency: Money.defaultCurrency),
                 symbol: "arrow.up.right", tint: .orange)
        }
        .padding(.vertical, 4)
    }

    private func card(_ title: LocalizedStringKey, lines: [String], symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: 20))
    }
}

struct DebtRow: View {
    let debt: Debt

    var body: some View {
        HStack(spacing: 12) {
            EmojiBadge(emoji: debt.emoji)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(debt.title.isEmpty ? String(localized: "Untitled") : debt.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(Money.format(max(debt.pendingUnits, 0), currency: debt.currencyCode))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(debt.isSettled ? .secondary : (debt.direction == .owedToMe ? Color.green : Color.orange))
                }
                HStack {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(debt.isSettled ? String(localized: "Settled") : String(localized: "of \(totalText)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                ProgressView(value: debt.progress)
                    .tint(debt.direction == .owedToMe ? .green : .orange)
            }
        }
        .padding(.vertical, 4)
    }

    private var totalText: String { Money.format(debt.totalUnits, currency: debt.currencyCode) }

    private var subtitle: String {
        let who = debt.person?.name ?? String(localized: "No one")
        return debt.direction == .owedToMe ? String(localized: "\(who) owes you") : String(localized: "You owe \(who)")
    }
}

struct EmojiBadge: View {
    let emoji: String
    var size: CGFloat = 44

    var body: some View {
        Text(emoji.isEmpty ? "💰" : emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(.background.secondary, in: .circle)
    }
}
