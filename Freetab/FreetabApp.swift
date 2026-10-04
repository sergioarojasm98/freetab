import SwiftData
import SwiftUI

@main
struct FreetabApp: App {
    let container: ModelContainer

    init() {
        container = Self.makeContainer(demo: CommandLine.arguments.contains("-demo"))
    }

    var body: some Scene {
        WindowGroup {
            AppLockGate {
                RootView()
            }
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1000, height: 700)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .frame(width: 420)
        }
        #endif
    }

    // swiftlint:disable force_try - an in-memory or local store failing to open is unrecoverable
    /// iCloud-synced store when the app is signed with the CloudKit entitlement; local-only otherwise (unsigned
    /// development builds) or if CloudKit setup fails. `-demo` uses an in-memory store with sample data.
    @MainActor
    static func makeContainer(demo: Bool) -> ModelContainer {
        let schema = Schema(FreetabSchema.models)
        if demo {
            let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            DemoData.load(into: container.mainContext)
            return container
        }
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .automatic))
        } catch {
            print("Freetab: CloudKit store unavailable (\(error)); using a local store")
            return try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .none))
        }
    }
    // swiftlint:enable force_try
}
