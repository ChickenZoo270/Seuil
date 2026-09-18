import SwiftUI
import UIKit

enum SeuilTheme {
    static let paper = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.07, green: 0.12, blue: 0.15, alpha: 1) : UIColor(red: 0.93, green: 0.95, blue: 0.96, alpha: 1)
    })
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.86, green: 0.93, blue: 0.96, alpha: 1) : UIColor(red: 0.09, green: 0.24, blue: 0.30, alpha: 1)
    })
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.62, green: 0.80, blue: 0.89, alpha: 1) : UIColor(red: 0.14, green: 0.33, blue: 0.41, alpha: 1)
    })
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
