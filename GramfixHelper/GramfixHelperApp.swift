import AppKit
import SwiftUI

@main
struct GramfixHelperApp: App {
    init() {
        let mainAppID = "com.gramfix.app"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains { $0.bundleIdentifier == mainAppID }
        
        if !isRunning {
            var path = Bundle.main.bundlePath as NSString
            path = path.deletingLastPathComponent as NSString
            path = path.deletingLastPathComponent as NSString
            path = path.deletingLastPathComponent as NSString
            path = path.deletingLastPathComponent as NSString
            
            let mainAppURL = URL(fileURLWithPath: path as String)
            NSWorkspace.shared.openApplication(at: mainAppURL, configuration: NSWorkspace.OpenConfiguration()) { app, error in
                if let error = error {
                    print("Failed to launch main app: \(error.localizedDescription)")
                }
            }
        }
        
        NSApplication.shared.terminate(nil)
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
