import SwiftUI
import UIKit

/// Call / Message / WhatsApp / copy a birthday message.
/// Next Birthday never sends anything itself — it just opens the other app.
struct QuickActionsSheet: View {
    let person: Person

    @Environment(\.dismiss) private var dismiss
    @State private var channels = ContactActions.ContactChannels()
    @State private var copied = false

    private var suggestedMessage: String {
        NotificationScheduler.birthdayMessage(for: person)
    }

    private var primaryPhone: String? { channels.phoneNumbers.first }
    private var primaryEmail: String? { channels.emails.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    AvatarView(name: person.fullName,
                               initials: person.initials,
                               photoData: person.photoData,
                               size: 76)
                        .padding(.top, 8)

                    VStack(spacing: 3) {
                        Text(person.fullName).font(.headline)
                        Text(person.countdownLabel)
                            .font(.subheadline)
                            .foregroundStyle(Theme.purple)
                    }

                    if channels.hasAny {
                        HStack(spacing: 12) {
                            if let phone = primaryPhone {
                                ActionButton(icon: "message.fill", title: "Message", tint: Theme.blue) {
                                    ContactActions.open(
                                        ContactActions.messageURL(phone: phone, body: suggestedMessage))
                                }
                                ActionButton(icon: "phone.fill", title: "Call", tint: Theme.mint) {
                                    ContactActions.open(ContactActions.callURL(phone: phone))
                                }
                                ActionButton(icon: "bubble.left.and.bubble.right.fill",
                                             title: "WhatsApp", tint: Color(hex: 0x25D366)) {
                                    ContactActions.open(
                                        ContactActions.whatsAppURL(phone: phone, text: suggestedMessage))
                                }
                            }
                            if let email = primaryEmail, primaryPhone == nil {
                                ActionButton(icon: "envelope.fill", title: "Email", tint: Theme.peach) {
                                    ContactActions.open(
                                        ContactActions.mailURL(email: email, subject: "Happy birthday!"))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        Text("Link this person to a contact to message or call them from here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Suggested message")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(suggestedMessage)
                                .font(.subheadline)
                            Button {
                                UIPasteboard.general.string = suggestedMessage
                                copied = true
                            } label: {
                                Label(copied ? "Copied" : "Copy Message",
                                      systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal, 20)

                    ShareLink(item: shareText) {
                        Label("Share Birthday", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.bottom, 20)
                }
            }
            .screenBackground(.detail, intensity: 0.28)
            .navigationTitle("Quick Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                channels = ContactActions.channels(for: person.contactIdentifier)
            }
        }
    }

    private var shareText: String {
        "\(person.fullName)'s birthday — \(person.fullDateLabel)"
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(tint))
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
