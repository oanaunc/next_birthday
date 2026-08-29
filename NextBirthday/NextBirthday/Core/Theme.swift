import SwiftUI

/// The pastel palette used across the app, taken from the Next Birthday artwork.
enum Theme {

    static let purple    = Color(hex: 0x7B61D8)
    static let deepInk   = Color(hex: 0x3B2E6E)
    static let lavender  = Color(hex: 0xC4B5F0)
    static let pink      = Color(hex: 0xF49AC1)
    static let rose      = Color(hex: 0xFF8FA3)
    static let peach     = Color(hex: 0xFFC49B)
    static let mint      = Color(hex: 0x9FE0D0)
    static let blue      = Color(hex: 0x7FB8F0)
    static let butter    = Color(hex: 0xFFE08A)
    static let cloud     = Color(hex: 0xF8F5FF)
    static let blush     = Color(hex: 0xFFF4F7)

    /// Accent options offered in Settings.
    static let accentOptions: [Color] = [purple, blue, pink, peach, Color(hex: 0x5AC8E8), mint]
    static let accentNames = ["Lilac", "Sky", "Blossom", "Peach", "Lagoon", "Mint"]

    static func accent(at index: Int) -> Color {
        guard accentOptions.indices.contains(index) else { return purple }
        return accentOptions[index]
    }

    /// Soft wash used behind cards when background art is switched off.
    static var fallbackGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xF3ECFF), Color(hex: 0xFDEFF6), Color(hex: 0xEAF4FF)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [lavender.opacity(0.95), pink.opacity(0.85), peach.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x8B72EE), Color(hex: 0x6EA8F5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// A deterministic pastel pair for a person without a photo.
    ///
    /// Uses a stable hash rather than `hashValue`, which is seeded per launch
    /// and would give the same person a different colour every time.
    static func avatarGradient(for seed: String) -> LinearGradient {
        let palette: [[Color]] = [
            [lavender, purple], [pink, rose], [peach, butter],
            [mint, blue], [blue, lavender], [rose, peach]
        ]
        let index = Int(stableHash(seed) % UInt64(palette.count))
        return LinearGradient(colors: palette[index], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// FNV-1a — same result on every launch and every device.
    static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
