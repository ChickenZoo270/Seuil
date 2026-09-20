import SwiftUI
import UIKit

/// Seuil is dark-first: black canvas, soft green glow, mint accents.
enum SeuilTheme {
    static let paper = Color.black
    static let ink = Color.white
    static let secondaryInk = Color.white.opacity(0.58)
    static let accent = Color(red: 0.66, green: 0.95, blue: 0.80)
    static let onAccent = Color.black
    static let glow = Color(red: 0.36, green: 0.55, blue: 0.45)
    static let success = Color(red: 0.20, green: 0.85, blue: 0.70)
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.86, green: 0.96, blue: 0.62), Color(red: 0.66, green: 0.95, blue: 0.80), Color(red: 0.55, green: 0.90, blue: 0.95)],
        startPoint: .leading, endPoint: .trailing)
}

struct SeuilMark: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 5, y: 31))
            path.addLine(to: CGPoint(x: 5, y: 14))
            path.addCurve(to: CGPoint(x: 27, y: 14), control1: CGPoint(x: 5, y: -1), control2: CGPoint(x: 27, y: -1))
            path.addLine(to: CGPoint(x: 27, y: 31))
            path.move(to: CGPoint(x: 16, y: 31))
            path.addLine(to: CGPoint(x: 32, y: 31))
        }.stroke(SeuilTheme.ink, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            .frame(width: 34, height: 34).accessibilityHidden(true)
    }
}
