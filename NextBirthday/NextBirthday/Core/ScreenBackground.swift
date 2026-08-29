import SwiftUI

/// Named background artwork shipped in the asset catalog, one per screen.
enum BackgroundArt: String {
    case onboarding = "BGOnboarding"
    case upcoming   = "BGUpcoming"
    case calendar   = "BGCalendar"
    case people     = "BGPeople"
    case settings   = "BGSettings"
    case detail     = "BGDetail"
    case add        = "BGAdd"
    case gifts      = "BGGifts"
    case importing  = "BGImport"
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
            Color(colorScheme == .dark ? .systemBackground : .white)

            Theme.fallbackGradient
                .opacity(colorScheme == .dark ? 0.22 : 0.9)

            Circle()
                .fill(Theme.lavender.opacity(colorScheme == .dark ? 0.14 : 0.28))
                .frame(width: 390, height: 390)
                .blur(radius: 70)
                .offset(x: -150, y: -290)

            Circle()
                .fill(Theme.pink.opacity(colorScheme == .dark ? 0.10 : 0.2))
                .frame(width: 340, height: 340)
                .blur(radius: 80)
                .offset(x: 170, y: 260)

            if settings.showBackgroundArt {
                Image(art.rawValue)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: blur, opaque: true)
                    .opacity(colorScheme == .dark ? intensity * 0.34 : intensity * 0.72)
                    .saturation(0.72)
            }

            // Scrim: keeps text readable no matter how busy the art is.
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.black.opacity(0.72), Color.black.opacity(0.86)]
                    : [Color.white.opacity(0.42), Theme.blush.opacity(0.68)],
                startPoint: .top,
                endPoint: .bottom
            )
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
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.85), Theme.lavender.opacity(0.28)],
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
