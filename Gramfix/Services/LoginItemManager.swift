import Foundation
import ServiceManagement
import os.log

private let logger = Logger(subsystem: "com.gramfix.app", category: "LoginItemManager")

class LoginItemManager {
    static let shared = LoginItemManager()
    
    private let helperBundleID = "com.gramfix.app.helper"
    private var appService: SMAppService?
    
    private init() {
        appService = SMAppService.loginItem(identifier: helperBundleID)
    }
    
    var isEnabled: Bool {
        guard let appService = appService else { return false }
        return appService.status == .enabled
    }
    
    func setEnabled(_ enabled: Bool) -> Bool {
        guard let appService = appService else {
            logger.error("Failed to get SMAppService instance")
            return false
        }
        
        do {
            if enabled {
                try appService.register()
                logger.info("Login item enabled")
            } else {
                try appService.unregister()
                logger.info("Login item disabled")
            }
            return true
        } catch {
            logger.error("Failed to \(enabled ? "enable" : "disable") login item: \(error.localizedDescription)")
            return false
        }
    }
}

