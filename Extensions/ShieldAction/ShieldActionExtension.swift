import ManagedSettings
import Foundation
import os

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard action == .primaryButtonPressed else { completionHandler(.close); return }
        do {
            let canUnlock = try SharedStorage.locked { state, save in
                let now = Date()
                guard !state.isStrictlyBlocked(application, now: now),
                      state.rule(for: application)?.remainingUnlocks(now: now) != 0 else { return false }
                state.pendingApplication = application
                try save(state)
                return true
            }
            if canUnlock, #available(iOS 26.5, *) {
                completionHandler(.openParentalControlsApp)
            } else {
                completionHandler(.close)
            }
        } catch {
            Logger(subsystem: "Intention", category: "ShieldAction").error("Cannot persist requested app: \(error.localizedDescription, privacy: .public)")
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }
}
