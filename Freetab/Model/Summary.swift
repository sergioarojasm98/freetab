import Foundation

/// Pending totals per currency, split by direction. Settled debts contribute nothing; overpayments don't
/// reduce the total (they show on the debt itself).
struct Summary: Equatable {
    var owedToMe: [String: Int64] = [:]
    var iOwe: [String: Int64] = [:]

    init(debts: [Debt]) {
        for debt in debts where debt.pendingUnits > 0 {
            switch debt.direction {
            case .owedToMe: owedToMe[debt.currencyCode, default: 0] += debt.pendingUnits
            case .iOwe: iOwe[debt.currencyCode, default: 0] += debt.pendingUnits
            }
        }
    }

    /// Formatted lines, largest currency first; a single "$ 0" when there's nothing.
    static func lines(_ totals: [String: Int64], fallbackCurrency: String) -> [String] {
        let nonZero = totals.filter { $0.value != 0 }.sorted { $0.value > $1.value }
        guard !nonZero.isEmpty else { return [Money.format(0, currency: fallbackCurrency)] }
        return nonZero.map { Money.format($0.value, currency: $0.key) }
    }
}

/// What one person and I owe each other, per currency (positive = they owe me).
struct PersonBalance {
    var net: [String: Int64] = [:]

    init(person: Person) {
        for debt in person.debts ?? [] where debt.pendingUnits > 0 {
            let sign: Int64 = debt.direction == .owedToMe ? 1 : -1
            net[debt.currencyCode, default: 0] += sign * debt.pendingUnits
        }
    }
}
