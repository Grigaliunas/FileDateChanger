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
