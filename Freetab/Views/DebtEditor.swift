import SwiftData
import SwiftUI

/// Create or edit an account: direction, concept, person, total and currency.
struct DebtEditor: View {
    let debt: Debt?
    var onCreate: (Debt) -> Void = { _ in }
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.name) private var people: [Person]

    @State private var direction: Direction = .owedToMe
    @State private var title = ""
    @State private var emoji = "💰"
    @State private var personName = ""
    @State private var amountText = ""
    @State private var currency = Money.defaultCurrency
    @State private var date = Date.now
    @State private var note = ""
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $direction) {
                        Text("Owed to me").tag(Direction.owedToMe)
                        Text("I owe").tag(Direction.iOwe)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section("Concept") {
                    HStack(spacing: 12) {
                        EmojiPicker(emoji: $emoji)
                        TextField("e.g. Lenovo laptop", text: $title)
                    }
                }

                Section(direction == .owedToMe ? "Who owes you" : "Who you owe") {
                    TextField("Name", text: $personName)
                        .textContentType(.name)
                    let suggestions = matchingPeople
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(suggestions) { person in
                                    Button(person.name) { personName = person.name }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                }
                            }
                        }
                    }
                }

                Section("Total") {
                    HStack {
                        Picker("Currency", selection: $currency) {
                            ForEach(currencies, id: \.self) { code in
                                Text("\(code) · \(Money.currencyName(code))").tag(code)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        AmountField(text: $amountText, currency: currency)
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Note") {
                    TextField("Optional details (installments agreed, etc.)", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(debt == nil ? "New account" : "Edit account")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(debt == nil ? "Create" : "Save", systemImage: "checkmark", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
    }

    private var currencies: [String] {
        Money.commonCurrencies.contains(currency) ? Money.commonCurrencies : [currency] + Money.commonCurrencies
    }

    private var matchingPeople: [Person] {
        let query = personName.trimmingCharacters(in: .whitespaces)
        let exact = people.contains { $0.name.caseInsensitiveCompare(query) == .orderedSame }
        guard !exact else { return [] }
        return people.filter { query.isEmpty || $0.name.localizedStandardContains(query) }.prefix(8).map { $0 }
    }

    private var amountUnits: Int64? { AmountField.parse(amountText, currency: currency) }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && (amountUnits ?? 0) > 0
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let debt else { return }
        direction = debt.direction
        title = debt.title
        emoji = debt.emoji
        personName = debt.person?.name ?? ""
        currency = debt.currencyCode
        amountText = AmountField.text(for: debt.totalUnits, currency: debt.currencyCode)
        date = debt.date
        note = debt.note
    }

    private func save() {
        guard let total = amountUnits else { return }
        let person = resolvePerson()
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let debt {
            debt.direction = direction
            debt.title = cleanTitle
            debt.emoji = emoji
            debt.person = person
            debt.totalUnits = total
            debt.currencyCode = currency
            debt.date = date
            debt.note = cleanNote
        } else {
            let created = Debt(direction: direction, title: cleanTitle, emoji: emoji, totalUnits: total,
                               currencyCode: currency, date: date, note: cleanNote, person: person)
            context.insert(created)
            onCreate(created)
        }
        dismiss()
    }

    /// Reuses a person with the same name (case-insensitive) instead of creating duplicates.
    private func resolvePerson() -> Person? {
        let name = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if let existing = people.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let person = Person(name: name)
        context.insert(person)
        return person
    }
}
