import LocalAuthentication
import SwiftUI

/// Optional Face ID / Touch ID / passcode lock. Locks again whenever the app goes to the background.
struct AppLockGate<Content: View>: View {
    @AppStorage("lockEnabled") private var lockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    @State private var failed = false
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            content
                .blur(radius: locked ? 24 : 0)
                .allowsHitTesting(!locked)
            if locked {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("Freetab is locked")
                        .font(.title2.bold())
                    Button(failed ? "Try again" : "Unlock", action: authenticate)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                .padding(40)
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
            }
        }
        .onAppear { if lockEnabled { authenticate() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { unlocked = false }
            if phase == .active, locked { authenticate() }
        }
    }

    private var locked: Bool { lockEnabled && !unlocked }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode or biometrics on this device: a lock can't protect anything, so don't trap the user.
            unlocked = true
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String(localized: "Unlock your accounts")) { success, _ in
            Task { @MainActor in
                unlocked = success
                failed = !success
            }
        }
    }
}
