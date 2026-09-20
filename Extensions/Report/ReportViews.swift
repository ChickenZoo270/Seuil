import SwiftUI
import FamilyControls
import ManagedSettings
import IntentionCore

enum ReportColors {
    static let mint = Color(red: 0.66, green: 0.95, blue: 0.80)
    static let lime = Color(red: 0.86, green: 0.96, blue: 0.62)
    static let cyan = Color(red: 0.55, green: 0.90, blue: 0.95)
    static let good = Color(red: 0.20, green: 0.85, blue: 0.70)
    static let bad = Color(red: 0.98, green: 0.36, blue: 0.47)
    static let secondary = Color.white.opacity(0.55)
    static var gauge: LinearGradient { LinearGradient(colors: [lime, mint, cyan], startPoint: .leading, endPoint: .trailing) }
    /// Usage bars for apps flagged as distracting ("Apps distrayantes").
    static var distracting: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(colors: [bad, bad.opacity(0.55)], startPoint: .leading, endPoint: .trailing))
    }
    /// Usage bars for everything else ("Autres apps").
    static var other: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(colors: [mint, cyan], startPoint: .leading, endPoint: .trailing))
    }
}

/// Upper arc gauge with the score in the middle (Aujourd'hui detail screen).
struct ScoreArc: View {
    let score: Int
    var size: CGFloat = 250
    private let sweep = 0.62

    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: sweep)
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(90 + (1 - sweep) * 180))
            Circle().trim(from: 0, to: sweep * Double(score) / 100)
                .stroke(ReportColors.gauge, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(90 + (1 - sweep) * 180))
                .shadow(color: ReportColors.mint.opacity(0.5), radius: 8)
            VStack(spacing: 2) {
                Text("\(score)").font(.system(size: 84, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(LinearGradient(colors: [ReportColors.lime, ReportColors.cyan], startPoint: .top, endPoint: .bottom))
                Text("Score Seuil").font(.headline).foregroundStyle(ReportColors.mint)
            }
            .offset(y: 8)
        }
        .frame(width: size, height: size)
        .frame(height: size * 0.72, alignment: .top)
    }
}

/// Compact "Score / 87 ▲" header used on the Home screen.
struct ScoreHeader: View {
    let score: Int
    /// Day-over-day trend arrow. The report extension only ever receives today's
    /// activity segments, so there is no honest way to compute a real trend here;
    /// this stays nil (and the arrow hidden) until a previous score is shared via
    /// SharedState, rather than showing a made-up direction.
    let trendUp: Bool?

    var body: some View {
        VStack(spacing: 2) {
            Text("Score").font(.subheadline).foregroundStyle(ReportColors.secondary)
            HStack(spacing: 6) {
                Text("\(score)")
                    .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(LinearGradient(colors: [ReportColors.mint, .white], startPoint: .leading, endPoint: .trailing))
                if let trendUp {
                    Image(systemName: "triangle.fill")
                        .rotationEffect(trendUp ? .zero : .degrees(180))
                        .font(.caption2)
                        .foregroundStyle(trendUp ? ReportColors.good : ReportColors.bad)
                }
            }
        }
    }
}

/// A sub-score the "Aujourd'hui" pills can be selected against.
enum ScoreMetric: String, CaseIterable, Identifiable, Equatable {
    case sleep, focus, rest

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .sleep: return "moon.fill"
        case .focus: return "hourglass"
        case .rest: return "leaf.fill"
        }
    }

    var title: String {
        switch self {
        case .sleep: return "Sommeil"
        case .focus: return "Focus"
        case .rest: return "Repos"
        }
    }

    var question: String { "Qu’est-ce que le score \(title) ?" }

    var explanation: String {
        switch self {
        case .sleep:
            return "Le Score de Sommeil capture ce qui se passe avant, pendant et après le sommeil, et son effet sur ta journée à venir."
        case .focus:
            return "Le Score de Focus suit les distractions et montre comment tes habitudes façonnent ta capacité à te concentrer en profondeur."
        case .rest:
            return "Ton Score de Repos mesure à quel point ton corps et ton esprit récupèrent au cours de la journée."
        }
    }

    /// Which "temps forts" row this pill relates to, so selecting a pill can point at its figure.
    var highlightTitle: String {
        switch self {
        case .sleep: return "Écran la nuit"
        case .focus: return "Distractions"
        case .rest: return "Hors ligne"
        }
    }
}

/// Capsule showing a sub-score with a partial glowing outline, optionally selectable.
struct SubScorePill: View {
    let symbol: String
    let title: String
    let score: Int?
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Capsule().fill(Color.white.opacity(0.06))
                Capsule().stroke(Color.white.opacity(0.08), lineWidth: 3)
                if let score {
                    Capsule().trim(from: 0, to: Double(score) / 100)
                        .stroke(ReportColors.gauge, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                } else {
                    Capsule().stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
                if isSelected {
                    Capsule().stroke(ReportColors.mint, lineWidth: 2)
                        .shadow(color: ReportColors.mint.opacity(0.6), radius: 6)
                }
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                    Text(score.map(String.init) ?? "–").monospacedDigit()
                }
                .font(.title3.weight(.semibold))
                .foregroundStyle(score == nil ? ReportColors.secondary : ReportColors.mint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .frame(width: 104, height: 56)
            Text(title).font(.subheadline.weight(.semibold))
                .foregroundStyle(score == nil ? ReportColors.secondary : ReportColors.lime)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

/// The 3 sub-score pills, branching from the main score. Pass `selected` to make
/// them tappable (used on the "Aujourd'hui" detail screen); omit it on Home,
/// where the pills are purely informational.
struct SubScorePillsRow: View {
    let scores: DailyScores
    var selected: Binding<ScoreMetric?>?

    var body: some View {
        VStack(spacing: 10) {
            Bracket().stroke(Color.white.opacity(0.18), lineWidth: 2).frame(height: 36).padding(.horizontal, 70)
            HStack(spacing: 14) {
                pill(.sleep, score: scores.sleep)
                pill(.focus, score: scores.focus)
                pill(.rest, score: scores.rest)
            }
        }
    }

    private func pill(_ metric: ScoreMetric, score: Int?) -> some View {
        SubScorePill(symbol: metric.symbol, title: metric.title, score: score,
                     isSelected: selected?.wrappedValue == metric)
            .contentShape(Rectangle())
            .onTapGesture {
                guard let selected else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    selected.wrappedValue = (selected.wrappedValue == metric) ? nil : metric
                }
            }
    }
}

/// "⎴"-like connector from the score to the three sub-scores.
struct Bracket: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 16
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.midY), control: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX - r, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.midX + r, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.midY))
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

/// Empty squircle for apps whose icon token isn't available (fully generic fallback).
struct AppIcon: View {
    let token: ApplicationToken?

    var body: some View {
        if let token {
            Label(token).labelStyle(.iconOnly).scaleEffect(1.6).frame(width: 40, height: 40)
        } else {
            RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)).frame(width: 40, height: 40)
        }
    }
}

/// One app-usage row: icon, name, a bar proportional to `longest`, and the duration.
/// Shared by the Home screen-time card and the breakdown sections so the two never drift apart.
struct AppRow: View {
    let app: AppUsage
    let longest: Double
    let accent: AnyShapeStyle
    let valueColor: Color

    var body: some View {
        HStack(spacing: 14) {
            AppIcon(token: app.token)
            VStack(alignment: .leading, spacing: 8) {
                Text(app.name).font(.body).lineLimit(1).minimumScaleFactor(0.8)
                GeometryReader { geo in
                    let trackWidth = max(geo.size.width - 90, 8)
                    HStack(spacing: 10) {
                        Capsule()
                            .fill(accent)
                            .frame(width: max(8, trackWidth * app.minutes / max(longest, 1)), height: 5)
                        Text(Scoring.duration(app.minutes)).font(.subheadline.monospacedDigit())
                            .foregroundStyle(valueColor)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                .frame(height: 18)
            }
        }
    }
}

struct ScreenTimeCard: View {
    let model: ReportModel

    var body: some View {
        let top = Array(model.apps.prefix(5))
        let longest = max(top.first?.minutes ?? 1, 1)
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Temps d’écran").font(.headline).foregroundStyle(ReportColors.secondary)
                Text(Scoring.duration(model.usage.totalMinutes))
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Aujourd’hui").foregroundStyle(ReportColors.secondary)
            }
            Divider().overlay(Color.white.opacity(0.12))
            if top.isEmpty {
                Text("Pas encore d’utilisation aujourd’hui.").foregroundStyle(ReportColors.secondary)
            }
            ForEach(top) { app in
                AppRow(app: app, longest: longest,
                       accent: app.isDistracting ? ReportColors.distracting : ReportColors.other,
                       valueColor: app.isDistracting ? ReportColors.bad : ReportColors.mint)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
    }
}

struct HomeReportView: View {
    let model: ReportModel

    var body: some View {
        VStack(spacing: 18) {
            ScoreHeader(score: model.scores.overall, trendUp: model.trendUp)
            SubScorePillsRow(scores: model.scores)
            ScreenTimeCard(model: model).padding(.top, 12)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
}

/// Bar centred on the target average ("MOY."): mint towards the left when better, coral to the right when worse.
struct RatingBar: View {
    let score: Int

    var body: some View {
        GeometryReader { geo in
            let half = geo.size.width / 2
            let deviation = CGFloat(score - 50) / 50
            ZStack {
                Capsule().fill(Color.white.opacity(0.06)).frame(height: 6)
                Capsule()
                    .fill(deviation >= 0
                          ? LinearGradient(colors: [ReportColors.good, ReportColors.good.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                          : LinearGradient(colors: [ReportColors.bad.opacity(0.2), ReportColors.bad], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, half * abs(deviation)), height: 6)
                    .offset(x: deviation >= 0 ? -half * abs(deviation) / 2 : half * abs(deviation) / 2)
                Text("MOY.").font(.caption2.weight(.bold))
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.black, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 2))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: 34)
    }
}

/// Explainer heading + body, swapped in place when a pill is selected.
private struct ExplainerBlock: View {
    let metric: ScoreMetric?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric?.question ?? "Qu’est-ce que le score Seuil ?")
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
            Text(metric?.explanation ?? defaultExplanation)
                .foregroundStyle(ReportColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .id(metric)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var defaultExplanation: String {
        "Le Score Seuil combine des données sur ton sommeil, ta concentration et ton repos en une mesure unique de l’alignement de la technologie avec ton bien-être."
    }
}

/// One "temps forts du jour" row: bold label, value, coloured status word and a MOY. gauge.
private struct HighlightRow: View {
    let item: Highlight
    let isEmphasized: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title).font(.title3.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(item.value).font(.title3).foregroundStyle(ReportColors.secondary).lineLimit(1)
                Spacer()
                Text(item.rating.label).font(.title3.weight(.semibold))
                    .foregroundStyle(isGood ? ReportColors.good : ReportColors.bad)
                    .lineLimit(1)
            }
            RatingBar(score: item.score)
        }
        .padding(isEmphasized ? 12 : 0)
        .background {
            if isEmphasized {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05))
            }
        }
    }

    private var isGood: Bool { item.rating == .great || item.rating == .good }
}

struct DetailReportView: View {
    let model: ReportModel
    @State private var selected: ScoreMetric?

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(spacing: 16) {
                ScoreArc(score: model.scores.overall, size: 220)
                SubScorePillsRow(scores: model.scores, selected: $selected)
            }
            .frame(maxWidth: .infinity)
            ExplainerBlock(metric: selected)
            Text("TEMPS FORTS DU JOUR").font(.footnote.weight(.semibold)).foregroundStyle(ReportColors.secondary)
            ForEach(Scoring.highlights(model.usage), id: \.title) { item in
                HighlightRow(item: item, isEmphasized: selected?.highlightTitle == item.title)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .animation(.easeOut(duration: 0.25), value: selected)
    }
}

/// "Jour / Semaine / Mois" period picker for the screen-time breakdown.
enum ReportPeriod: String, CaseIterable, Identifiable, Equatable {
    case day, week, month

    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: return "Jour"
        case .week: return "Semaine"
        case .month: return "Mois"
        }
    }
}

private struct PeriodControl: View {
    @Binding var period: ReportPeriod
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ReportPeriod.allCases) { item in
                Text(item.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(period == item ? Color.white : ReportColors.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if period == item {
                            Capsule().fill(Color.white.opacity(0.14))
                                .matchedGeometryEffect(id: "period-highlight", in: namespace)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.25)) { period = item } }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05), in: Capsule())
    }
}

/// One "Apps distrayantes" / "Autres apps" section: header with total, top-5 rows,
/// and a "Tout afficher" row when there is more to show.
private struct AppUsageSection: View {
    let title: String
    let apps: [AppUsage]
    let accent: AnyShapeStyle
    let valueColor: Color

    private var top: [AppUsage] { Array(apps.prefix(5)) }
    private var total: Double { apps.reduce(0) { $0 + $1.minutes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.headline).lineLimit(1)
                Spacer()
                Text(Scoring.duration(total)).foregroundStyle(ReportColors.secondary).lineLimit(1)
            }
            if apps.isEmpty {
                Text("Rien à signaler.").foregroundStyle(ReportColors.secondary)
            } else {
                let longest = max(top.first?.minutes ?? 1, 1)
                ForEach(top) { app in
                    AppRow(app: app, longest: longest, accent: accent, valueColor: valueColor)
                }
                if apps.count > top.count {
                    HStack {
                        Text("Tout afficher").foregroundStyle(ReportColors.secondary)
                        Spacer()
                        Image(systemName: "chevron.down").foregroundStyle(ReportColors.secondary)
                    }
                }
            }
        }
    }
}

/// Real, today-only breakdown. There is no shared baseline to compare against yet,
/// so the delta line is simply omitted rather than inventing one (see spec rule:
/// never fabricate figures the extension does not actually have).
private struct DayBreakdownContent: View {
    let model: ReportModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Scoring.duration(model.usage.totalMinutes))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Temps d’écran").foregroundStyle(ReportColors.secondary)
            }
            AppUsageSection(title: "Apps distrayantes", apps: model.apps.filter(\.isDistracting),
                             accent: ReportColors.distracting, valueColor: ReportColors.bad)
            AppUsageSection(title: "Autres apps", apps: model.apps.filter { !$0.isDistracting },
                             accent: ReportColors.other, valueColor: ReportColors.mint)
        }
    }
}

/// Neutral, honest stand-in for Semaine/Mois: this extension only ever receives
/// today's DeviceActivity segments, so multi-day totals aren't available here.
/// Showing a calm placeholder beats crashing or guessing numbers.
private struct HistoryPlaceholder: View {
    let period: ReportPeriod

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.questionmark")
                .font(.largeTitle)
                .foregroundStyle(ReportColors.secondary)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(ReportColors.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var message: String {
        period == .week
            ? "L’historique de la semaine n’est pas encore disponible ici."
            : "L’historique du mois n’est pas encore disponible ici."
    }
}

/// Screen-time breakdown with the Jour/Semaine/Mois segmented control.
struct BreakdownReportView: View {
    let model: ReportModel
    @State private var period: ReportPeriod = .day

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PeriodControl(period: $period)
            content
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .animation(.easeInOut(duration: 0.2), value: period)
    }

    @ViewBuilder
    private var content: some View {
        switch period {
        case .day: DayBreakdownContent(model: model)
        case .week, .month: HistoryPlaceholder(period: period)
        }
    }
}
