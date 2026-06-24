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

extension AppModel {
    /// DEBUG-only: populates the list with curated sample data so marketing
    /// screenshots are reproducible. Triggered by `--screenshot-seed=main|remove`
    /// on launch. Compiles to a no-op in release builds (never ships).
    func applyScreenshotSeedIfRequested() {
        #if DEBUG
        let prefix = "--screenshot-seed="
        guard let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) })
        else { return }
        let mode = String(arg.dropFirst(prefix.count))

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        func date(_ s: String) -> Date { fmt.date(from: s)! }
        func item(_ name: String, _ created: String, _ modified: String) -> FileItem {
            FileItem(url: URL(fileURLWithPath: "/Users/Sample/\(name)"),
                     creationDate: date(created), modificationDate: date(modified),
                     isDirectory: false)
        }

        switch mode {
        case "main":
            items = [
                item("Vacation Photo.jpg", "2019-07-04 14:30:00", "2019-07-04 14:30:00"),
                item("Tax Return.pdf",     "2021-04-15 09:05:00", "2021-04-15 09:05:00"),
                item("Meeting Notes.txt",  "2018-11-02 18:45:00", "2018-11-02 18:45:00"),
            ]
            config.kind = .setSpecific
            config.fields = .both
            config.specificDate = date("2026-06-21 14:53:57")
        case "remove":
            items = [
                item("Scanned Contract.pdf", "2016-03-22 11:00:00", "2016-03-22 11:00:00"),
                item("IMG_4521.jpg",         "2020-08-09 16:20:00", "2020-08-09 16:20:00"),
                item("Old Backup.zip",       "2014-12-01 19:45:00", "2014-12-01 19:45:00"),
            ]
            config.kind = .removeDates
            config.fields = .both
        default:
            return
        }

        // Force light appearance and a deterministic window size for the shot.
        DispatchQueue.main.async {
            NSApp.appearance = NSAppearance(named: .aqua)
            if let window = NSApp.windows.first {
                window.setContentSize(NSSize(width: 1100, height: 640))
                window.center()
            }
        }
        #endif
    }
}
