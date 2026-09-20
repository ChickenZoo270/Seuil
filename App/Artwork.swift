import SwiftUI
import FamilyControls
import ManagedSettings

/// Procedural card art: gradient, light, particles and a large soft symbol.
/// Everything is drawn in code, so the app ships no photography.
struct Artwork: View {
    let key: String

    private struct Style {
        let colors: [Color]
        let symbol: String
        var stars = false
        var beam: Color? = nil
        var symbolTint: Color = .white
    }

    private var style: Style {
        switch key {
        case "work": return Style(colors: [c(0.30, 0.27, 0.24), c(0.62, 0.55, 0.47), c(0.18, 0.18, 0.2)], symbol: "desktopcomputer", beam: c(1, 0.93, 0.8))
        case "laser": return Style(colors: [c(0.05, 0.08, 0.16), c(0.14, 0.2, 0.34)], symbol: "scope", stars: true, beam: c(0.6, 0.8, 1))
        case "unwind": return Style(colors: [c(0.2, 0.2, 0.12), c(0.55, 0.5, 0.3), c(0.12, 0.14, 0.12)], symbol: "tree.fill", beam: c(1, 0.95, 0.75))
        case "sleep": return Style(colors: [c(0.04, 0.05, 0.12), c(0.12, 0.13, 0.25)], symbol: "moon.stars.fill", stars: true, beam: c(1, 0.85, 0.6))
        case "read": return Style(colors: [c(0.18, 0.22, 0.3), c(0.36, 0.42, 0.52)], symbol: "book.fill", beam: c(0.9, 0.95, 1))
        case "sport": return Style(colors: [c(0.35, 0.15, 0.08), c(0.2, 0.28, 0.36)], symbol: "dumbbell.fill", beam: c(1, 0.6, 0.4))
        case "air": return Style(colors: [c(0.2, 0.35, 0.1), c(0.55, 0.7, 0.3), c(0.1, 0.2, 0.08)], symbol: "leaf.fill", beam: c(0.95, 1, 0.8))
        case "calm": return Style(colors: [c(0.75, 0.7, 0.9), c(0.95, 0.75, 0.85), c(0.25, 0.3, 0.35)], symbol: "sun.horizon.fill")
        case "study": return Style(colors: [c(0.5, 0.48, 0.44), c(0.8, 0.76, 0.68), c(0.3, 0.28, 0.25)], symbol: "doc.text.fill", beam: c(1, 0.95, 0.8))
        case "commute": return Style(colors: [c(0.12, 0.22, 0.38), c(0.3, 0.45, 0.65)], symbol: "tram.fill")
        case "weekend": return Style(colors: [c(0.14, 0.16, 0.14), c(0.35, 0.33, 0.28)], symbol: "camera.macro", stars: true)
        case "limit": return Style(colors: [c(0.12, 0.14, 0.22), c(0.45, 0.35, 0.3)], symbol: "hourglass", beam: c(1, 0.9, 0.7))
        default: return Style(colors: [c(0.12, 0.14, 0.13), c(0.22, 0.26, 0.24)], symbol: "sparkles", stars: true)
        }
    }

    var body: some View {
        let style = style
        ZStack {
            LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            if let beam = style.beam {
                LinearGradient(colors: [beam.opacity(0.55), .clear], startPoint: .topTrailing, endPoint: .center)
                    .rotationEffect(.degrees(12))
                    .blendMode(.screen)
            }
            // Stable seed: Swift's hashValue changes on every launch.
            if style.stars { StarField(seed: key.unicodeScalars.reduce(7) { $0 &* 31 &+ Int($1.value) }) }
            Image(systemName: style.symbol)
                .font(.system(size: 150, weight: .regular))
                .foregroundStyle(style.symbolTint.opacity(0.35))
                .blur(radius: 1.5)
                .rotationEffect(.degrees(-8))
                .offset(x: 30, y: -10)
            LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
        }
        .clipped()
    }

    private func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
}

struct StarField: View {
    let seed: Int

    var body: some View {
        Canvas { context, size in
            var rng = SplitMix(seed: UInt64(bitPattern: Int64(seed)))
            for _ in 0..<70 {
                let x = Double(rng.next() % 1000) / 1000 * size.width
                let y = Double(rng.next() % 1000) / 1000 * size.height
                let r = Double(rng.next() % 100) / 100 * 1.6 + 0.3
                let alpha = Double(rng.next() % 100) / 100 * 0.7 + 0.2
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(alpha)))
            }
        }
    }

    private struct SplitMix {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
}

/// Iridescent orb that slowly shifts colour: Seuil's emblem on the home screen.
struct GlowOrb: View {
    var size: CGFloat = 200

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .fill(AngularGradient(colors: [.cyan, .mint, .yellow, .pink, .blue, .cyan], center: .center, angle: .degrees(t * 12)))
                    .blur(radius: 18)
                    .opacity(0.9)
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.95), .white.opacity(0.0)], center: .init(x: 0.35, y: 0.3), startRadius: 2, endRadius: size * 0.45))
                    .blendMode(.screen)
                Circle()
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.7), .clear, .white.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
            }
            .frame(width: size, height: size)
            .scaleEffect(1 + 0.03 * sin(t / 2))
            .shadow(color: .mint.opacity(0.45), radius: 40)
        }
    }
}

/// Rule/template card: art background, schedule, title, blocked apps and an action.
struct RuleCard<Accessory: View>: View {
    let artwork: String
    let icon: String
    let caption: String
    let title: String
    let subtitle: String
    var tokens: [ApplicationToken] = []
    var width: CGFloat = 200
    var height: CGFloat = 250
    @ViewBuilder var accessory: Accessory

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Artwork(key: artwork)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: icon).font(.title2)
                    Image(systemName: "arrow.right").font(.headline).opacity(0.5)
                    Image(systemName: "shield.fill").font(.title2)
                }
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(caption).font(.subheadline).opacity(0.75).lineLimit(1).minimumScaleFactor(0.8)
                        Text(title).font(.title3.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.85)
                        HStack(spacing: 6) {
                            Text(subtitle).font(.subheadline).opacity(0.7).lineLimit(1).minimumScaleFactor(0.8)
                            if !tokens.isEmpty { AppIconRow(tokens: tokens, size: 24) }
                        }
                    }
                    Spacer(minLength: 4)
                    accessory
                }
            }
            .padding(18)
            .foregroundStyle(.white)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
    }
}

struct CircleIconButton: View {
    let symbol: String
    var size: CGFloat = 52
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .frame(width: size, height: size)
                .foregroundStyle(prominent ? Color.black : Color.white)
                .background(prominent ? AnyShapeStyle(SeuilTheme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.1)), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.weight(.semibold))
            if let subtitle { Text(subtitle).foregroundStyle(SeuilTheme.secondaryInk) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
