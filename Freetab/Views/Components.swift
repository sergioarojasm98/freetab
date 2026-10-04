import SwiftUI

/// Text-backed amount input: parses what the user types in their locale ("1.724.764" in es-CO,
/// "1,724,764.50" in en-US) into minor units.
struct AmountField: View {
    @Binding var text: String
    let currency: String
    var large = false

    var body: some View {
        TextField("0", text: $text)
            #if os(iOS)
            .keyboardType(Money.fractionDigits(for: currency) == 0 ? .numberPad : .decimalPad)
            #endif
            .font(large ? .title.weight(.semibold) : .body)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }

    static func parse(_ text: String, currency: String, locale: Locale = .current) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true
        formatter.isLenient = true
        guard let number = formatter.number(from: trimmed) as? NSDecimalNumber, number != .notANumber else { return nil }
        let minor = Money.units(from: number.decimalValue, currency: currency)
        return minor >= 0 ? minor : nil
    }

    static func text(for minor: Int64, currency: String, locale: Locale = .current) -> String {
        let value = Money.decimal(fromUnits: minor)
        return value.formatted(.number.locale(locale).precision(.fractionLength(0...Money.fractionDigits(for: currency))))
    }
}

/// A curated emoji grid plus free typing, shown in a popover from a round button.
struct EmojiPicker: View {
    @Binding var emoji: String
    @State private var showing = false

    static let choices = [
        "💰", "💵", "💳", "🏦", "🤝", "📱", "💻", "🖥️", "🎮", "📷", "🎧", "⌚️",
        "🚗", "🏍️", "🚲", "🏠", "🛋️", "🛏️", "🧊", "📺", "👟", "👕", "💍", "🎁",
        "🍔", "✈️", "🏖️", "🎓", "🩺", "🐶", "🔧", "📦", "🧾", "⚽️", "🎸", "📚",
    ]

    var body: some View {
        Button { showing = true } label: {
            EmojiBadge(emoji: emoji, size: 40)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showing) {
            VStack(spacing: 12) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(40)), count: 6), spacing: 8) {
                    ForEach(Self.choices, id: \.self) { choice in
                        Button {
                            emoji = choice
                            showing = false
                        } label: {
                            Text(choice).font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                TextField("Or type any emoji", text: Binding(
                    get: { "" },
                    set: { typed in
                        if let first = typed.first(where: { $0.unicodeScalars.first?.properties.isEmoji == true }) {
                            emoji = String(first)
                            showing = false
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
            }
            .padding()
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// `Image` from JPEG/PNG data on both UIKit and AppKit.
struct PlatformImage: View {
    let data: Data

    var body: some View {
        #if os(iOS)
        if let image = UIImage(data: data) {
            Image(uiImage: image).resizable()
        } else {
            Image(systemName: "photo").resizable()
        }
        #else
        if let image = NSImage(data: data) {
            Image(nsImage: image).resizable()
        } else {
            Image(systemName: "photo").resizable()
        }
        #endif
    }
}

#if os(iOS)
import UIKit

/// Minimal camera capture returning JPEG data.
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                parent.onCapture(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
