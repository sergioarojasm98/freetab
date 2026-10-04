import Foundation

/// Amounts are stored as `Int64` in a fixed scale of 1/10,000 of the currency's main unit, independent of the
/// currency and of the OS's currency tables, so a stored value never changes meaning across devices, locales or
/// future OS updates. Sums are exact integer math; `Decimal` is used only for input and display.
enum Money {
    /// Stored units per main unit (1 peso = 10,000 units). Covers every ISO 4217 currency (max 4 decimals).
    static let scale: Int64 = 10_000

    /// Currencies offered in pickers, most likely first; any ISO 4217 code still works if stored.
    static let commonCurrencies = ["COP", "USD", "EUR", "MXN", "ARS", "CLP", "PEN", "BRL", "GBP", "CAD"]

    static var defaultCurrency: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    /// Decimals people use for a currency (0 for COP/JPY/CLP, 2 for USD/EUR, 3 for KWD). Only used to round
    /// input and to format; never to interpret stored values.
    static func fractionDigits(for code: String) -> Int {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return min(4, max(0, formatter.maximumFractionDigits))
    }

    static func decimal(fromUnits units: Int64) -> Decimal {
        Decimal(units) / Decimal(scale)
    }

    /// Rounds half-up to the currency's decimals, then converts to stored units.
    static func units(from value: Decimal, currency code: String) -> Int64 {
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, fractionDigits(for: code), .plain)
        return NSDecimalNumber(decimal: rounded * Decimal(scale)).int64Value
    }

    /// "$ 1.724.764" in es-CO, "$1,724,764" in en-US; decimals only when the amount has them.
    static func format(_ units: Int64, currency code: String, locale: Locale = .current) -> String {
        let digits = units % scale == 0 ? 0 : fractionDigits(for: code)
        return decimal(fromUnits: units).formatted(
            .currency(code: code).locale(locale).precision(.fractionLength(digits))
        )
    }

    static func currencyName(_ code: String, locale: Locale = .current) -> String {
        locale.localizedString(forCurrencyCode: code) ?? code
    }
}
