import Foundation
import Testing
@testable import Freetab

struct MoneyTests {
    @Test func storageScaleIsFixed() {
        // Changing this would silently change the meaning of every stored amount.
        #expect(Money.scale == 10_000)
    }

    @Test func fractionDigitsFollowISO4217() {
        #expect(Money.fractionDigits(for: "USD") == 2)
        #expect(Money.fractionDigits(for: "COP") == 0)
        #expect(Money.fractionDigits(for: "JPY") == 0)
        #expect(Money.fractionDigits(for: "KWD") == 3)
    }

    @Test func roundingToCurrencyDecimals() {
        #expect(Money.units(from: Decimal(string: "1724764")!, currency: "COP") == 1_724_764 * Money.scale)
        #expect(Money.units(from: Decimal(string: "1724764.6")!, currency: "COP") == 1_724_765 * Money.scale)
        #expect(Money.units(from: Decimal(string: "19.995")!, currency: "USD") == 20 * Money.scale)
        let tenth = Money.units(from: Decimal(string: "0.1")!, currency: "USD")
        let fifth = Money.units(from: Decimal(string: "0.2")!, currency: "USD")
        #expect(tenth + fifth == Money.units(from: Decimal(string: "0.3")!, currency: "USD"))
        #expect(Money.decimal(fromUnits: 1_724_764 * Money.scale) == Decimal(1_724_764))
    }

    @Test func formatsColombianPesos() {
        let text = Money.format(1_724_764 * Money.scale, currency: "COP", locale: Locale(identifier: "es_CO"))
        #expect(text.contains("1.724.764"))
        #expect(!text.contains(","))
    }

    @Test func formatsCentsOnlyWhenPresent() {
        let us = Locale(identifier: "en_US")
        #expect(Money.format(10 * Money.scale + 5_000, currency: "USD", locale: us) == "$10.50")
        #expect(Money.format(10 * Money.scale, currency: "USD", locale: us) == "$10")
    }

    @Test func parsesTypedAmountsPerLocale() {
        #expect(AmountField.parse("1.724.764", currency: "COP", locale: Locale(identifier: "es_CO")) == 1_724_764 * Money.scale)
        #expect(AmountField.parse("1,724.50", currency: "USD", locale: Locale(identifier: "en_US")) == 1_724 * Money.scale + 5_000)
        #expect(AmountField.parse("", currency: "USD") == nil)
        #expect(AmountField.parse("abc", currency: "USD", locale: Locale(identifier: "en_US")) == nil)
    }

    @Test func textRoundTripsThroughParse() {
        let co = Locale(identifier: "es_CO")
        let units: Int64 = 3_000_000 * Money.scale
        #expect(AmountField.parse(AmountField.text(for: units, currency: "COP", locale: co), currency: "COP", locale: co) == units)
    }
}
