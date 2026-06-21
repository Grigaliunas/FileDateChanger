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

import SwiftUI

@main
struct ReStampApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 820, minHeight: 480)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Files…") { model.presentAddPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

extension Date {
    /// Shared medium-date / medium-time formatter for the UI.
    static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    var displayString: String { Self.displayFormatter.string(from: self) }
}

extension Optional where Wrapped == Date {
    /// Finder shows files with no date as "-----"; so do we for a missing date
    /// and for the `noDate` sentinel written by the "Remove dates" action.
    var displayString: String {
        guard let date = self, !FileDateService.isNoDate(date) else { return "-----" }
        return date.displayString
    }
}
