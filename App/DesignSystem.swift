import SwiftUI

/// Dark canvas with a soft green glow at the top.
struct GlowBackground: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [SeuilTheme.glow.opacity(0.55), SeuilTheme.glow.opacity(0.12), .clear],
                           center: .top, startRadius: 0, endRadius: 520)
                .scaleEffect(x: 1.6, y: 1, anchor: .top)
        }
        .ignoresSafeArea()
    }
}

/// Aurora gradient used for glowing borders.
enum Aurora {
    static let colors: [Color] = [Color(red: 0.93, green: 0.95, blue: 0.55), Color(red: 0.55, green: 0.93, blue: 0.70),
                                  Color(red: 0.45, green: 0.85, blue: 0.95), Color(red: 0.93, green: 0.95, blue: 0.55)]
    static var gradient: AngularGradient { AngularGradient(colors: colors, center: .center) }
}

/// Pill button: dark glass with an aurora glow along the bottom edge, or bright white.
struct PillButtonStyle: ButtonStyle {
    enum Variant { case glass, bright }
    var variant: Variant = .glass
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(variant == .bright ? Color.black : Color.white)
            .background {
                Capsule().fill(variant == .bright ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.08)))
                    .overlay {
                        Capsule()
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.15), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
                    }
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(LinearGradient(colors: Aurora.colors, startPoint: .leading, endPoint: .trailing))
                            .frame(height: 3)
                            .blur(radius: 3)
                            .opacity(variant == .glass ? 0.9 : 0.5)
                            .padding(.horizontal, 30)
                    }
                    .clipShape(Capsule())
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.55)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    /// Frosted card on the dark canvas.
    func glassCard(cornerRadius: CGFloat = 32, padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
    }
}

/// App-icon-like tile built from an SF Symbol.
struct GlyphTile: View {
    let symbol: String
    let tint: Color
    var background: Color = .white
    var size: CGFloat = 56

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(background.gradient)
            .frame(width: size, height: size)
            .overlay(Image(systemName: symbol).font(.system(size: size * 0.45, weight: .semibold)).foregroundStyle(tint))
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }
}

/// Stylised phone used by onboarding illustrations.
struct PhoneMock<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        RoundedRectangle(cornerRadius: 44, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(content.clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous)).padding(9))
            .overlay(alignment: .top) { Capsule().fill(Color.white.opacity(0.2)).frame(width: 74, height: 22).padding(.top, 22) }
            .overlay(RoundedRectangle(cornerRadius: 44, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 2))
            .frame(width: 210, height: 330)
            .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
    }
}

/// Glowing ring that slowly breathes: used by the pause challenge and onboarding.
struct BreathingRing: View {
    var size: CGFloat = 180
    var expanded: Bool

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.9), lineWidth: 5).blur(radius: 1)
            Circle().stroke(Aurora.gradient, lineWidth: 10).blur(radius: 10).opacity(0.8)
            Circle().stroke(Color.white.opacity(0.5), lineWidth: 18).blur(radius: 22)
        }
        .frame(width: size, height: size)
        .scaleEffect(expanded ? 1 : 0.72)
        .animation(.easeInOut(duration: 4), value: expanded)
    }
}

/// Slowly drifting colour field behind the breathing ring.
struct DriftingSky: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient(colors: [Color(red: 0.36, green: 0.38, blue: 0.48), Color(red: 0.62, green: 0.58, blue: 0.66)],
                               startPoint: .top, endPoint: .bottom)
                ForEach(0..<4, id: \.self) { index in
                    let phase = t / (7 + Double(index) * 2) + Double(index)
                    Circle()
                        .fill([Color.white, Color(red: 0.85, green: 0.75, blue: 0.85), Color(red: 0.7, green: 0.8, blue: 0.95), .white][index].opacity(0.45))
                        .frame(width: 180, height: 180)
                        .blur(radius: 40)
                        .offset(x: cos(phase) * 70, y: sin(phase * 1.3) * 110)
                }
            }
        }
    }
}
