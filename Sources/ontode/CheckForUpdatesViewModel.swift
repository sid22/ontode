import Sparkle
import SwiftUI

/// A SwiftUI-compatible wrapper around Sparkle's SPUStandardUpdaterController.
/// Provides an observable `canCheckForUpdates` property and a method to trigger
/// a manual check from a menu item.
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    let updater: SPUUpdater

    init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updater = controller.updater
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}

/// A SwiftUI view that renders a "Check for Updates…" button wired to Sparkle.
struct CheckForUpdatesView: View {
    @ObservedObject var viewModel: CheckForUpdatesViewModel

    var body: some View {
        Button("Check for Updates…") {
            viewModel.checkForUpdates()
        }
        .disabled(!viewModel.canCheckForUpdates)
    }
}
