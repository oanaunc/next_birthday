import SwiftUI
import UIKit

/// Circular avatar: photo when available, otherwise pastel initials.
struct AvatarView: View {
    let name: String
    let initials: String
    var photoData: Data?
    var size: CGFloat = 48
    var showsRing: Bool = false
    var ringColor: Color = Theme.pink

    var body: some View {
        ZStack {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Theme.avatarGradient(for: name)
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(showsRing ? ringColor : Color.white.opacity(0.7),
                            lineWidth: showsRing ? 2.5 : 1.5)
        )
        .shadow(color: Theme.deepInk.opacity(0.12), radius: 4, y: 2)
    }
}

/// Small pill showing a relationship label.
struct RelationshipTag: View {
    let raw: String?

    var body: some View {
        if let raw, !raw.isEmpty {
            HStack(spacing: 3) {
                Image(systemName: Relationship.symbol(for: raw))
                    .font(.system(size: 8, weight: .bold))
                Text(raw)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(Relationship.tint(for: raw))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Relationship.tint(for: raw).opacity(0.16))
            )
        }
    }
}
