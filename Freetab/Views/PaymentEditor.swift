import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Add or edit a payment: amount, date, method, note and evidence images.
struct PaymentEditor: View {
    let debt: Debt
    let payment: Payment?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var date = Date.now
    @State private var method: PaymentMethod = .transfer
    @State private var note = ""
    @State private var images: [EvidenceDraft] = []
    @State private var removed: [Attachment] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var showingFiles = false
    @State private var viewing: EvidenceDraft?
    @State private var loaded = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    AmountField(text: $amountText, currency: debt.currencyCode, large: true)
                    if payment == nil, debt.pendingUnits > 0 {
                        Button("Pending: \(Money.format(debt.pendingUnits, currency: debt.currencyCode))") {
                            amountText = AmountField.text(for: debt.pendingUnits, currency: debt.currencyCode)
                        }
                        .font(.subheadline)
                    }
                }

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Method", selection: $method) {
                        ForEach(PaymentMethod.allCases) { option in
                            Label(option.title, systemImage: option.symbol).tag(option)
                        }
                    }
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section {
                    if !images.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(images) { draft in
                                    ZStack(alignment: .topTrailing) {
                                        PlatformImage(data: draft.thumbnail)
                                            .scaledToFill()
                                            .frame(width: 84, height: 84)
                                            .clipShape(.rect(cornerRadius: 12))
                                            .onTapGesture { viewing = draft }
                                        Button { remove(draft) } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, .black.opacity(0.6))
                                                .font(.title3)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                        Label("Add from Photos", systemImage: "photo.on.rectangle")
                    }
                    #if os(iOS)
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Take photo", systemImage: "camera") { showingCamera = true }
                    }
                    #endif
                    Button("Add from Files", systemImage: "folder") { showingFiles = true }
                } header: {
                    Text("Evidence")
                } footer: {
                    Text("Screenshots of the transfer or photos of the receipt. They stay in your iCloud.")
                }

                if payment != nil {
                    Section {
                        Button("Delete payment", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(payment == nil ? "New payment" : "Payment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(payment == nil ? "Add" : "Save", systemImage: "checkmark", action: save)
                        .disabled((amountUnits ?? 0) <= 0)
                }
            }
            .onAppear(perform: load)
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await importPhotos(items) }
            }
            .fileImporter(isPresented: $showingFiles, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
                if case let .success(urls) = result { importFiles(urls) }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { data in add(data) }
                    .ignoresSafeArea()
            }
            #endif
            .sheet(item: $viewing) { draft in
                ImageViewer(data: draft.full)
            }
            .confirmationDialog("Delete this payment?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let payment { context.delete(payment) }
                    dismiss()
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
    }

    private var amountUnits: Int64? { AmountField.parse(amountText, currency: debt.currencyCode) }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let payment else { return }
        amountText = AmountField.text(for: payment.amountUnits, currency: debt.currencyCode)
        date = payment.date
        method = payment.method
        note = payment.note
        images = payment.sortedAttachments.compactMap { attachment in
            guard let full = attachment.imageData else { return nil }
            return EvidenceDraft(full: full, thumbnail: attachment.thumbnailData ?? full, existing: attachment)
        }
    }

    private func add(_ data: Data) {
        guard let prepared = ImageStore.prepare(data) else { return }
        images.append(EvidenceDraft(full: prepared.image, thumbnail: prepared.thumbnail, existing: nil))
    }

    private func remove(_ draft: EvidenceDraft) {
        images.removeAll { $0.id == draft.id }
        if let existing = draft.existing { removed.append(existing) }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) { add(data) }
        }
        pickerItems = []
    }

    private func importFiles(_ urls: [URL]) {
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) { add(data) }
        }
    }

    private func save() {
        guard let amount = amountUnits else { return }
        let target: Payment
        if let payment {
            target = payment
            target.amountUnits = amount
            target.date = date
            target.method = method
            target.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            target = Payment(amountUnits: amount, date: date, method: method,
                             note: note.trimmingCharacters(in: .whitespacesAndNewlines))
            context.insert(target)
            target.debt = debt
        }
        for attachment in removed { context.delete(attachment) }
        for draft in images where draft.existing == nil {
            let attachment = Attachment(imageData: draft.full, thumbnailData: draft.thumbnail)
            context.insert(attachment)
            attachment.payment = target
        }
        dismiss()
    }
}

struct EvidenceDraft: Identifiable {
    let id = UUID()
    let full: Data
    let thumbnail: Data
    let existing: Attachment?
}

struct AttachmentThumbnail: View {
    let attachment: Attachment
    var size: CGFloat = 44
    @State private var showing = false

    var body: some View {
        PlatformImage(data: attachment.thumbnailData ?? attachment.imageData ?? Data())
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: 8))
            .onTapGesture { showing = true }
            .sheet(isPresented: $showing) {
                ImageViewer(data: attachment.imageData ?? attachment.thumbnailData ?? Data())
            }
    }
}

/// Full-size evidence image with pinch-to-zoom (iOS) and share/save.
struct ImageViewer: View {
    let data: Data
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                PlatformImage(data: data)
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(MagnifyGesture().onChanged { scale = max(1, min(5, $0.magnification)) })
            }
            .background(.black)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: EvidenceFile(data: data), preview: SharePreview("Payment evidence"))
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 500)
        #endif
    }
}

struct EvidenceFile: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { $0.data }
            .suggestedFileName("evidence.jpg")
    }
}
