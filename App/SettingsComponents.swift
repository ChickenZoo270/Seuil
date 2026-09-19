import SwiftUI

/// Rounded dark card holding rows separated by hairlines.
struct SettingsCard<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).font(.title3.weight(.semibold)).padding(.leading, 8) }
            VStack(spacing: 0) { content }
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color.white.opacity(0.07)))
        }
    }
}

struct RowDivider: View {
    var body: some View { Divider().overlay(Color.white.opacity(0.08)).padding(.leading, 64) }
}

/// Icon, title, optional subtitle and trailing value.
struct SettingsRowLabel: View {
    var icon: String? = nil
    var emoji: String? = nil
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var trailing: String? = "chevron.right"

    var body: some View {
        HStack(spacing: 16) {
            if let emoji {
                Text(emoji).font(.title2).frame(width: 32)
            } else if let icon {
                Image(systemName: icon).font(.title3).foregroundStyle(SeuilTheme.secondaryInk).frame(width: 32)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title3)
                if let subtitle { Text(subtitle).font(.body).foregroundStyle(SeuilTheme.secondaryInk) }
            }
            Spacer(minLength: 8)
            if let value { Text(value).font(.body).foregroundStyle(SeuilTheme.secondaryInk) }
            if let trailing { Image(systemName: trailing).font(.body.weight(.semibold)).foregroundStyle(SeuilTheme.secondaryInk) }
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
        .contentShape(Rectangle())
    }
}

/// Row with a switch on the right, tinted like the rest of Seuil.
struct SettingsToggleRow: View {
    var icon: String? = nil
    var emoji: String? = nil
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingsRowLabel(icon: icon, emoji: emoji, title: title, subtitle: subtitle, trailing: nil)
                .padding(.horizontal, -20).padding(.vertical, -18)
        }
        .tint(Color(red: 0.86, green: 0.96, blue: 0.62))
        .padding(.horizontal, 20).padding(.vertical, 18)
        .accessibilityLabel(title)
    }
}

/// Custom header with a round back button, used by every settings page.
struct PageScaffold<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) { content }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CircleIconButton(symbol: "chevron.left", size: 44) { dismiss() }.accessibilityLabel("Retour")
            }
        }
    }
}

/// Phone outline used to preview shields and notifications.
struct PreviewPhone<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 56, style: .continuous)
                .fill(Color(white: 0.07))
                .overlay(RoundedRectangle(cornerRadius: 56, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 8))
                .frame(width: 280, height: 380)
            Capsule().fill(Color.white.opacity(0.14)).frame(width: 90, height: 28).padding(.top, 26)
            content.frame(width: 280, height: 380)
        }
        .frame(height: 300, alignment: .top)
        .clipped()
        .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
        .frame(maxWidth: .infinity)
    }
}
