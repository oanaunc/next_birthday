import SwiftUI
import WidgetKit
import UIKit

/// Widget palette.
///
/// Every colour comes from the asset catalog with a light and a dark variant,
/// so the background and the text always flip together. Hardcoding one but not
/// the other is what made the first version unreadable in dark mode.
enum WidgetTheme {
    static let ink        = Color("WidgetInk")
    static let secondary  = Color("WidgetInkSecondary")
    static let accent     = Color("WidgetAccent")
    static let accentSoft = Color("WidgetAccentSoft")

    static var background: LinearGradient {
        LinearGradient(colors: [Color("WidgetBackground"), Color("WidgetBackgroundAlt")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Slightly warmer wash for the dedicated countdown widget.
    static var countdownBackground: LinearGradient {
        LinearGradient(colors: [Color("WidgetBackgroundAlt"), Color("WidgetBackground")],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// Avatar for widgets — photo when the snapshot carries one, else initials.
struct WidgetAvatar: View {
    let entry: SnapshotEntry
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            if let data = entry.photo, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [WidgetTheme.accentSoft, WidgetTheme.accent],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(entry.initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// One line in the medium / large "Up Next" widget.
struct WidgetPersonRow: View {
    let entry: SnapshotEntry
    var avatarSize: CGFloat = 30

    var body: some View {
        HStack(spacing: 9) {
            WidgetAvatar(entry: entry, size: avatarSize)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetTheme.ink)
                    .lineLimit(1)
                Text(entry.shortDate)
                    .font(.system(size: 10))
                    .foregroundStyle(WidgetTheme.secondary)
            }

            Spacer(minLength: 4)

            Text(entry.countdown)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(entry.daysUntil <= 1 ? WidgetTheme.accent : WidgetTheme.secondary)
        }
    }
}

/// Shown when the app has no birthdays yet.
struct WidgetEmptyState: View {
    var compact = false

    var body: some View {
        VStack(spacing: 4) {
            Text("🎂").font(.system(size: compact ? 20 : 28))
            Text("No birthdays yet")
                .font(.system(size: compact ? 10 : 12, weight: .medium))
                .foregroundStyle(WidgetTheme.ink)
                .foregroundStyle(WidgetTheme.secondary)
            if !compact {
                Text("Open Next Birthday to add one")
                    .font(.system(size: 10))
                    .foregroundStyle(WidgetTheme.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension SnapshotEntry {
    var deepLink: URL {
        URL(string: "\(SharedConstants.deepLinkScheme)://person/\(id)")
            ?? URL(string: "\(SharedConstants.deepLinkScheme)://")!
    }
}
