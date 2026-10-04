import SwiftData
import SwiftUI

struct RootView: View {
    @State private var selection: Debt?
    @Query(sort: \Debt.date, order: .reverse) private var debts: [Debt]

    var body: some View {
        NavigationSplitView {
            HomeView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380)
        } detail: {
            NavigationStack {
                if let selection {
                    DebtDetailView(debt: selection, onDelete: { self.selection = nil })
                        .id(selection.persistentModelID)
                } else {
                    ContentUnavailableView(
                        "No account selected",
                        systemImage: "rectangle.stack",
                        description: Text("Pick an account to see its payments, or add a new one with +.")
                    )
                }
            }
        }
        .task {
            // Screenshot/demo aid: `-selectFirst` opens the most recent active account.
            if CommandLine.arguments.contains("-selectFirst") {
                selection = debts.first { !$0.isSettled }
            }
        }
    }
}
