import SwiftUI
import FamilyControls
import ManagedSettings
import IntentionCore

struct AccountView: View {
    @AppStorage("profile.name") private var name = ""
    @AppStorage("profile.profession") private var profession = ""
    @AppStorage("profile.age") private var age = 25
    @AppStorage("profile.hours") private var hours = 4.0

    var body: some View {
        PageScaffold(title: "Mon compte") {
            HStack {
                Spacer()
                ZStack {
                    Circle().fill(SeuilTheme.accentGradient).frame(width: 96, height: 96)
                    Text(name.first.map { String($0).uppercased() } ?? "?").font(.system(size: 40, weight: .bold)).foregroundStyle(.black)
                }
                Spacer()
            }
            SettingsCard {
                field(icon: "person.fill", title: "Ton prénom", text: $name, placeholder: "Adrien")
                RowDivider()
                field(icon: "briefcase.fill", title: "Profession", text: $profession, placeholder: "Étudiant, CEO…")
                RowDivider()
                Stepper(value: $age, in: 13...99) {
                    SettingsRowLabel(icon: "birthday.cake.fill", title: "Mon âge", subtitle: "\(age) ans", trailing: nil)
                        .padding(.horizontal, -20).padding(.vertical, -18)
                }
                .padding(.horizontal, 20).padding(.vertical, 18)
                RowDivider()
                Stepper(value: $hours, in: 1...12, step: 0.5) {
                    SettingsRowLabel(icon: "hourglass", title: "Temps d’écran initial", subtitle: "\(Scoring.duration(hours * 60)) par jour", trailing: nil)
                        .padding(.horizontal, -20).padding(.vertical, -18)
                }
                .padding(.horizontal, 20).padding(.vertical, 18)
            }
            Text("Ton profil reste sur cet iPhone. Seuil n’a ni compte ni serveur.")
                .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
        }
    }

    private func field(icon: String, title: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title3).foregroundStyle(SeuilTheme.secondaryInk).frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title3)
                TextField(placeholder, text: text).font(.body).foregroundStyle(SeuilTheme.secondaryInk)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }
}

struct NotificationSettingsView: View {
    @ObservedObject var access: AccessController

    var body: some View {
        PageScaffold(title: "Notifications") {
            SettingsCard {
                SettingsToggleRow(title: "Autofocus", subtitle: "Pings quand tu scrolles trop", isOn: access.preference(\.usageAlerts))
                RowDivider()
                NavigationLink { AutofocusView(access: access) } label: { SettingsRowLabel(title: "Réglages Autofocus") }
                    .buttonStyle(.plain)
                RowDivider()
                SettingsToggleRow(title: "Rappels", subtitle: "Un petit mot si tu n’as pas ouvert Seuil depuis quelques jours.",
                                  isOn: access.preference(\.reminders))
                RowDivider()
                SettingsToggleRow(title: "Service", subtitle: "Quand une règle démarre ou que ton minuteur se termine.",
                                  isOn: access.preference(\.serviceNotifications))
                RowDivider()
                SettingsToggleRow(title: "Rappels de déblocage", subtitle: "Quand ton déblocage est terminé.",
                                  isOn: access.preference(\.unlockReminders))
                RowDivider()
                SettingsToggleRow(title: "Rapport du soir", subtitle: "Chaque soir à 21 h, ton score du jour.",
                                  isOn: access.preference(\.dailyReport))
                RowDivider()
                SettingsToggleRow(title: "Limites de temps", subtitle: "Quand tu atteins une limite de temps.",
                                  isOn: access.preference(\.limitNotifications))
                RowDivider()
                SettingsToggleRow(title: "Streaks", subtitle: "Chaque matin, pour garder ta série en vie.",
                                  isOn: access.preference(\.streakNotifications))
            }
        }
    }
}

struct ShieldDesignView: View {
    @ObservedObject var access: AccessController
    @Environment(\.requestPro) private var requestPro
    // Not @EnvironmentObject: this page is reached both from a sheet in
    // ContentView and from a NavigationLink in SettingsView, and a missing
    // ancestor .environmentObject(ProStore) would hard-crash the app the
    // instant `store` is read. Pro status is derived from UserDefaults and
    // StoreKit entitlements (not instance-local state), so owning a private
    // instance here converges to the same value without that crash risk.
    @ObservedObject private var store = ProStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var preview = ShieldPack.standard.messages[0]
    @State private var previewPack = ShieldPack.standard

    var body: some View {
        PageScaffold(title: "Écrans de blocage") {
            PreviewPhone {
                VStack(spacing: 12) {
                    Text(previewPack.emoji).font(.system(size: 64))
                    Text(previewPack.title).font(.title2.weight(.semibold))
                        .lineLimit(2).minimumScaleFactor(0.8).multilineTextAlignment(.center)
                    Text(preview).font(.body).foregroundStyle(SeuilTheme.secondaryInk).multilineTextAlignment(.center)
                        .padding(.horizontal, 26)
                }
                .padding(.top, 90)
            }
            RailHeader(title: "Sélectionnées",
                       subtitle: "Un message est tiré au hasard parmi les séries activées à chaque ouverture d’une app bloquée.")
            SettingsCard {
                ForEach(ShieldPack.allCases, id: \.self) { pack in
                    packRow(pack)
                    if pack != ShieldPack.allCases.last { RowDivider() }
                }
            }
            HStack {
                Spacer()
                CircleIconButton(symbol: "checkmark", size: 52, prominent: true) { dismiss() }
                    .accessibilityLabel("Valider")
                    .accessibilityIdentifier("shields.confirm")
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    // A single Toggle (not a Button wrapping a nested Toggle) drives both the
    // row-wide tap and the switch, matching SettingsToggleRow's pattern —
    // nesting two interactive controls would fire both handlers per tap.
    private func packRow(_ pack: ShieldPack) -> some View {
        let locked = !store.isPro && !FreePlan.allows(pack)
        let isOn = access.state.preferences.shieldPacks.contains(pack)
        return Toggle(isOn: Binding(get: { isOn }, set: { on in
            if locked { requestPro() } else { toggle(pack, on: on) }
        })) {
            HStack(spacing: 16) {
                Text(pack.emoji).font(.title2).frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(pack.title).font(.title3.weight(.bold)).lineLimit(1).minimumScaleFactor(0.85)
                        if locked { ProBadge() }
                    }
                    Text(pack.summary).font(.body).foregroundStyle(SeuilTheme.secondaryInk)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
            }
        }
        // Left enabled (not `.disabled`) so a tap on a locked row still reaches
        // the binding's setter and calls requestPro(); the setter never
        // actually flips `shieldPacks` for a locked pack, so the switch snaps
        // back to its real (off) state on the next redraw.
        .tint(Color(red: 0.86, green: 0.96, blue: 0.62))
        .padding(.horizontal, 20).padding(.vertical, 16)
        .accessibilityLabel(pack.title)
    }

    private func toggle(_ pack: ShieldPack, on: Bool) {
        access.updatePreferences { preferences in
            if on { preferences.shieldPacks.insert(pack) } else if preferences.shieldPacks.count > 1 { preferences.shieldPacks.remove(pack) }
        }
        if on {
            previewPack = pack
            preview = pack.messages.randomElement() ?? preview
        }
    }
}

struct WaitingRoomView: View {
    @ObservedObject var access: AccessController
    @State private var showResistance = false
    @State private var trying = false
    @State private var result = ""

    var body: some View {
        PageScaffold(title: "Salle d’attente") {
            SettingsCard {
                Button { showResistance = true } label: {
                    SettingsRowLabel(icon: "shield.fill", title: "Résistance", subtitle: access.state.preferences.resistance.title)
                }
                .buttonStyle(.plain)
                RowDivider()
                Picker("Difficulté", selection: access.preference(\.difficulty)) {
                    ForEach(Difficulty.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(16)
            }
            group(title: "Moments de calme", subtitle: "Respiration guidée pour te détendre et te recentrer.",
                  symbol: "circle.hexagongrid.fill", tint: SeuilTheme.success, kinds: [.pause])
            group(title: "Casse-tête", subtitle: "Soigne ton brainrot avec ces jeux.",
                  symbol: "brain.head.profile", tint: .purple, kinds: [.math, .puzzle])
            group(title: "Réflexion", subtitle: "Prends le temps d’écrire avant d’ouvrir.",
                  symbol: "text.quote", tint: .orange, kinds: [.typing, .reason])
            Button("Essayer le défi") { result = ""; trying = true }
                .buttonStyle(PillButtonStyle())
                .accessibilityIdentifier("settings.tryChallenge")
            if !result.isEmpty {
                Text(result).font(.footnote).foregroundStyle(SeuilTheme.accent).accessibilityIdentifier("settings.challengeResult")
            }
        }
        .sheet(isPresented: $showResistance) { ResistanceSheet(access: access) }
        .sheet(isPresented: $trying) {
            NavigationStack {
                ScrollView {
                    ChallengeView(preferences: access.state.preferences, minutes: Policy.defaultUnlockMinutes) {
                        trying = false
                        result = "Défi réussi. C’est ce qui t’attendra avant chaque déblocage."
                    }
                    .padding(24)
                }
                .background(GlowBackground())
                .navigationTitle("Salle d’attente")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { trying = false } } }
            }
            .presentationBackground(.black)
        }
    }

    private func group(title: String, subtitle: String, symbol: String, tint: Color, kinds: [ChallengeKind]) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.title2.weight(.semibold))
                    Text(subtitle).foregroundStyle(SeuilTheme.secondaryInk)
                }
                Spacer()
                Image(systemName: symbol).font(.title).foregroundStyle(tint.gradient)
                    .frame(width: 56, height: 56)
                    .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(20)
            ForEach(kinds, id: \.self) { kind in
                RowDivider()
                SettingsToggleRow(title: kind.title, isOn: Binding(
                    get: { access.state.preferences.enabledChallenges.contains(kind) },
                    set: { on in
                        access.updatePreferences { preferences in
                            if on { preferences.enabledChallenges.insert(kind) }
                            else if preferences.enabledChallenges.count > 1 { preferences.enabledChallenges.remove(kind) }
                        }
                    }))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.05), tint.opacity(0.22)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color.white.opacity(0.07)))
    }
}

struct ResistanceSheet: View {
    @ObservedObject var access: AccessController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                CircleIconButton(symbol: "xmark", size: 44) { dismiss() }
                Spacer()
                Text("Résistance").font(.title2.weight(.semibold))
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            SettingsCard {
                ForEach(Resistance.allCases, id: \.self) { resistance in
                    Button {
                        access.updatePreferences { $0.resistance = resistance }
                        dismiss()
                    } label: {
                        SettingsRowLabel(icon: resistance == .standard ? "shield.fill" : "checkmark.shield.fill",
                                         title: resistance.title, subtitle: resistance.summary,
                                         trailing: access.state.preferences.resistance == resistance ? "checkmark" : nil)
                    }
                    .buttonStyle(.plain)
                    if resistance != Resistance.allCases.last { RowDivider() }
                }
            }
            Spacer()
        }
        .padding(20)
        .presentationDetents([.height(380)])
        .presentationBackground(Color(white: 0.1))
        .foregroundStyle(.white)
    }
}
