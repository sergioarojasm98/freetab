import Foundation
import SwiftData

/// Sample accounts for `-demo` launches (screenshots, previews). Never touches the real store.
enum DemoData {
    @MainActor
    static func load(into context: ModelContext) {
        let calendar = Calendar.current
        func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: .now) ?? .now }
        func amount(_ whole: Int64) -> Int64 { whole * Money.scale }
        let es = Locale.current.language.languageCode == .spanish
        func text(_ english: String, _ spanish: String) -> String { es ? spanish : english }

        let juan = Person(name: "Juan Pérez")
        let ana = Person(name: "Ana Gómez")
        let carlos = Person(name: "Carlos Ruiz")
        [juan, ana, carlos].forEach(context.insert)

        let laptop = Debt(direction: .owedToMe, title: text("Lenovo laptop", "Portátil Lenovo"), emoji: "💻", totalUnits: amount(3_000_000),
                          currencyCode: "COP", date: daysAgo(120), note: text("6 monthly installments", "6 cuotas mensuales"), person: juan)
        let phone = Debt(direction: .owedToMe, title: "iPhone 13", emoji: "📱", totalUnits: amount(1_800_000),
                         currencyCode: "COP", date: daysAgo(60), person: ana)
        let loan = Debt(direction: .iOwe, title: text("Loan for the trip", "Préstamo del viaje"), emoji: "✈️", totalUnits: amount(500),
                        currencyCode: "USD", date: daysAgo(30), person: carlos)
        let bike = Debt(direction: .owedToMe, title: text("Bicycle", "Bicicleta"), emoji: "🚲", totalUnits: amount(900_000),
                        currencyCode: "COP", date: daysAgo(200), person: ana)
        [laptop, phone, loan, bike].forEach(context.insert)

        let payments: [(Debt, Int64, Int, PaymentMethod, String)] = [
            (laptop, amount(500_000), 110, .transfer, ""),
            (laptop, amount(500_000), 80, .transfer, ""),
            (laptop, amount(724_764), 45, .wallet, "Nequi"),
            (phone, amount(600_000), 50, .cash, ""),
            (loan, amount(200), 20, .transfer, ""),
            (bike, amount(900_000), 150, .transfer, text("Paid in full", "Pago completo")),
        ]
        for (debt, amount, days, method, note) in payments {
            let payment = Payment(amountUnits: amount, date: daysAgo(days), method: method, note: note)
            context.insert(payment)
            payment.debt = debt
        }
    }
}
