import SwiftUI
import IntentionCore

/// Every trophy is a door, drawn in code: wood, stone, torii, glass, moon, temple, gold, light.
struct DoorArt: View {
    let door: Door
    var locked = false

    var body: some View {
        ZStack {
            switch door {
            case .wood: wood
            case .stone: stone
            case .torii: torii
            case .glass: glass
            case .moon: moon
            case .temple: temple
            case .gold: gold
            case .light: light
            }
        }
        .frame(width: 150, height: 230)
        .saturation(locked ? 0 : 1)
        .opacity(locked ? 0.45 : 1)
        .shadow(color: locked ? .clear : glow.opacity(0.7), radius: 30)
        .overlay {
            if locked {
                Image(systemName: "lock.fill").font(.title).foregroundStyle(.white.opacity(0.8))
                    .padding(12).background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    private var glow: Color {
        switch door {
        case .wood: return .orange
        case .stone: return .gray
        case .torii: return .red
        case .glass: return .cyan
        case .moon: return .indigo
        case .temple: return .teal
        case .gold: return .yellow
        case .light: return .white
        }
    }

    // MARK: Doors

    private var wood: some View {
        ArchFrame(frameColor: Color(red: 0.32, green: 0.2, blue: 0.11), lineWidth: 14) {
            ZStack {
                LinearGradient(colors: [Color(red: 0.45, green: 0.28, blue: 0.15), Color(red: 0.28, green: 0.17, blue: 0.09)],
                               startPoint: .top, endPoint: .bottom)
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle().fill(.black.opacity(0.18)).frame(width: 1.5).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                Circle().fill(Color(red: 0.85, green: 0.72, blue: 0.4)).frame(width: 12).offset(x: 45, y: 20)
            }
        }
    }

    private var stone: some View {
        ArchFrame(frameColor: Color(white: 0.42), lineWidth: 16) {
            ZStack {
                LinearGradient(colors: [Color(white: 0.3), Color(white: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 6) {
                    ForEach(0..<6, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(0..<2, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 3).fill(Color(white: row.isMultiple(of: 2) ? 0.26 : 0.22))
                            }
                        }
                    }
                }
                .padding(10)
            }
        }
    }

    private var torii: some View {
        ZStack {
            VStack(spacing: 0) {
                Capsule().fill(Color(red: 0.78, green: 0.16, blue: 0.13)).frame(width: 150, height: 18)
                Capsule().fill(Color(red: 0.62, green: 0.12, blue: 0.1)).frame(width: 120, height: 12).padding(.top, 8)
                Spacer()
            }
            HStack(spacing: 70) {
                Capsule().fill(Color(red: 0.72, green: 0.14, blue: 0.12)).frame(width: 20)
                Capsule().fill(Color(red: 0.72, green: 0.14, blue: 0.12)).frame(width: 20)
            }
            .padding(.top, 30)
            Capsule().fill(Color(red: 0.72, green: 0.14, blue: 0.12)).frame(width: 110, height: 10).offset(y: -40)
        }
    }

    private var glass: some View {
        ArchFrame(frameColor: Color(white: 0.75), lineWidth: 8) {
            ZStack {
                LinearGradient(colors: [.cyan.opacity(0.55), .white.opacity(0.25), .mint.opacity(0.45)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 0) { ForEach(0..<3, id: \.self) { _ in Rectangle().fill(.white.opacity(0.35)).frame(height: 1.5).frame(maxHeight: .infinity, alignment: .bottom) } }
                Rectangle().fill(LinearGradient(colors: [.white.opacity(0.7), .clear], startPoint: .topLeading, endPoint: .center))
                    .rotationEffect(.degrees(20))
            }
        }
    }

    private var moon: some View {
        ZStack {
            Circle().strokeBorder(LinearGradient(colors: [.indigo, .purple, .blue], startPoint: .top, endPoint: .bottom), lineWidth: 16)
                .frame(width: 170, height: 170)
            Circle().fill(RadialGradient(colors: [.indigo.opacity(0.7), .black], center: .center, startRadius: 4, endRadius: 80))
                .frame(width: 150, height: 150)
            StarField(seed: 42).frame(width: 150, height: 150).clipShape(Circle())
        }
    }

    private var temple: some View {
        VStack(spacing: 0) {
            Triangle().fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.6)], startPoint: .top, endPoint: .bottom))
                .frame(width: 160, height: 46)
            Rectangle().fill(Color(white: 0.78)).frame(width: 150, height: 10)
            HStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { _ in
                    Capsule().fill(LinearGradient(colors: [Color(white: 0.9), Color(white: 0.55)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 20)
                }
            }
            .frame(height: 150)
            Rectangle().fill(Color(white: 0.7)).frame(width: 165, height: 12)
        }
    }

    private var gold: some View {
        ArchFrame(frameColor: Color(red: 0.85, green: 0.68, blue: 0.24), lineWidth: 14) {
            ZStack {
                LinearGradient(colors: [Color(red: 0.95, green: 0.82, blue: 0.4), Color(red: 0.6, green: 0.44, blue: 0.12)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().strokeBorder(Color(red: 0.4, green: 0.28, blue: 0.05), lineWidth: 3).frame(width: 38, height: 38)
                    }
                }
                Rectangle().fill(Color(red: 0.4, green: 0.28, blue: 0.05)).frame(width: 2)
            }
        }
    }

    private var light: some View {
        ZStack {
            ArchFrame(frameColor: .white.opacity(0.9), lineWidth: 6) {
                LinearGradient(colors: [.white, .yellow.opacity(0.8), .white.opacity(0.4)], startPoint: .top, endPoint: .bottom)
            }
            .blur(radius: 1)
            ArchFrame(frameColor: .clear, lineWidth: 0) { Color.white.opacity(0.9) }
                .blur(radius: 26)
        }
    }
}

/// Arched doorway: rounded top, straight sides, thick frame.
struct ArchFrame<Content: View>: View {
    let frameColor: Color
    let lineWidth: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        content
            .clipShape(ArchShape())
            .overlay(ArchShape().strokeBorder(frameColor, lineWidth: lineWidth))
            .frame(width: 140, height: 220)
    }
}

struct ArchShape: InsettableShape {
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> ArchShape {
        var copy = self
        copy.inset += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let radius = r.width / 2
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
        path.addArc(center: CGPoint(x: r.midX, y: r.minY + radius), radius: radius,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Night scene with a stone pedestal, where a door is displayed.
struct DoorScene: View {
    let door: Door
    let locked: Bool

    var body: some View {
        ZStack {
            Color.black
            StarField(seed: door.rawValue.unicodeScalars.reduce(3) { $0 &* 31 &+ Int($1.value) })
            RadialGradient(colors: [SeuilTheme.glow.opacity(locked ? 0.15 : 0.5), .clear], center: .center, startRadius: 10, endRadius: 260)
            VStack(spacing: 0) {
                DoorArt(door: door, locked: locked)
                Ellipse()
                    .fill(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.08)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 230, height: 54)
                    .overlay(Ellipse().stroke(Color.white.opacity(0.08)))
                    .offset(y: -12)
            }
        }
    }
}

/// Full-screen trophy gallery, one page per door.
struct DoorsView: View {
    @ObservedObject var access: AccessController
    @State private var selection: Door
    @Environment(\.dismiss) private var dismiss

    init(access: AccessController, start: Door? = nil) {
        self.access = access
        _selection = State(initialValue: start ?? Door.latest(access.state.progressStats(now: Date())) ?? .wood)
    }

    var body: some View {
        let stats = access.state.progressStats(now: Date())
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            TabView(selection: $selection) {
                ForEach(Door.allCases, id: \.self) { door in
                    page(door, stats: stats).tag(door)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)
            HStack {
                CircleIconButton(symbol: "xmark", size: 46) { dismiss() }.accessibilityLabel("Fermer")
                Spacer()
                if selection.isUnlocked(stats) {
                    ShareLink(item: "J’ai franchi « \(selection.title) » avec Seuil 🔥") {
                        Image(systemName: "square.and.arrow.up").font(.title3.weight(.semibold))
                            .frame(width: 46, height: 46).background(Color.white.opacity(0.1), in: Circle())
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .foregroundStyle(.white)
    }

    private func page(_ door: Door, stats: ProgressStats) -> some View {
        let progress = door.progress(stats)
        let unlocked = door.isUnlocked(stats)
        return VStack(spacing: 18) {
            VStack(spacing: 10) {
                Text(door.title).font(.system(size: 30, weight: .bold)).multilineTextAlignment(.center)
                Text(unlocked ? door.celebration : door.goal)
                    .multilineTextAlignment(.center).foregroundStyle(SeuilTheme.secondaryInk)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 70)
            DoorScene(door: door, locked: !unlocked)
                .frame(height: 380)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .padding(.horizontal, 20)
            VStack(spacing: 10) {
                ProgressView(value: Double(progress.current), total: Double(progress.target))
                    .tint(SeuilTheme.accent).padding(.horizontal, 60)
                Text("\(progress.current)/\(progress.target)").font(.headline).foregroundStyle(SeuilTheme.secondaryInk)
                Label(unlocked ? "Franchie" : "Verrouillée", systemImage: unlocked ? "checkmark.circle.fill" : "lock.fill")
                    .font(.title3)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(Color.white.opacity(0.07), in: Capsule())
                    .foregroundStyle(unlocked ? SeuilTheme.accent : SeuilTheme.secondaryInk)
                    .padding(.horizontal, 24)
            }
            Spacer(minLength: 30)
        }
        .accessibilityIdentifier("door.\(door.rawValue)")
    }
}

/// Settings entry: every door as a row, with progress, opening the gallery on tap.
struct DoorsList: View {
    @ObservedObject var access: AccessController
    @State private var opened: Door?

    var body: some View {
        let stats = access.state.progressStats(now: Date())
        PageScaffold(title: "Mes portes") {
            Text("Chaque seuil franchi ouvre une nouvelle porte. Elles restent à toi, sur cet iPhone.")
                .foregroundStyle(SeuilTheme.secondaryInk)
            ForEach(Door.allCases, id: \.self) { door in
                let progress = door.progress(stats)
                let unlocked = door.isUnlocked(stats)
                Button { opened = door } label: {
                    HStack(spacing: 18) {
                        DoorArt(door: door, locked: !unlocked)
                            .scaleEffect(0.42)
                            .frame(width: 70, height: 100)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(door.title).font(.title3.weight(.semibold))
                            Text(unlocked ? door.celebration : door.goal)
                                .font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                            ProgressView(value: Double(progress.current), total: Double(progress.target))
                                .tint(unlocked ? SeuilTheme.accent : SeuilTheme.secondaryInk)
                            Text("\(progress.current)/\(progress.target)").font(.caption).foregroundStyle(SeuilTheme.secondaryInk)
                        }
                    }
                    .glassCard(cornerRadius: 28, padding: 16)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("doorRow.\(door.rawValue)")
            }
        }
        .fullScreenCover(item: $opened) { door in DoorsView(access: access, start: door) }
    }
}

extension Door: Identifiable {
    public var id: String { rawValue }
}
