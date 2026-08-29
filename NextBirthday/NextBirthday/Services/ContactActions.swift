import Foundation
import Contacts
import UIKit

/// Opens Messages, Phone, Mail or WhatsApp for a linked contact.
///
/// The app never sends anything by itself — it only opens the other app with
/// the conversation ready.
enum ContactActions {

    struct ContactChannels {
        var phoneNumbers: [String] = []
        var emails: [String] = []
        var hasAny: Bool { !phoneNumbers.isEmpty || !emails.isEmpty }
    }

    /// Reads phone numbers and emails for a linked contact, if access is granted.
    static func channels(for identifier: String?) -> ContactChannels {
        guard let identifier,
              CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            return ContactChannels()
        }
        let keys: [CNKeyDescriptor] = [
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]
        do {
            let contact = try CNContactStore().unifiedContact(withIdentifier: identifier, keysToFetch: keys)
            return ContactChannels(
                phoneNumbers: contact.phoneNumbers.map { $0.value.stringValue },
                emails: contact.emailAddresses.map { $0.value as String }
            )
        } catch {
            return ContactChannels()
        }
    }

    private static func digits(_ number: String) -> String {
        let allowed = CharacterSet(charactersIn: "+0123456789")
        return String(number.unicodeScalars.filter { allowed.contains($0) })
    }

    static func messageURL(phone: String, body: String? = nil) -> URL? {
        var components = URLComponents(string: "sms:\(digits(phone))")
        if let body {
            components?.queryItems = [URLQueryItem(name: "body", value: body)]
        }
        return components?.url
    }

    static func callURL(phone: String) -> URL? {
        URL(string: "tel:\(digits(phone))")
    }

    static func mailURL(email: String, subject: String) -> URL? {
        var components = URLComponents(string: "mailto:\(email)")
        components?.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components?.url
    }

    static func whatsAppURL(phone: String, text: String) -> URL? {
        let number = digits(phone).replacingOccurrences(of: "+", with: "")
        var components = URLComponents(string: "https://wa.me/\(number)")
        components?.queryItems = [URLQueryItem(name: "text", value: text)]
        return components?.url
    }

    static func openContactURL(identifier: String) -> URL? {
        URL(string: "contacts://")
    }

    @MainActor
    static func open(_ url: URL?) {
        guard let url, UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
