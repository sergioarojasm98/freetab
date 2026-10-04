import SwiftData
import SwiftUI

/// Everyone you have accounts with, and the net balance with each one.
struct PeopleView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.name) private var people: [Person]

    var body: some View {
        List {
            if people.isEmpty {
                ContentUnavailableView("No people yet", systemImage: "person.2",
                                       description: Text("People appear here when you add an account for them."))
            }
            ForEach(people) { person in
                NavigationLink {
                    PersonDetailView(person: person)
                } label: {
                    PersonRow(person: person)
                }
            }
        }
        .navigationTitle("People")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") { dismiss() }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }
}

struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            Text(person.initials)
                .font(.headline)
                .frame(width: 40, height: 40)
                .background(.background.secondary, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.headline)
                Text("\(person.activeDebts.count) active")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            BalanceText(balance: PersonBalance(person: person))
        }
    }
}

struct BalanceText: View {
    let balance: PersonBalance

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            let entries = balance.net.filter { $0.value != 0 }.sorted { abs($0.value) > abs($1.value) }
            if entries.isEmpty {
                Text("Even").foregroundStyle(.secondary)
            }
            ForEach(entries, id: \.key) { code, net in
                Text(net > 0 ? "Owes you \(Money.format(net, currency: code))" : "You owe \(Money.format(-net, currency: code))")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(net > 0 ? Color.green : Color.orange)
            }
        }
    }
}

struct PersonDetailView: View {
    @Bindable var person: Person
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            Section {
                TextField("Name", text: $person.name)
                TextField("Note", text: $person.note, axis: .vertical)
            }
            Section("Accounts") {
                let debts = (person.debts ?? []).sorted { $0.date > $1.date }
                if debts.isEmpty {
                    Text("No accounts.").foregroundStyle(.secondary)
                }
                ForEach(debts) { debt in
                    NavigationLink {
                        DebtDetailView(debt: debt)
                    } label: {
                        DebtRow(debt: debt)
                    }
                }
            }
        }
        .navigationTitle(person.name)
    }
}
