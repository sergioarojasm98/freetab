import SwiftUI

struct SettingsView: View {
    @AppStorage("lockEnabled") private var lockEnabled = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                Toggle("Lock with Face ID / Touch ID", isOn: $lockEnabled)
            } footer: {
                Text("Asks for Face ID, Touch ID or your device passcode every time Freetab opens.")
            }

            Section("iCloud") {
                Label("Your accounts sync through your own iCloud across your iPhone, iPad and Mac.", systemImage: "icloud")
                Label("Nobody else can see them — not even the developer. Freetab has no servers and collects no data.",
                      systemImage: "hand.raised")
            }

            Section("About") {
                LabeledContent("Version", value: Self.version)
                Link(destination: URL(string: "https://github.com/sergioarojasm98/freetab")!) {
                    Label("Source code (MIT)", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") { dismiss() }
            }
        }
        #endif
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
