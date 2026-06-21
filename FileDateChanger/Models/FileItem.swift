// File Date Changer — change file creation and modification dates.
// Copyright (C) 2026 Sarunas Grigaliunas
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
