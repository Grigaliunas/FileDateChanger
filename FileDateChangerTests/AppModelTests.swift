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

import Testing
import Foundation
@testable import ReStamp

/// Tests for the `AppModel` store (list management + derived state). The model is
/// `@MainActor`, so the suite is too.
@MainActor
struct AppModelTests {

    private func tempFile(date: Date) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fdc_model_\(UUID().uuidString).txt")
        try Data("x".utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.creationDate: date, .modificationDate: date], ofItemAtPath: url.path)
        return url
    }

    @Test func addURLsDeduplicatesByPath() throws {
        let model = AppModel()
        let url = try tempFile(date: Date(timeIntervalSince1970: 1_000_000_000))
        defer { try? FileManager.default.removeItem(at: url) }

        model.addURLs([url])
        model.addURLs([url]) // same path again — must not duplicate
        #expect(model.items.count == 1)
    }

    @Test func changeCountReflectsConfig() throws {
        let model = AppModel()
        let original = Date(timeIntervalSince1970: 1_000_000_000)
        let url = try tempFile(date: original)
        defer { try? FileManager.default.removeItem(at: url) }
        model.addURLs([url])

        model.config.kind = .setSpecific
        model.config.fields = .both
        model.config.correctInconsistencies = false

        // A clearly different target date counts as a change.
        model.config.specificDate = Date(timeIntervalSince1970: 1_500_000_000)
        #expect(model.changeCount == 1)

        // Targeting the item's existing date is a no-op.
        model.config.specificDate = original
        #expect(model.changeCount == 0)
    }

    @Test func removeSelectedRemovesItemsAndClearsSelection() throws {
        let model = AppModel()
        let url = try tempFile(date: Date(timeIntervalSince1970: 1_000_000_000))
        defer { try? FileManager.default.removeItem(at: url) }
        model.addURLs([url])

        model.selection = [model.items[0].id]
        model.removeSelected()
        #expect(model.items.isEmpty)
        #expect(model.selection.isEmpty)
    }

    @Test func clearEmptiesEverything() throws {
        let model = AppModel()
        let url = try tempFile(date: Date(timeIntervalSince1970: 1_000_000_000))
        defer { try? FileManager.default.removeItem(at: url) }
        model.addURLs([url])
        model.selection = [model.items[0].id]

        model.clear()
        #expect(model.items.isEmpty)
        #expect(model.selection.isEmpty)
    }
}
