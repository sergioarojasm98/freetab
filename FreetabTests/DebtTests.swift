import Foundation
import SwiftData
import Testing
@testable import Freetab

@MainActor
struct DebtTests {
    let context: ModelContext

    init() throws {
        let container = try ModelContainer(for: Schema(FreetabSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
    }

    private func debt(_ direction: Direction, total: Int64, payments: [Int64], currency: String = "COP",
                      person: Person? = nil) -> Debt {
        let debt = Debt(direction: direction, title: "Test", emoji: "💰", totalUnits: total, currencyCode: currency,
                        date: .now, person: person)
        context.insert(debt)
        for amount in payments {
            let payment = Payment(amountUnits: amount, date: .now, method: .cash)
            context.insert(payment)
            payment.debt = debt
        }
        return debt
    }

    @Test func pendingProgressAndSettled() {
        let open = debt(.owedToMe, total: 3_000, payments: [1_000, 500])
        #expect(open.paidUnits == 1_500 && open.pendingUnits == 1_500 && !open.isSettled)
        #expect(open.progress == 0.5)
        let done = debt(.owedToMe, total: 1_000, payments: [600, 400])
        #expect(done.isSettled && done.progress == 1)
        let over = debt(.iOwe, total: 1_000, payments: [1_200])
        #expect(over.pendingUnits == -200 && over.isSettled && over.progress == 1)
    }

    @Test func summarySplitsDirectionsAndCurrencies() {
        let debts = [
            debt(.owedToMe, total: 3_000, payments: [1_000]),
            debt(.owedToMe, total: 500, payments: [], currency: "USD"),
            debt(.iOwe, total: 800, payments: [300]),
            debt(.owedToMe, total: 100, payments: [100]),
        ]
        let summary = Summary(debts: debts)
        #expect(summary.owedToMe == ["COP": 2_000, "USD": 500])
        #expect(summary.iOwe == ["COP": 500])
    }

    @Test func personBalanceIsNetOfBothDirections() {
        let person = Person(name: "Ana")
        context.insert(person)
        _ = debt(.owedToMe, total: 1_000, payments: [200], person: person)
        _ = debt(.iOwe, total: 300, payments: [], person: person)
        #expect(PersonBalance(person: person).net == ["COP": 500])
    }

    @Test func initialsFromName() {
        #expect(Person(name: "Juan Pérez").initials == "JP")
        #expect(Person(name: "ana").initials == "A")
        #expect(Person(name: "").initials == "?")
    }
}
