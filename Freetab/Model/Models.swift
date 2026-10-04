import Foundation
import SwiftData

// CloudKit-backed SwiftData rules: every stored property has a default or is optional, relationships are optional,
// and nothing is marked unique. Enums are stored as their raw strings so old records stay readable.

enum Direction: String, Codable, CaseIterable, Identifiable {
    case owedToMe
    case iOwe

    var id: String { rawValue }
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case transfer
    case cash
    case card
    case wallet
    case other

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .transfer: "building.columns"
        case .cash: "banknote"
        case .card: "creditcard"
        case .wallet: "iphone"
        case .other: "ellipsis.circle"
        }
    }
}

@Model
final class Person {
    var name: String = ""
    var note: String = ""
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \Debt.person)
    var debts: [Debt]? = []

    init(name: String) {
        self.name = name
    }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var activeDebts: [Debt] { (debts ?? []).filter { !$0.isSettled } }
}

@Model
final class Debt {
    var directionRaw: String = Direction.owedToMe.rawValue
    var title: String = ""
    var emoji: String = "💰"
    var totalUnits: Int64 = 0
    var currencyCode: String = "COP"
    var date: Date = Date.now
    var note: String = ""
    var createdAt: Date = Date.now
    var person: Person?
    @Relationship(deleteRule: .cascade, inverse: \Payment.debt)
    var payments: [Payment]? = []

    init(direction: Direction, title: String, emoji: String, totalUnits: Int64, currencyCode: String,
         date: Date, note: String = "", person: Person?) {
        self.directionRaw = direction.rawValue
        self.title = title
        self.emoji = emoji
        self.totalUnits = totalUnits
        self.currencyCode = currencyCode
        self.date = date
        self.note = note
        self.person = person
    }

    var direction: Direction {
        get { Direction(rawValue: directionRaw) ?? .owedToMe }
        set { directionRaw = newValue.rawValue }
    }

    var sortedPayments: [Payment] {
        (payments ?? []).sorted { ($0.date, $0.createdAt) > ($1.date, $1.createdAt) }
    }

    var paidUnits: Int64 { (payments ?? []).reduce(0) { $0 + $1.amountUnits } }
    /// Negative when more than the total was paid.
    var pendingUnits: Int64 { totalUnits - paidUnits }
    var isSettled: Bool { totalUnits > 0 && pendingUnits <= 0 }

    var progress: Double {
        guard totalUnits > 0 else { return 0 }
        return min(1, max(0, Double(paidUnits) / Double(totalUnits)))
    }

    var lastPaymentDate: Date? { sortedPayments.first?.date }
}

@Model
final class Payment {
    var amountUnits: Int64 = 0
    var date: Date = Date.now
    var methodRaw: String = PaymentMethod.transfer.rawValue
    var note: String = ""
    var createdAt: Date = Date.now
    var debt: Debt?
    @Relationship(deleteRule: .cascade, inverse: \Attachment.payment)
    var attachments: [Attachment]? = []

    init(amountUnits: Int64, date: Date, method: PaymentMethod, note: String = "") {
        self.amountUnits = amountUnits
        self.date = date
        self.methodRaw = method.rawValue
        self.note = note
    }

    var method: PaymentMethod {
        get { PaymentMethod(rawValue: methodRaw) ?? .other }
        set { methodRaw = newValue.rawValue }
    }

    var sortedAttachments: [Attachment] { (attachments ?? []).sorted { $0.createdAt < $1.createdAt } }
}

/// A photo or screenshot kept as evidence of a payment. The full image goes to external storage (a CloudKit
/// asset when synced); the thumbnail keeps lists fast.
@Model
final class Attachment {
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var createdAt: Date = Date.now
    var payment: Payment?

    init(imageData: Data, thumbnailData: Data?) {
        self.imageData = imageData
        self.thumbnailData = thumbnailData
    }
}

enum FreetabSchema {
    static let models: [any PersistentModel.Type] = [Person.self, Debt.self, Payment.self, Attachment.self]
}
