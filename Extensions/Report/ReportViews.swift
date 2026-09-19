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
}

/// Upper arc gauge with the score in the middle.
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

/// Capsule showing a sub-score with a partial glowing outline.
struct SubScorePill: View {
    let symbol: String
    let title: String
    let score: Int?

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
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                    Text(score.map(String.init) ?? "–").monospacedDigit()
                }
                .font(.title3.weight(.semibold))
                .foregroundStyle(score == nil ? ReportColors.secondary : ReportColors.mint)
            }
            .frame(width: 104, height: 56)
            Text(title).font(.subheadline.weight(.semibold))
                .foregroundStyle(score == nil ? ReportColors.secondary : ReportColors.lime)
        }
    }
}

struct SubScoreRow: View {
    let scores: DailyScores

    var body: some View {
        VStack(spacing: 10) {
            Bracket().stroke(Color.white.opacity(0.18), lineWidth: 2).frame(height: 36).padding(.horizontal, 70)
            HStack(spacing: 14) {
                SubScorePill(symbol: "moon.fill", title: "Sommeil", score: scores.sleep)
                SubScorePill(symbol: "hourglass", title: "Focus", score: scores.focus)
                SubScorePill(symbol: "leaf.fill", title: "Repos", score: scores.rest)
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

struct ScreenTimeCard: View {
    let model: ReportModel

    var body: some View {
        let top = Array(model.apps.prefix(5))
        let longest = max(top.first?.minutes ?? 1, 1)
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Temps d’écran").font(.headline).foregroundStyle(ReportColors.secondary)
                Text(Scoring.duration(model.usage.totalMinutes)).font(.system(size: 40, weight: .semibold, design: .rounded))
                Text("Aujourd’hui").foregroundStyle(ReportColors.secondary)
            }
            Divider().overlay(Color.white.opacity(0.12))
            if top.isEmpty {
                Text("Pas encore d’utilisation aujourd’hui.").foregroundStyle(ReportColors.secondary)
            }
            ForEach(top) { app in
                HStack(spacing: 14) {
                    icon(app)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(app.name).font(.body)
                        GeometryReader { geo in
                            HStack(spacing: 10) {
                                Capsule()
                                    .fill(app.isDistracting ? AnyShapeStyle(ReportColors.bad.opacity(0.9)) : AnyShapeStyle(ReportColors.gauge))
                                    .frame(width: max(8, (geo.size.width - 90) * app.minutes / longest), height: 5)
                                Text(Scoring.duration(app.minutes)).font(.subheadline.monospacedDigit())
                                    .foregroundStyle(app.isDistracting ? ReportColors.bad : ReportColors.mint)
                                    .fixedSize()
                            }
                        }
                        .frame(height: 18)
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
    }

    @ViewBuilder
    private func icon(_ app: AppUsage) -> some View {
        if let token = app.token {
            Label(token).labelStyle(.iconOnly).scaleEffect(1.6).frame(width: 40, height: 40)
        } else {
            RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)).frame(width: 40, height: 40)
        }
    }
}

struct HomeReportView: View {
    let model: ReportModel

    var body: some View {
        VStack(spacing: 18) {
            ScoreArc(score: model.scores.overall)
            SubScoreRow(scores: model.scores)
            ScreenTimeCard(model: model).padding(.top, 12)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
}

/// Bar centred on the target ("OBJ"): green towards the left when better, red to the right when worse.
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
                Text("OBJ").font(.caption.weight(.bold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.black, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 2))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: 34)
    }
}

struct DetailReportView: View {
    let model: ReportModel

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(spacing: 16) {
                ScoreArc(score: model.scores.overall, size: 220)
                SubScoreRow(scores: model.scores)
            }
            .frame(maxWidth: .infinity)
            explanation("Focus", "Suit tes distractions, tes prises en main et tes déblocages : ce qui entame ta capacité à te concentrer en profondeur.")
            explanation("Repos", "Mesure les vraies pauses loin de l’écran et ton temps d’écran total sur la journée.")
            explanation("Sommeil", "Regarde l’écran entre minuit et 6 h, l’ennemi n°1 d’une bonne nuit.")
            Text("TEMPS FORTS DU JOUR").font(.footnote.weight(.semibold)).foregroundStyle(ReportColors.secondary)
            ForEach(Scoring.highlights(model.usage), id: \.title) { item in
                VStack(spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.title).font(.title3.weight(.semibold))
                        Text(item.value).font(.title3).foregroundStyle(ReportColors.secondary)
                        Spacer()
                        Text(item.rating.label).font(.title3.weight(.semibold))
                            .foregroundStyle(item.score >= 65 ? ReportColors.good : ReportColors.bad)
                    }
                    RatingBar(score: item.score)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
    }

    private func explanation(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Qu’est-ce que le score \(title) ?").font(.headline)
            Text(text).foregroundStyle(ReportColors.secondary)
        }
    }
}
