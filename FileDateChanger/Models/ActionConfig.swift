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

/// The kind of date operation to perform.
enum DateActionKind: String, CaseIterable, Identifiable {
    case setSpecific = "Set to a specific date"
    case shift = "Add / remove time"
    case copyCreationToModification = "Copy creation → modification"
    case copyModificationToCreation = "Copy modification → creation"
    case liftFromFile = "Lift dates from another file"
    case removeDates = "Remove dates (show as -----)"

    var id: String { rawValue }

    /// Whether the "which dates" picker is meaningful for this action.
    var usesFieldSelection: Bool {
        switch self {
        case .setSpecific, .shift, .liftFromFile, .removeDates: return true
        case .copyCreationToModification, .copyModificationToCreation: return false
        }
    }
}

/// Which of the two dates an action should affect.
enum DateFieldSelection: String, CaseIterable, Identifiable {
    case both = "Creation & Modification"
    case creation = "Creation only"
    case modification = "Modification only"

    var id: String { rawValue }
    var affectsCreation: Bool { self == .both || self == .creation }
    var affectsModification: Bool { self == .both || self == .modification }
}

enum ShiftDirection: String, CaseIterable, Identifiable {
    case add = "Add"
    case subtract = "Subtract"
    var id: String { rawValue }
}

/// All settings that drive how planned changes are computed.
struct ActionConfig {
    var kind: DateActionKind = .setSpecific
    var fields: DateFieldSelection = .both

    // setSpecific
    var specificDate: Date = Date()

    // shift
    var shiftDirection: ShiftDirection = .add
    var shiftDays: Int = 0
    var shiftHours: Int = 0
    var shiftMinutes: Int = 0
    var shiftSeconds: Int = 0

    /// Signed number of seconds to apply for a shift action.
    var shiftInterval: TimeInterval {
        let magnitude = shiftDays * 86_400 + shiftHours * 3_600 + shiftMinutes * 60 + shiftSeconds
        return TimeInterval(shiftDirection == .add ? magnitude : -magnitude)
    }

    // liftFromFile
    var liftSourceURL: URL?
    var liftCreation: Date?
    var liftModification: Date?

    // options
    var correctInconsistencies: Bool = true
    var includeSubfolderContents: Bool = false
}
