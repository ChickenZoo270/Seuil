import SwiftUI
import FamilyControls
import IntentionCore

struct RoutinesView: View {
    @ObservedObject var access: AccessController
    @State private var editing: Routine?

    private static let templates: [Routine] = [
        Routine(name: "Matin sans écran", window: RoutineWindow(startMinute: 7 * 60, endMinute: 9 * 60, weekdays: RoutineWindow.allWeekdays)),
        Routine(name: "Travail", window: RoutineWindow(startMinute: 9 * 60, endMinute: 12 * 60, weekdays: [2, 3, 4, 5, 6])),
        Routine(name: "Coucher", window: RoutineWindow(startMinute: 22 * 60, endMinute: 7 * 60, weekdays: RoutineWindow.allWeekdays), isStrict: true),
    ]

    var body: some View {
        List {
            Section {
                Text("Comme la limite de temps d’écran d’Apple : à ces horaires, les apps choisies sont bloquées. En mode strict, aucun déblocage n’est possible.")
                    .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
            }
            if !access.state.routines.isEmpty {
                Section("Mes routines") {
                    ForEach(access.state.routines) { routine in row(routine) }
                }
            }
            Section("Ajouter") {
                ForEach(Self.templates, id: \.name) { template in
                    Button { editing = Routine(name: template.name, window: template.window, isStrict: template.isStrict) } label: {
                        VStack(alignment: .leading) {
                            Text(template.name)
                            Text(template.window.summary).font(.caption).foregroundStyle(SeuilTheme.secondaryInk)
                        }
                    }
                }
                Button { editing = Routine(name: "Ma routine") } label: { Label("Routine personnalisée", systemImage: "plus") }
            }
            if !access.message.isEmpty {
                Section { Text(access.message).font(.footnote) }
            }
        }
        .navigationTitle("Routines")
        .sheet(item: $editing) { routine in
            NavigationStack {
                RoutineEditor(
                    routine: routine,
                    isNew: !access.state.routines.contains { $0.id == routine.id },
                    onSave: { access.saveRoutine($0) },
                    onDelete: { access.deleteRoutine(id: routine.id) })
            }
        }
    }

    private func row(_ routine: Routine) -> some View {
        let locked = access.isLocked(routine)
        return HStack {
            Button { if !locked { editing = routine } } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(routine.name).font(.headline)
                        if routine.isStrict { Image(systemName: "lock.fill").font(.caption) }
                        if access.state.activeRoutineIDs.contains(routine.id) {
                            Text("En cours").font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(SeuilTheme.accent.opacity(0.2), in: Capsule())
                        }
                    }
                    Text(routine.window.summary).font(.caption).foregroundStyle(SeuilTheme.secondaryInk)
                    Text("\(routine.applications.count) apps · \(routine.categories.count) catégories")
                        .font(.caption2).foregroundStyle(SeuilTheme.secondaryInk)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Toggle("Activée", isOn: Binding(get: { routine.isEnabled },
                                            set: { access.setRoutineEnabled($0, id: routine.id) }))
                .labelsHidden()
                .disabled(locked)
        }
    }
}

struct RoutineEditor: View {
    @State var routine: Routine
    let isNew: Bool
    let onSave: (Routine) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        Form {
            Section { TextField("Nom", text: $routine.name) }
            Section("Horaire") {
                DatePicker("Début", selection: time(\.startMinute), displayedComponents: .hourAndMinute)
                DatePicker("Fin", selection: time(\.endMinute), displayedComponents: .hourAndMinute)
                if routine.window.crossesMidnight {
                    Text("Se termine le lendemain matin.").font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                }
                if routine.window.durationMinutes < RoutineWindow.minimumMinutes {
                    Text("Au moins 15 minutes.").font(.footnote).foregroundStyle(.red)
                }
            }
            Section("Jours") {
                HStack(spacing: 6) {
                    ForEach(RoutineWindow.displayOrder, id: \.self) { day in dayButton(day) }
                }
            }
            Section {
                Button(routine.isEmpty ? "Choisir les apps à bloquer" : "Modifier les apps à bloquer") {
                    selection = FamilyActivitySelection()
                    selection.applicationTokens = routine.applications
                    selection.categoryTokens = routine.categories
                    showPicker = true
                }
                if !routine.isEmpty {
                    Text("\(routine.applications.count) apps · \(routine.categories.count) catégories")
                        .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                }
            } header: { Text("À bloquer") } footer: { Text("Tu peux choisir des catégories entières, comme Réseaux sociaux ou Jeux.") }
            Section {
                Toggle("Mode strict", isOn: $routine.isStrict)
            } footer: { Text("En mode strict, aucun défi ne permet de débloquer une app pendant la routine, et la routine ne peut pas être désactivée tant qu’elle est en cours.") }
            if !isNew {
                Section { Button("Supprimer la routine", role: .destructive) { onDelete(); dismiss() } }
            }
        }
        .navigationTitle(isNew ? "Nouvelle routine" : routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") { onSave(routine); dismiss() }
                    .disabled(!routine.window.isValid || routine.isEmpty || routine.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: showPicker) { old, new in
            if old && !new {
                routine.applications = selection.applicationTokens
                routine.categories = selection.categoryTokens
            }
        }
    }

    private func time(_ keyPath: WritableKeyPath<RoutineWindow, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minute = routine.window[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                routine.window[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            })
    }

    private func dayButton(_ day: Int) -> some View {
        let selected = routine.window.weekdays.contains(day)
        return Button {
            if selected { routine.window.weekdays.remove(day) } else { routine.window.weekdays.insert(day) }
        } label: {
            Text(RoutineWindow.shortDayNames[day] ?? "")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(selected ? SeuilTheme.accent : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(selected ? SeuilTheme.onAccent : SeuilTheme.ink)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
