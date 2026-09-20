import SwiftUI
import IntentionCore

/// One card shown in a "Minuteur" rail: either a procedurally drawn scene (`Artwork`)
/// or, for meditations, a flat colour gradient — never a photo or third-party asset.
struct TimerRailItem: Identifiable, Hashable {
    let title: String
    var description: String? = nil
    let minutes: Int
    var artwork: String = "default"
    var ctaTitle: String = "Démarrer"
    var isMeditation = false
    var meditationColors: [Color] = []
    var isPro = false

    var id: String { "\(title)-\(minutes)" }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension TimerRailItem {
    /// Rail cards commit through the same sheet as the home "Démarrer" button.
    var asPreset: TimerPreset { TimerPreset(name: title, minutes: minutes, artwork: artwork, subtitle: description) }

    static let recent = TimerRailItem(title: "Focus total", minutes: 30, artwork: "default")

    static let forYou = [
        TimerRailItem(title: "Étude poussée", minutes: 90, artwork: "study"),
        TimerRailItem(title: "Trajet", minutes: 30, artwork: "commute"),
    ]

    static let detox = [
        TimerRailItem(title: "Prends l’air", description: "Pas d’apps distrayantes", minutes: 8 * 60, artwork: "air"),
        TimerRailItem(title: "Journée tranquille", description: "Une journée entière sans distraction", minutes: 24 * 60, artwork: "weekend"),
    ]

    static let sleepStories = [
        TimerRailItem(title: "Observatoire de montagne", description: "Une ascension silencieuse vers les étoiles.",
                     minutes: 45, artwork: "sleep", ctaTitle: "Lire"),
        TimerRailItem(title: "Dunes du désert", description: "Le vent glisse sur le sable, tout s’apaise.",
                     minutes: 40, artwork: "sleep", ctaTitle: "Lire"),
    ]

    static let meditations = [
        TimerRailItem(title: "Méditation de gratitude", description: "Termine la journée avec chaleur.", minutes: 3,
                     ctaTitle: "Démarrer", isMeditation: true,
                     meditationColors: [Color(red: 0.85, green: 0.56, blue: 0.47), Color(red: 0.55, green: 0.29, blue: 0.24)]),
        TimerRailItem(title: "Respiration profonde", description: "Retrouve ton calme intérieur.", minutes: 8,
                     ctaTitle: "Démarrer", isMeditation: true,
                     meditationColors: [Color(red: 0.25, green: 0.45, blue: 0.35), Color(red: 0.08, green: 0.18, blue: 0.14)],
                     isPro: true),
    ]
}

/// Rounded photo/gradient card: bottom scrim, title, optional description, duration meta, CTA pill.
struct TimerRailCard: View {
    let item: TimerRailItem
    /// `nil` lets the card fill the available width, used by the single "Récents" card.
    var width: CGFloat? = 200
    var height: CGFloat = 250
    let onStart: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background
            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
            content
        }
        .frame(width: width, height: height)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
        .overlay(alignment: .topLeading) {
            if item.isPro { ProBadge().padding(10) }
        }
    }

    @ViewBuilder private var background: some View {
        if item.isMeditation {
            LinearGradient(colors: item.meditationColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Artwork(key: item.artwork)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title).font(.title3.weight(.bold)).lineLimit(2).minimumScaleFactor(0.85)
            if let description = item.description {
                Text(description).font(.footnote).opacity(0.85).lineLimit(2)
            }
            HStack(spacing: 6) {
                Image(systemName: "clock").font(.caption2)
                Text(Scoring.duration(Double(item.minutes))).font(.caption.weight(.medium))
            }
            .opacity(0.85)
            Button(action: onStart) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.caption2.weight(.bold))
                    Text(item.ctaTitle).font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}

/// A title + grey subtitle followed by a horizontal, card-snapping rail.
struct TimerRailSection: View {
    let title: String
    var subtitle: String? = nil
    let items: [TimerRailItem]
    var cardHeight: CGFloat = 250
    var isEnabled = true
    let onStart: (TimerRailItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RailHeader(title: title, subtitle: subtitle)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(items) { item in
                        TimerRailCard(item: item, width: 200, height: cardHeight) { onStart(item) }
                            .disabled(!isEnabled)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }
}
