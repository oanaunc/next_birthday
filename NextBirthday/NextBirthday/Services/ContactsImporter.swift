import Foundation
import Contacts
import UIKit

/// One importable contact that already has a birthday saved in iOS Contacts.
struct ContactCandidate: Identifiable, Hashable {
    var id: String            // CNContact identifier
    var firstName: String
    var lastName: String
    var month: Int
    var day: Int
    var year: Int?
    var photoData: Data?

    var fullName: String {
        let name = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? "Unnamed" : name
    }

    var initials: String {
        let letters = [firstName.first, lastName.first].compactMap { $0 }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var dateLabel: String {
        BirthdayMath.fullDateLabel(month: month, day: day, year: year)
    }

    /// Used for duplicate detection when identifiers don't line up.
    var matchKey: String {
        "\(fullName.lowercased())|\(month)-\(day)"
    }
}

/// How an incoming contact relates to what's already stored.
enum ImportStatus {
    case new
    case alreadyImported          // same contact identifier, nothing to do
    case possibleDuplicate(String) // same name + date as an existing person
}

enum ContactsImporter {

    static var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    @discardableResult
    static func requestAccess() async -> Bool {
        let store = CNContactStore()
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            return false
        }
    }

    /// Every contact that has at least a day and month of birth.
    static func fetchCandidates() async -> [ContactCandidate] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: fetchCandidatesSync())
            }
        }
    }

    private static func fetchCandidatesSync() -> [ContactCandidate] {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .givenName

        var results: [ContactCandidate] = []
        let store = CNContactStore()

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                guard let birthday = contact.birthday,
                      let month = birthday.month,
                      let day = birthday.day else { return }

                let candidate = ContactCandidate(
                    id: contact.identifier,
                    firstName: contact.givenName,
                    lastName: contact.familyName,
                    month: month,
                    day: day,
                    year: birthday.year,
                    photoData: downscale(contact.thumbnailImageData)
                )
                results.append(candidate)
            }
        } catch {
            #if DEBUG
            print("Contacts fetch failed: \(error)")
            #endif
        }

        return results.sorted { lhs, rhs in
            if lhs.month != rhs.month { return lhs.month < rhs.month }
            if lhs.day != rhs.day { return lhs.day < rhs.day }
            return lhs.fullName < rhs.fullName
        }
    }

    /// Classifies each candidate against people already stored.
    static func status(for candidate: ContactCandidate, existing: [Person]) -> ImportStatus {
        if existing.contains(where: { $0.contactIdentifier == candidate.id }) {
            return .alreadyImported
        }
        if let match = existing.first(where: {
            "\($0.fullName.lowercased())|\($0.birthMonth)-\($0.birthDay)" == candidate.matchKey
        }) {
            return .possibleDuplicate(match.fullName)
        }
        return .new
    }

    static func makePerson(from candidate: ContactCandidate, relationship: String?) -> Person {
        Person(firstName: candidate.firstName,
               lastName: candidate.lastName,
               birthMonth: candidate.month,
               birthDay: candidate.day,
               birthYear: candidate.year,
               relationshipRaw: relationship,
               photoData: candidate.photoData,
               contactIdentifier: candidate.id)
    }

    /// Keeps stored photos small; contact thumbnails are already modest but
    /// this guarantees a predictable ceiling for the widget payload.
    static func downscale(_ data: Data?, maxDimension: CGFloat = 240, quality: CGFloat = 0.8) -> Data? {
        guard let data, let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image.jpegData(compressionQuality: quality) }

        let scale = maxDimension / longest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
