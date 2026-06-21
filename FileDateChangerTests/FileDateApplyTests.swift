import Testing
import Foundation
@testable import FileDateChanger

/// Integration tests that exercise `FileDateService.apply` against real files on
/// disk, then read the dates back to confirm the write actually took effect.
struct FileDateApplyTests {

    let ref = Date(timeIntervalSince1970: 1_000_000_000)        // 2001-09-09
    let now = Date(timeIntervalSince1970: 2_000_000_000)        // 2033-05-18

    /// Compare at whole-second granularity — on-disk dates carry sub-second noise.
    private func sameSecond(_ a: Date?, _ b: Date?) -> Bool {
        guard let a, let b else { return a == nil && b == nil }
        return Int(a.timeIntervalSince1970) == Int(b.timeIntervalSince1970)
    }

    /// Creates a fresh temp file (or directory) seeded with known dates and
    /// returns its URL. The caller is responsible for cleanup.
    private func makeTempItem(creation: Date, modification: Date, directory: Bool = false) throws -> URL {
        let fm = FileManager.default
        let url = fm.temporaryDirectory
            .appendingPathComponent("fdc_apply_\(UUID().uuidString)")
        if directory {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        } else {
            try "seed".write(to: url, atomically: true, encoding: .utf8)
        }
        try fm.setAttributes([.creationDate: creation, .modificationDate: modification],
                             ofItemAtPath: url.path)
        return url
    }

    // MARK: - Tests

    @Test func applySetsBothDatesOnDisk() throws {
        let fm = FileManager.default
        let url = try makeTempItem(creation: now, modification: now)
        defer { try? fm.removeItem(at: url) }

        var config = ActionConfig()
        config.kind = .setSpecific
        config.fields = .both
        config.specificDate = ref
        config.correctInconsistencies = false

        let item = FileItem(url: url)
        let change = FileDateService.plannedChange(for: item, config: config, now: now)
        try FileDateService.apply(change)

        let result = FileDateService.readDates(at: url)
        #expect(sameSecond(result.creation, ref))
        #expect(sameSecond(result.modification, ref))
    }

    @Test func applyOnlyWritesChangedField() throws {
        let fm = FileManager.default
        let originalCreation = ref
        let originalModification = ref.addingTimeInterval(3_600)
        let url = try makeTempItem(creation: originalCreation, modification: originalModification)
        defer { try? fm.removeItem(at: url) }

        // Only the modification date should change.
        var config = ActionConfig()
        config.kind = .setSpecific
        config.fields = .modification
        config.specificDate = ref.addingTimeInterval(7_200)
        config.correctInconsistencies = false

        let item = FileItem(url: url)
        let change = FileDateService.plannedChange(for: item, config: config, now: now)
        #expect(change.creationChanged == false)
        #expect(change.modificationChanged == true)

        try FileDateService.apply(change)

        let result = FileDateService.readDates(at: url)
        #expect(sameSecond(result.creation, originalCreation))           // untouched
        #expect(sameSecond(result.modification, ref.addingTimeInterval(7_200)))
    }

    @Test func applyShiftRoundTripsThroughDisk() throws {
        let fm = FileManager.default
        let url = try makeTempItem(creation: ref, modification: ref)
        defer { try? fm.removeItem(at: url) }

        var config = ActionConfig()
        config.kind = .shift
        config.fields = .both
        config.shiftDirection = .subtract
        config.shiftDays = 2
        config.correctInconsistencies = false

        let item = FileItem(url: url)
        let change = FileDateService.plannedChange(for: item, config: config, now: now)
        try FileDateService.apply(change)

        let expected = ref.addingTimeInterval(-2 * 86_400)
        let result = FileDateService.readDates(at: url)
        #expect(sameSecond(result.creation, expected))
        #expect(sameSecond(result.modification, expected))
    }

    @Test func applyCopyCreationToModificationOnDisk() throws {
        let fm = FileManager.default
        let url = try makeTempItem(creation: ref, modification: now)
        defer { try? fm.removeItem(at: url) }

        var config = ActionConfig()
        config.kind = .copyCreationToModification
        config.correctInconsistencies = false

        let item = FileItem(url: url)
        let change = FileDateService.plannedChange(for: item, config: config, now: now)
        try FileDateService.apply(change)

        let result = FileDateService.readDates(at: url)
        #expect(sameSecond(result.creation, ref))
        #expect(sameSecond(result.modification, ref))
    }

    @Test func applyWithCorrectionClampsFutureDateOnDisk() throws {
        let fm = FileManager.default
        let url = try makeTempItem(creation: ref, modification: ref)
        defer { try? fm.removeItem(at: url) }

        var config = ActionConfig()
        config.kind = .setSpecific
        config.fields = .both
        config.specificDate = now.addingTimeInterval(100_000) // future relative to `now`
        config.correctInconsistencies = true

        let item = FileItem(url: url)
        let change = FileDateService.plannedChange(for: item, config: config, now: now)
        try FileDateService.apply(change)

        let result = FileDateService.readDates(at: url)
        #expect(sameSecond(result.creation, now))
        #expect(sameSecond(result.modification, now))
    }

    @Test func applyNoChangeLeavesFileUntouched() throws {
        let fm = FileManager.default
        let url = try makeTempItem(creation: ref, modification: ref)
        defer { try? fm.removeItem(at: url) }

        // specificDate equals existing dates → nothing should change.
        var config = ActionConfig()
        config.kind = .setSpecific
        config.fields = .both
        config.specificDate = ref
        config.correctInconsistencies = false

        let item = FileItem(url: url)
        let change = FileDateService.plannedChange(for: item, config: config, now: now)
        #expect(change.hasChanges == false)

        try FileDateService.apply(change) // no-op, must not throw

        let result = FileDateService.readDates(at: url)
        #expect(sameSecond(result.creation, ref))
        #expect(sameSecond(result.modification, ref))
    }

    @Test func applyWorksOnDirectories() throws {
        let fm = FileManager.default
        let url = try makeTempItem(creation: now, modification: now, directory: true)
        defer { try? fm.removeItem(at: url) }

        var config = ActionConfig()
        config.kind = .setSpecific
        config.fields = .both
        config.specificDate = ref
        config.correctInconsistencies = false

        let item = FileItem(url: url)
        #expect(item.isDirectory == true)
        let change = FileDateService.plannedChange(for: item, config: config, now: now)
        try FileDateService.apply(change)

        let result = FileDateService.readDates(at: url)
        #expect(sameSecond(result.creation, ref))
        #expect(sameSecond(result.modification, ref))
    }

    @Test func applyRemoveDatesWritesNoDateSentinelOnDisk() throws {
        let fm = FileManager.default
        let url = try makeTempItem(creation: now, modification: now)
        defer { try? fm.removeItem(at: url) }

        var config = ActionConfig()
        config.kind = .removeDates
        config.fields = .both

        let item = FileItem(url: url)
        let change = FileDateService.plannedChange(for: item, config: config, now: now)
        try FileDateService.apply(change)

        let result = FileDateService.readDates(at: url)
        #expect(FileDateService.isNoDate(result.creation))
        #expect(FileDateService.isNoDate(result.modification))
    }

    @Test func applyToMissingFileThrowsCannotWrite() throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("fdc_missing_\(UUID().uuidString)")

        // Build a change by hand referencing a file that does not exist.
        let item = FileItem(url: missing, creationDate: now, modificationDate: now, isDirectory: false)
        let change = PlannedChange(item: item, newCreation: ref, newModification: ref)
        #expect(change.hasChanges == true)

        #expect(throws: FileDateError.self) {
            try FileDateService.apply(change)
        }
    }
}
