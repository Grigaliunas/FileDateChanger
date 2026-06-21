import Foundation

/// A file or folder that has been added to the list, along with its current dates.
struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var creationDate: Date?
    var modificationDate: Date?
    var isDirectory: Bool

    var name: String { url.lastPathComponent }
    var path: String { url.path }

    init(url: URL) {
        self.url = url
        let info = FileDateService.readDates(at: url)
        self.creationDate = info.creation
        self.modificationDate = info.modification
        self.isDirectory = info.isDirectory
    }

    /// Direct initializer with explicit dates (used by tests and for constructing
    /// items without reading from disk).
    init(url: URL, creationDate: Date?, modificationDate: Date?, isDirectory: Bool) {
        self.url = url
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.isDirectory = isDirectory
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
