import DeviceActivity
import Foundation
import os

final class MonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        do {
            try SharedStorage.locked { state, save in
                // Late callbacks from previous sessions must never close a new session.
                guard state.session?.id == activity.rawValue else { return }
                state.session = nil
                SharedStorage.applyShield(state)
                try save(state)
            }
            DeviceActivityCenter().stopMonitoring([activity])
        } catch {
            Logger(subsystem: "Intention", category: "Monitor").error("Reblocking failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
