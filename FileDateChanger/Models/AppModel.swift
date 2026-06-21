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
import SwiftUI
import AppKit

struct ProcessResult: Identifiable {
    let id = UUID()
    let succeeded: Int
    let failed: Int
    let errors: [String]
}

@MainActor
final class AppModel: ObservableObject {
    @Published var items: [FileItem] = []
    @Published var selection: Set<FileItem.ID> = []
    @Published var config = ActionConfig()
    @Published var isProcessing = false
    @Published var lastResult: ProcessResult?
    @Published var errorMessage: String?

    // MARK: Derived state

    /// Preview rows — recomputed from the current items + config on every access.
    var plannedChanges: [PlannedChange] {
        items.map { FileDateService.plannedChange(for: $0, config: config) }
    }

    var changeCount: Int { plannedChanges.filter(\.hasChanges).count }

    // MARK: List management

    func addURLs(_ urls: [URL]) {
        let expanded = FileDateService.expand(urls: urls, includeDescendants: config.includeSubfolderContents)
        let existingPaths = Set(items.map(\.path))
        var seen = existingPaths
        for url in expanded {
            let standardized = url.standardizedFileURL
            guard !seen.contains(standardized.path) else { continue }
            seen.insert(standardized.path)
            items.append(FileItem(url: standardized))
        }
    }

    /// Presents an open panel and adds the chosen files/folders. Shared by the
    /// toolbar button and the File ▸ Add Files… menu command.
    func presentAddPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Choose files or folders whose dates you want to change."
        if panel.runModal() == .OK {
            addURLs(panel.urls)
        }
    }

    func removeSelected() {
        items.removeAll { selection.contains($0.id) }
        selection.removeAll()
    }

    func clear() {
        items.removeAll()
        selection.removeAll()
    }

    func reloadDates() {
        // Rebuild as fresh instances (new ids) rather than mutating in place:
        // SwiftUI's Table caches row cells by identity, so an in-place date
        // change on the same id leaves stale values on screen.
        items = items.map { FileItem(url: $0.url) }
        selection.removeAll()
    }

    // MARK: Lift source

    func setLiftSource(_ url: URL) {
        let info = FileDateService.readDates(at: url)
        config.liftSourceURL = url
        config.liftCreation = info.creation
        config.liftModification = info.modification
    }

    // MARK: Applying

    func performChanges() {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        var succeeded = 0
        var failed = 0
        var errors: [String] = []

        for change in plannedChanges where change.hasChanges {
            do {
                try FileDateService.apply(change)
                succeeded += 1
            } catch {
                failed += 1
                errors.append(error.localizedDescription)
            }
        }

        reloadDates()
        lastResult = ProcessResult(succeeded: succeeded, failed: failed, errors: errors)
    }
}
