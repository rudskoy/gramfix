import Foundation
import Sparkle
import os.log

/// Centralized service for managing app updates via Sparkle
/// Provides a shared SPUUpdater instance for the entire app
final class UpdateService: ObservableObject {
    static let shared = UpdateService()
    
    /// The official update feed URL (hosted on public releases repo)
    static let feedURL = URL(string: "https://raw.githubusercontent.com/rudskoy/gramfix/main/appcast.xml")!
    
    /// The Sparkle updater controller
    private let updaterController: SPUStandardUpdaterController
    
    /// The updater delegate for error handling
    private let updaterDelegate: UpdaterDelegate
    
    /// The underlying SPUUpdater for direct access
    var updater: SPUUpdater {
        updaterController.updater
    }
    
    private init() {
        // Create the updater delegate for error handling
        updaterDelegate = UpdaterDelegate()
        
        // Initialize Sparkle with default settings
        // startingUpdater: true means it will automatically check for updates on launch
        // based on user preferences
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: updaterDelegate,
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

// MARK: - Updater Delegate

/// Delegate to handle Sparkle updater events and errors
final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    private let logger = Logger(subsystem: "com.gramfix.app", category: "UpdateService")
    
    func updater(_ updater: SPUUpdater, didFinishUpdateCheckFor updateCheck: SPUUpdateCheck, error: Error?) {
        if let error = error {
            logger.error("Update check failed: \(error.localizedDescription, privacy: .public)")
            
            // Log additional error details if available
            if let nsError = error as NSError? {
                logger.error("Error domain: \(nsError.domain, privacy: .public), code: \(nsError.code)")
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    logger.error("Underlying error: \(underlyingError.localizedDescription, privacy: .public)")
                }
            }
        } else {
            logger.info("Update check completed successfully")
        }
    }
    
    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        logger.error("Failed to download update \(item.versionString): \(error.localizedDescription, privacy: .public)")
        
        if let nsError = error as NSError? {
            logger.error("Download error domain: \(nsError.domain, privacy: .public), code: \(nsError.code)")
            
            // Provide more specific error information
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet:
                    logger.error("Network error: No internet connection")
                case NSURLErrorTimedOut:
                    logger.error("Network error: Request timed out")
                case NSURLErrorNetworkConnectionLost:
                    logger.error("Network error: Connection lost")
                default:
                    logger.error("Network error: \(nsError.localizedDescription, privacy: .public)")
                }
            }
        }
    }
    
    func updater(_ updater: SPUUpdater, failedToInstallUpdate item: SUAppcastItem, error: Error) {
        logger.error("Failed to install update \(item.versionString): \(error.localizedDescription, privacy: .public)")
        
        if let nsError = error as NSError? {
            logger.error("Installation error domain: \(nsError.domain, privacy: .public), code: \(nsError.code)")
            
            // Check for code signing errors (OSStatus -67056 = errSecCSBadSignature)
            if nsError.code == -67056 || nsError.localizedDescription.contains("Code Signing") || 
               nsError.localizedDescription.contains("corrupted") {
                logger.error("⚠️ CODE SIGNING ERROR DETECTED")
                logger.error("The update archive has a valid Sparkle signature, but the app inside failed Apple code signing validation.")
                logger.error("This typically means the app was built without proper Developer ID code signing.")
                logger.error("Solution: Rebuild the app with a valid Developer ID Application certificate.")
                logger.error("Error details: domain=\(nsError.domain, privacy: .public), code=\(nsError.code)")
            }
            
            // Common installation errors
            if nsError.domain == NSCocoaErrorDomain {
                switch nsError.code {
                case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
                    logger.error("Permission error: The app may not have sufficient permissions to install the update")
                case NSFileReadCorruptFileError:
                    logger.error("Corrupted file: The downloaded update file may be corrupted")
                default:
                    logger.error("File system error: \(nsError.localizedDescription, privacy: .public)")
                }
            }
        }
    }
    
    // Note: didFinishUpdateCycle is not a standard SPUUpdaterDelegate method
    // Removed to fix compilation error - SPUUpdateCycle type doesn't exist in Sparkle
    
    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        logger.info("Will install update \(item.versionString)")
    }
    
    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error?) {
        if let error = error {
            logger.info("No update found (with error): \(error.localizedDescription, privacy: .public)")
        } else {
            logger.info("No update found - app is up to date")
        }
    }
}

