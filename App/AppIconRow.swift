import SwiftUI
import FamilyControls
import ManagedSettings

/// Overlapping app icons with a "+n" pill when the list is longer.
struct AppIconRow: View {
    let tokens: [ApplicationToken]
    var size: CGFloat = 30
    var maximum = 3

    var body: some View {
        HStack(spacing: -size / 4) {
            ForEach(Array(tokens.prefix(maximum)), id: \.self) { token in
                Label(token).labelStyle(.iconOnly)
                    .scaleEffect(size / 34)
                    .frame(width: size, height: size)
                    .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: size * 0.26))
                    .overlay(RoundedRectangle(cornerRadius: size * 0.26).strokeBorder(Color.black.opacity(0.5), lineWidth: 1))
            }
            if tokens.count > maximum {
                Text("+\(tokens.count - maximum)")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .frame(width: size, height: size)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.26))
            }
        }
        .accessibilityHidden(true)
    }
}
