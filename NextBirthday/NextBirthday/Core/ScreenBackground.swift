import SwiftUI

/// Named background artwork shipped in the asset catalog, one per screen.
enum BackgroundArt {
    case onboarding
    case upcoming
    case calendar
    case people
    case settings
    case detail
    case add
    case gifts
    case importing
}

/// Puts softened artwork behind a screen without hurting legibility.
///
/// The image is blurred, desaturated a little and covered by a translucent
/// scrim so list rows and cards keep their contrast in both colour schemes.
struct ScreenBackground: View {
    let art: BackgroundArt
    var intensity: Double = 0.35
    var blur: CGFloat = 18

    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ZStack {
            Color(colorScheme == .dark ? .systemBackground : .init(red: 0.965, green: 0.953, blue: 0.922, alpha: 1))
            if settings.showBackgroundArt {
                LinearGradient(colors: [Theme.mint.opacity(0.08), .clear, Theme.peach.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Applies the standard screen background behind this view.
    func screenBackground(_ art: BackgroundArt,
                          intensity: Double = 0.35,
                          blur: CGFloat = 18) -> some View {
        self.background(ScreenBackground(art: art, intensity: intensity, blur: blur))
    }
}

/// A frosted card, matching the mockups.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 22
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.lavender.opacity(0.25), Theme.lavender.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Theme.deepInk.opacity(0.07), radius: 18, x: 0, y: 9)
    }
}

/// Section header used on the Upcoming screen ("Today", "This Week", ...).
struct SectionHeader: View {
    let title: String
    var count: Int?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if let count {
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.ultraThinMaterial))
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }
}
