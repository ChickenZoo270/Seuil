import Foundation
import IntentionCore

extension AccessController {
    func saveRoutine(_ routine: Routine) {
        guard routine.window.isValid, !routine.isEmpty else { message = AppError.invalidRoutine.localizedDescription; return }
        if isHardModeActive, state.routines.contains(where: { $0.id == routine.id }) {
            message = AppError.hardMode.localizedDescription
            return
        }
        if let active = state.routines.first(where: { $0.id == routine.id }),
           active.isStrict, state.activeRoutineIDs.contains(active.id) {
            message = AppError.strict.localizedDescription
            return
        }
        mutate(restart: true) { current in
            if let index = current.routines.firstIndex(where: { $0.id == routine.id }) {
                current.routines[index] = routine
            } else {
                current.routines.append(routine)
            }
        }
        message = "Routine « \(routine.name) » enregistrée."
    }

    func setRoutineEnabled(_ enabled: Bool, id: String) {
        guard let routine = state.routines.first(where: { $0.id == id }) else { return }
        if !enabled, isHardModeActive { message = AppError.hardMode.localizedDescription; return }
        // A strict routine in progress cannot be switched off: that is the point of strict.
        if !enabled, routine.isStrict, state.activeRoutineIDs.contains(id) {
            message = AppError.strict.localizedDescription
            return
        }
        mutate(restart: true) { current in
            guard let index = current.routines.firstIndex(where: { $0.id == id }) else { return }
            current.routines[index].isEnabled = enabled
        }
    }

    func deleteRoutine(id: String) {
        if isHardModeActive { message = AppError.hardMode.localizedDescription; return }
        if let routine = state.routines.first(where: { $0.id == id }), routine.isStrict, state.activeRoutineIDs.contains(id) {
            message = AppError.strict.localizedDescription
            return
        }
        mutate(restart: true) { current in current.routines.removeAll { $0.id == id } }
    }

    func isLocked(_ routine: Routine) -> Bool {
        isHardModeActive || (routine.isStrict && state.activeRoutineIDs.contains(routine.id))
    }
}
