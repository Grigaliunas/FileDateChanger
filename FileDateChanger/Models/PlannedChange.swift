import Foundation

/// The computed result of applying an `ActionConfig` to a single `FileItem`.
/// Used both to render the preview and to perform the actual write.
struct PlannedChange: Identifiable {
    let item: FileItem
    let newCreation: Date?
    let newModification: Date?

    var id: FileItem.ID { item.id }

    var creationChanged: Bool { !datesEqual(item.creationDate, newCreation) }
    var modificationChanged: Bool { !datesEqual(item.modificationDate, newModification) }
    var hasChanges: Bool { creationChanged || modificationChanged }

    /// File dates only have ~1 second of meaningful resolution in the Finder,
    /// so compare at whole-second granularity to avoid spurious "changed" flags.
    private func datesEqual(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return Int(x.timeIntervalSince1970) == Int(y.timeIntervalSince1970)
        default: return false
        }
    }
}
