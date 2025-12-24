import Foundation
import Sparkle

/// Available update channels with their feed URLs
enum UpdateChannel: String, CaseIterable, Identifiable {
    case clipsaAI = "clipsa-ai"
    case rudskoy = "rudskoy"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .clipsaAI: return "Clipsa AI (Official)"
        case .rudskoy: return "Rudskoy (Developer)"
        }
    }
    
    var feedURL: URL {
        switch self {
        case .clipsaAI:
            return URL(string: "https://raw.githubusercontent.com/clipsa-ai/clipsa/main/appcast.xml")!
        case .rudskoy:
            return URL(string: "https://raw.githubusercontent.com/rudskoy/clipsa/main/appcast.xml")!
        }
    }
}

/// Centralized service for managing app updates via Sparkle
/// Provides a shared SPUUpdater instance for the entire app
final class UpdateService: ObservableObject {
    static let shared = UpdateService()
    
    /// The Sparkle updater controller
    private let updaterController: SPUStandardUpdaterController
    
    /// The underlying SPUUpdater for direct access
    var updater: SPUUpdater {
        updaterController.updater
    }
    
    /// Current update channel (persisted in UserDefaults)
    @Published var currentChannel: UpdateChannel {
        didSet {
            UserDefaults.standard.set(currentChannel.rawValue, forKey: "updateChannel")
            applyChannel()
        }
    }
    
    private init() {
        // Load saved channel or default to clipsaAI
        let savedChannel = UserDefaults.standard.string(forKey: "updateChannel") ?? UpdateChannel.clipsaAI.rawValue
        self.currentChannel = UpdateChannel(rawValue: savedChannel) ?? .clipsaAI
        
        // Initialize Sparkle with default settings
        // startingUpdater: true means it will automatically check for updates on launch
        // based on user preferences
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        // Apply the channel after initialization
        applyChannel()
    }
    
    /// Apply the current channel's feed URL to the updater
    private func applyChannel() {
        updater.setFeedURL(currentChannel.feedURL)
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

