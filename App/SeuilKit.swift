import SwiftUI
import IntentionCore

/// Small parts shared by the rule sheets, the settings pages and the paywall.
/// They exist once here so every screen keeps the same shape and rhythm.

/// Mint outline capsule marking a feature reserved for Seuil Pro.
struct ProBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill").font(.system(size: 9, weight: .bold))
            Text("PRO").font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(SeuilTheme.accent)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .overlay(Capsule().strokeBorder(SeuilTheme.accent.opacity(0.7), lineWidth: 1))
        .accessibilityLabel("Réservé à Seuil Pro")
    }
}

/// Seven circles, one per day, Monday first. Selected days are solid white.
struct WeekdayCircles: View {
    @Binding var days: Set<Int>
    private let letters = ["L", "M", "M", "J", "V", "S", "D"]
    /// Calendar weekdays, Monday (2) through Sunday (1).
    private let weekdays = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                let day = weekdays[index]
                let selected = days.contains(day)
                Button {
                    if selected { days.remove(day) } else { days.insert(day) }
                } label: {
                    Text(letter)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selected ? Color.black : SeuilTheme.secondaryInk)
                        .frame(width: 36, height: 36)
                        .background(selected ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.08)), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Self.name(of: day))
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(maxWidth: .infinity)
    }

    static func name(of weekday: Int) -> String {
        switch weekday {
        case 2: return "Lundi"
        case 3: return "Mardi"
        case 4: return "Mercredi"
        case 5: return "Jeudi"
        case 6: return "Vendredi"
        case 7: return "Samedi"
        default: return "Dimanche"
        }
    }

    /// "Week-ends", "En semaine", "Tous les jours" or a list of initials.
    static func summary(_ days: Set<Int>) -> String {
        if days.isEmpty { return "Jamais" }
        if days == Set([1, 2, 3, 4, 5, 6, 7]) { return "Tous les jours" }
        if days == Set([1, 7]) { return "Week-ends" }
        if days == Set([2, 3, 4, 5, 6]) { return "En semaine" }
        return [2, 3, 4, 5, 6, 7, 1].filter(days.contains).map { String(name(of: $0).prefix(2)) }.joined(separator: " ")
    }
}

/// A value with two stacked chevrons that opens a list of choices.
struct ChevronStepper<Value: Hashable>: View {
    let values: [Value]
    let title: (Value) -> String
    @Binding var selection: Value
    var tint: Color = .white

    var body: some View {
        Menu {
            ForEach(values, id: \.self) { value in
                Button { selection = value } label: {
                    if value == selection { Label(title(value), systemImage: "checkmark") } else { Text(title(value)) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(title(selection)).font(.title3.weight(.medium)).foregroundStyle(tint)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SeuilTheme.secondaryInk)
            }
        }
        .accessibilityLabel(title(selection))
    }
}

/// Minus, a white disc holding the count, plus.
struct CountStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...99
    var step: Int = 1

    var body: some View {
        HStack(spacing: 12) {
            button("minus") { value = max(range.lowerBound, value - step) }
                .disabled(value <= range.lowerBound)
            Text("\(value)")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 40, height: 40)
                .background(Color.white, in: Circle())
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: value)
            button("plus") { value = min(range.upperBound, value + step) }
                .disabled(value >= range.upperBound)
        }
    }

    private func button(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "plus" ? "Augmenter" : "Diminuer")
    }
}

/// Grab handle, a round button on each side and a centred title: the top of every sheet.
struct SheetChrome<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            Text(title).font(.title3.weight(.semibold)).lineLimit(1)
            HStack {
                leading
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }
}

/// Grouped rows of "label … value", separated by hairlines.
struct InfoRowsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct InfoRow<Trailing: View>: View {
    let label: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Text(label).font(.body)
            Spacer(minLength: 12)
            trailing.foregroundStyle(SeuilTheme.secondaryInk)
        }
        .padding(.horizontal, 20).padding(.vertical, 17)
    }
}

/// "De 09:00 / À 12:00" joined by a dotted line, as on a timetable.
struct TimeRangeCard: View {
    @Binding var start: Int
    @Binding var end: Int
    var minutes: [Int] = stride(from: 0, to: 24 * 60, by: 15).map { $0 }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle().fill(Color.white).frame(width: 9, height: 9)
                DottedLine().stroke(style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(width: 1.5)
                Circle().strokeBorder(Color.white, lineWidth: 1.5).frame(width: 9, height: 9)
            }
            .padding(.vertical, 22)
            VStack(spacing: 0) {
                row("De", value: $start)
                RowDivider()
                row("À", value: $end)
            }
        }
        .padding(.horizontal, 20)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func row(_ label: String, value: Binding<Int>) -> some View {
        HStack {
            Text(label).font(.body).foregroundStyle(SeuilTheme.secondaryInk)
            Spacer()
            ChevronStepper(values: minutes, title: Self.clock, selection: value)
        }
        .padding(.vertical, 16)
    }

    static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

private struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

/// The dark-to-mint pill every screen uses to confirm a commitment.
struct GradientPillLabel: View {
    let title: String
    var symbol: String?

    var body: some View {
        HStack(spacing: 8) {
            if let symbol { Image(systemName: symbol).font(.headline) }
            Text(title).font(.title3.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background {
            Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.08), SeuilTheme.accent.opacity(0.85)],
                                          startPoint: .leading, endPoint: .trailing))
        }
    }
}

/// Section header: a bold title with an optional explaining line under it.
struct RailHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.weight(.semibold))
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
