import AVFoundation
import SwiftUI

/// Ambiences synthesised on the fly: no audio files, no network, no licensing.
enum Ambience: String, CaseIterable, Identifiable {
    case rain, ocean, wind, night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rain: return "Pluie"
        case .ocean: return "Océan"
        case .wind: return "Vent"
        case .night: return "Nuit d’été"
        }
    }

    var symbol: String {
        switch self {
        case .rain: return "cloud.rain.fill"
        case .ocean: return "water.waves"
        case .wind: return "wind"
        case .night: return "moon.stars.fill"
        }
    }

    var tint: Color {
        switch self {
        case .rain: return .blue
        case .ocean: return .teal
        case .wind: return .mint
        case .night: return .indigo
        }
    }

    /// Low-pass smoothing, amplitude and how slowly the swell breathes.
    var recipe: (smoothing: Float, gain: Float, swellHz: Float, swellDepth: Float) {
        switch self {
        case .rain: return (0.55, 0.16, 0, 0)
        case .ocean: return (0.96, 0.5, 0.09, 0.85)
        case .wind: return (0.9, 0.3, 0.05, 0.5)
        case .night: return (0.8, 0.12, 0.35, 0.3)
        }
    }
}

/// Plays one ambience at a time with a filtered noise generator.
@MainActor
final class AmbientPlayer: ObservableObject {
    @Published private(set) var playing: Ambience?

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var phase: Float = 0
    private var previous: Float = 0

    func toggle(_ ambience: Ambience) {
        if playing == ambience { stop() } else { start(ambience) }
    }

    func start(_ ambience: Ambience) {
        stop()
        let format = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate)
        let recipe = ambience.recipe
        // Brown-ish noise: a low-pass on white noise, with a slow swell on top.
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let white = Float.random(in: -1...1)
                self.previous = self.previous * recipe.smoothing + white * (1 - recipe.smoothing)
                var value = self.previous * recipe.gain * 4
                if recipe.swellHz > 0 {
                    self.phase += 2 * .pi * recipe.swellHz / sampleRate
                    if self.phase > 2 * .pi { self.phase -= 2 * .pi }
                    let swell = (1 - recipe.swellDepth) + recipe.swellDepth * (0.5 + 0.5 * sin(self.phase))
                    value *= swell
                }
                for buffer in buffers {
                    let pointer = UnsafeMutableBufferPointer<Float>(buffer)
                    pointer[frame] = max(-1, min(1, value))
                }
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        source = node
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            playing = ambience
        } catch {
            stop()
        }
    }

    func stop() {
        engine.stop()
        if let source {
            engine.detach(source)
            self.source = nil
        }
        previous = 0
        phase = 0
        playing = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Horizontal row of ambience bubbles, shown under the timer.
struct AmbienceRow: View {
    @ObservedObject var player: AmbientPlayer
    @EnvironmentObject private var store: ProStore
    @Environment(\.requestPro) private var requestPro

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                SectionTitle(title: "Ambiances", subtitle: "Des sons générés sur ton iPhone pour t’aider à te concentrer.")
                if !store.isPro { ProBadge() }
            }
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(Ambience.allCases) { ambience in
                        Button {
                            guard store.isPro else { requestPro(); return }
                            player.toggle(ambience)
                        } label: {
                            VStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(RadialGradient(colors: [ambience.tint.opacity(0.85), .black], center: .topLeading, startRadius: 4, endRadius: 90))
                                        .frame(width: 96, height: 96)
                                    Circle().strokeBorder(Color.white.opacity(player.playing == ambience ? 0.8 : 0.15), lineWidth: 2)
                                        .frame(width: 96, height: 96)
                                    Image(systemName: player.playing == ambience ? "pause.fill" : ambience.symbol)
                                        .font(.title2).foregroundStyle(.white)
                                }
                                Text(ambience.title).font(.subheadline.weight(.medium))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("ambience.\(ambience.rawValue)")
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }
}
