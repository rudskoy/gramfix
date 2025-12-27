import SwiftUI
import Sparkle

/// A SwiftUI view that provides a "Check for Updates" button
/// Integrates with Sparkle's SPUUpdater and observes its state
struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    
    init(updater: SPUUpdater) {
        self.viewModel = CheckForUpdatesViewModel(updater: updater)
    }
    
    var body: some View {
        Button("Check for Updates…") {
            viewModel.checkForUpdates()
        }
        .disabled(!viewModel.canCheckForUpdates)
    }
}

/// ViewModel that observes the Sparkle updater state
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    
    private let updater: SPUUpdater
    
    init(updater: SPUUpdater) {
        self.updater = updater
        
        // Observe the canCheckForUpdates property from Sparkle
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    func checkForUpdates() {
        updater.checkForUpdates()
    }
}

