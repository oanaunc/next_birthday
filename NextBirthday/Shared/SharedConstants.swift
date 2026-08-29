import Foundation

/// Values shared between the app and the widget extension.
///
/// IMPORTANT: `appGroupID` must match the App Group capability enabled on BOTH
/// targets in Xcode. If you change your team / bundle prefix, change it here too.
enum SharedConstants {
    static let appGroupID = "group.com.nextbirthday.app"
    static let snapshotFilename = "widget-snapshot.json"
    static let deepLinkScheme = "nextbirthday"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Container URL for the App Group. Falls back to the process's own
    /// documents directory so the app still runs if the group isn't configured.
    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return url
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var snapshotURL: URL {
        containerURL.appendingPathComponent(snapshotFilename)
    }
}
