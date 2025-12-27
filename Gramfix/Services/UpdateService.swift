import Foundation
import Sparkle

/// Centralized service for managing app updates via Sparkle
/// Provides a shared SPUUpdater instance for the entire app
final class UpdateService: ObservableObject {
    static let shared = UpdateService()
    
    /// The official update feed URL (hosted on public releases repo)
    static let feedURL = URL(string: "https://raw.githubusercontent.com/rudskoy/gramfix/main/appcast.xml")!
    
    /// The Sparkle updater controller
    private let updaterController: SPUStandardUpdaterController
    
    /// The underlying SPUUpdater for direct access
    var updater: SPUUpdater {
        updaterController.updater
    }
    
    private init() {
        // Initialize Sparkle with default settings
        // startingUpdater: true means it will automatically check for updates on launch
        // based on user preferences
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        // Set the feed URL
        updater.setFeedURL(Self.feedURL)
    }
    
    /// Manually trigger an update check
    func checkForUpdates() {
        updater.checkForUpdates()
    }
    
    /// Check if the updater can currently check for updates
    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }
}

