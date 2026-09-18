import ManagedSettings
import Foundation
import os

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard action == .primaryButtonPressed else { completionHandler(.close); return }
        do {
            try SharedStorage.locked { state, save in
                state.pendingApplication = application
                try save(state)
            }
            if #available(iOS 26.5, *) {
                completionHandler(.openParentalControlsApp)
            } else {
                completionHandler(.close)
            }
        } catch {
            Logger(subsystem: "Intention", category: "ShieldAction").error("Cannot persist requested app: \(error.localizedDescription, privacy: .public)")
            completionHandler(.close)
        }
    }
}
