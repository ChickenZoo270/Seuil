import SwiftUI

/// A hand-drawn vintage cinema-ticket look for the emergency pass.
/// Reuses HoldToCommitButton (TimerView.swift), PageScaffold and glassCard (SettingsComponents.swift / DesignSystem.swift).
struct EmergencyTicketView: View {
    @ObservedObject var access: AccessController

    var body: some View {
        PageScaffold(title: "Pass d'urgence") {
            VStack(spacing: 22) {
                ticket
                explanation
                actionArea
            }
        }
    }

    // MARK: Ticket

    private var ticket: some View {
        VStack(spacing: 0) {
            header
            fieldsGrid
            perforation
            barcode
            footer
        }
        .padding(22)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 22, y: 14)
        .rotationEffect(.degrees(-1.5))
        .padding(.top, 10)
        .padding(.horizontal, 6)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PASS D'URGENCE")
                    .font(.system(.title2, design: .monospaced, weight: .black))
                    .foregroundStyle(.black)
                Text("ÉMIS PAR LE SERVICE DES EXCEPTIONS")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.55))
            }
            Spacer(minLength: 6)
            stamp
        }
        .padding(.bottom, 16)
    }

    private var stamp: some View {
        ZStack {
            Circle().stroke(Color.black.opacity(0.65), lineWidth: 2)
            Circle().stroke(Color.black.opacity(0.65), lineWidth: 1).padding(5)
            Text("SEUIL")
                .font(.system(.caption2, design: .monospaced, weight: .black))
                .foregroundStyle(.black.opacity(0.75))
        }
        .frame(width: 58, height: 58)
        .rotationEffect(.degrees(8))
    }

    private var fieldsGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
            GridRow {
                ticketField(label: "RAISON", value: "NE JUGE PAS, S'IL TE PLAÎT")
                ticketField(label: "ACCÈS", value: "TOUTES LES APPS")
            }
            GridRow {
                ticketField(label: "COÛT", value: "TA DIGNITÉ")
                ticketField(label: "VALIDITÉ", value: "1 HEURE, 1X / SEMAINE")
            }
        }
        .padding(.bottom, 18)
    }

    private func ticketField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .foregroundStyle(.black.opacity(0.45))
            Text(value)
                .font(.system(.footnote, design: .monospaced, weight: .black))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gridColumnAlignment(.leading)
    }

    private var perforation: some View {
        HStack(spacing: 0) {
            HalfCircleNotch(pointsRight: true).fill(SeuilTheme.paper).frame(width: 8, height: 16)
            dashedLine.frame(maxWidth: .infinity)
            HalfCircleNotch(pointsRight: false).fill(SeuilTheme.paper).frame(width: 8, height: 16)
        }
        .padding(.horizontal, -22)
        .padding(.bottom, 14)
    }

    private var dashedLine: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 1, y: 0))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        .foregroundStyle(.black.opacity(0.35))
        .frame(height: 1)
    }

    /// Barcode drawn from a fixed seed so it never changes between renders.
    private var barcode: some View {
        Canvas { context, size in
            var seed: UInt64 = 1_337
            func next() -> Double {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double((seed >> 33) & 0xFFFF) / Double(0xFFFF)
            }
            var x: CGFloat = 0
            while x < size.width {
                let barWidth = CGFloat(1 + next() * 2.6)
                if next() > 0.32 {
                    context.fill(Path(CGRect(x: x, y: 0, width: barWidth, height: size.height)), with: .color(.black))
                }
                x += barWidth + 1.2
            }
        }
        .frame(height: 46)
        .padding(.bottom, 14)
    }

    private var footer: some View {
        Text("CE PASS VA S'AUTODÉTRUIRE. PAS VRAIMENT.")
            .font(.system(.caption2, design: .monospaced, weight: .medium))
            .foregroundStyle(.black.opacity(0.4))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Below the ticket

    private var explanation: some View {
        Text("Une fois par semaine, débloque toutes tes apps pendant \(EmergencyPass.minutes) minutes, même en mode strict ou en Hard Mode. À garder pour les vraies urgences.")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundStyle(SeuilTheme.secondaryInk)
            .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var actionArea: some View {
        if access.isEmergencyPassAvailable {
            HoldToCommitButton(title: "Maintiens pour utiliser") { access.useEmergencyPass() }
                .accessibilityIdentifier("emergency.hold")
        } else {
            VStack(spacing: 6) {
                Text("Déjà utilisé cette semaine").font(.title3.weight(.semibold))
                if let next = EmergencyPass.nextAvailable(lastUsed: access.state.preferences.emergencyPassUsedAt) {
                    Text("De nouveau disponible le \(next.formatted(date: .abbreviated, time: .shortened)).")
                        .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .glassCard(cornerRadius: 32, padding: 16)
            .opacity(0.7)
            .accessibilityIdentifier("emergency.hold")
        }
    }
}

/// Half a circle, flat edge on one side, used as a perforation notch on the ticket.
private struct HalfCircleNotch: Shape {
    var pointsRight: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: pointsRight ? rect.minX : rect.maxX, y: rect.midY)
        let radius = rect.height / 2
        let start = pointsRight ? -90.0 : 90.0
        let end = pointsRight ? 90.0 : 270.0
        path.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        path.closeSubpath()
        return path
    }
}
