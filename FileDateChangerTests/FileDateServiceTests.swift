import Testing
import Foundation
@testable import FileDateChanger

struct FileDateServiceTests {

    // A fixed reference point: 2001-09-09 01:46:40 UTC.
    let ref = Date(timeIntervalSince1970: 1_000_000_000)
    // A "now" used for inconsistency correction, comfortably after `ref`.
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func item(creation: Date?, modification: Date?, isDirectory: Bool = false) -> FileItem {
        FileItem(url: URL(fileURLWithPath: "/tmp/example"),
                 creationDate: creation,
                 modificationDate: modification,
                 isDirectory: isDirectory)
    }

    // MARK: - correct()

    @Test func correctClampsFutureDatesToNow() {
        let future = now.addingTimeInterval(10_000)
        let (c, m) = FileDateService.correct(creation: future, modification: future, now: now)
        #expect(c == now)
        #expect(m == now)
    }

    @Test func correctForcesModificationNotBeforeCreation() {
        let creation = ref
        let earlierModification = ref.addingTimeInterval(-5_000)
        let (c, m) = FileDateService.correct(creation: creation, modification: earlierModification, now: now)
        #expect(c == creation)
        #expect(m == creation) // bumped up to creation
    }

    @Test func correctLeavesValidDatesUntouched() {
        let creation = ref
        let modification = ref.addingTimeInterval(3_600)
        let (c, m) = FileDateService.correct(creation: creation, modification: modification, now: now)
        #expect(c == creation)
        #expect(m == modification)
    }

    @Test func correctHandlesNilDates() {
        let (c, m) = FileDateService.correct(creation: nil, modification: nil, now: now)
        #expect(c == nil)
        #expect(m == nil)
    }

    // MARK: - shiftInterval

    @Test func shiftIntervalIsSignedCorrectly() {
        var config = ActionConfig()
        config.shiftDays = 1
        config.shiftHours = 2
        config.shiftMinutes = 3
        config.shiftSeconds = 4
        let magnitude: TimeInterval = 86_400 + 2 * 3_600 + 3 * 60 + 4

        config.shiftDirection = .add
        #expect(config.shiftInterval == magnitude)

        config.shiftDirection = .subtract
        #expect(config.shiftInterval == -magnitude)
    }

    // MARK: - plannedChange: setSpecific

    @Test func setSpecificAffectsBothFields() {
        var config = ActionConfig()
        config.kind = .setSpecific
        config.fields = .both
        config.specificDate = ref
        config.correctInconsistencies = false

        let change = FileDateService.plannedChange(
            for: item(creation: now, modification: now), config: config, now: now)
        #expect(change.newCreation == ref)
        #expect(change.newModification == ref)
    }

    @Test func setSpecificCreationOnlyLeavesModification() {
        var config = ActionConfig()
        config.kind = .setSpecific
        config.fields = .creation
        config.specificDate = ref
        config.correctInconsistencies = false

        let original = item(creation: now, modification: now)
        let change = FileDateService.plannedChange(for: original, config: config, now: now)
        #expect(change.newCreation == ref)
        #expect(change.newModification == now)
    }

    // MARK: - plannedChange: shift

    @Test func shiftAddsIntervalToExistingDates() {
        var config = ActionConfig()
        config.kind = .shift
        config.fields = .both
        config.shiftDirection = .add
        config.shiftHours = 1
        config.correctInconsistencies = false

        let change = FileDateService.plannedChange(
            for: item(creation: ref, modification: ref), config: config, now: now)
        #expect(change.newCreation == ref.addingTimeInterval(3_600))
        #expect(change.newModification == ref.addingTimeInterval(3_600))
    }

    @Test func shiftLeavesNilDatesNil() {
        var config = ActionConfig()
        config.kind = .shift
        config.shiftHours = 1

        let change = FileDateService.plannedChange(
            for: item(creation: nil, modification: nil), config: config, now: now)
        #expect(change.newCreation == nil)
        #expect(change.newModification == nil)
    }

    // MARK: - plannedChange: copy

    @Test func copyCreationToModification() {
        var config = ActionConfig()
        config.kind = .copyCreationToModification
        config.correctInconsistencies = false

        let change = FileDateService.plannedChange(
            for: item(creation: ref, modification: now), config: config, now: now)
        #expect(change.newCreation == ref)
        #expect(change.newModification == ref)
    }

    @Test func copyModificationToCreation() {
        var config = ActionConfig()
        config.kind = .copyModificationToCreation
        config.correctInconsistencies = false

        let change = FileDateService.plannedChange(
            for: item(creation: ref, modification: now), config: config, now: now)
        #expect(change.newCreation == now)
        #expect(change.newModification == now)
    }

    // MARK: - plannedChange: lift

    @Test func liftFromFileUsesSourceDates() {
        var config = ActionConfig()
        config.kind = .liftFromFile
        config.fields = .both
        config.liftCreation = ref
        config.liftModification = ref.addingTimeInterval(60)
        config.correctInconsistencies = false

        let change = FileDateService.plannedChange(
            for: item(creation: now, modification: now), config: config, now: now)
        #expect(change.newCreation == ref)
        #expect(change.newModification == ref.addingTimeInterval(60))
    }

    // MARK: - plannedChange: removeDates

    @Test func removeDatesSetsNoDateSentinelOnBoth() {
        var config = ActionConfig()
        config.kind = .removeDates
        config.fields = .both

        let change = FileDateService.plannedChange(
            for: item(creation: ref, modification: now), config: config, now: now)
        #expect(FileDateService.isNoDate(change.newCreation))
        #expect(FileDateService.isNoDate(change.newModification))
    }

    @Test func removeDatesCreationOnlyLeavesModification() {
        var config = ActionConfig()
        config.kind = .removeDates
        config.fields = .creation

        let change = FileDateService.plannedChange(
            for: item(creation: ref, modification: now), config: config, now: now)
        #expect(FileDateService.isNoDate(change.newCreation))
        #expect(change.newModification == now)
    }

    @Test func removeDatesIgnoresInconsistencyCorrection() {
        // Removing only the modification date must NOT be clamped back up to the
        // (later) creation date, even with auto-correction enabled.
        var config = ActionConfig()
        config.kind = .removeDates
        config.fields = .modification
        config.correctInconsistencies = true

        let change = FileDateService.plannedChange(
            for: item(creation: ref, modification: now), config: config, now: now)
        #expect(change.newCreation == ref)
        #expect(FileDateService.isNoDate(change.newModification))
    }

    // MARK: - correction integrated into planning

    @Test func planningAppliesCorrectionWhenEnabled() {
        var config = ActionConfig()
        config.kind = .setSpecific
        config.fields = .both
        config.specificDate = now.addingTimeInterval(10_000) // in the future
        config.correctInconsistencies = true

        let change = FileDateService.plannedChange(
            for: item(creation: ref, modification: ref), config: config, now: now)
        #expect(change.newCreation == now)
        #expect(change.newModification == now)
    }

    // MARK: - PlannedChange change detection

    @Test func subSecondDifferenceIsNotAChange() {
        var config = ActionConfig()
        config.kind = .setSpecific
        config.fields = .both
        config.specificDate = ref.addingTimeInterval(0.4) // sub-second noise
        config.correctInconsistencies = false

        let change = FileDateService.plannedChange(
            for: item(creation: ref, modification: ref), config: config, now: now)
        #expect(change.creationChanged == false)
        #expect(change.modificationChanged == false)
        #expect(change.hasChanges == false)
    }

    @Test func wholeSecondDifferenceIsAChange() {
        var config = ActionConfig()
        config.kind = .setSpecific
        config.fields = .both
        config.specificDate = ref.addingTimeInterval(5)
        config.correctInconsistencies = false

        let change = FileDateService.plannedChange(
            for: item(creation: ref, modification: ref), config: config, now: now)
        #expect(change.hasChanges == true)
    }

    // MARK: - expand()

    @Test func expandRecursesIntoFoldersWhenRequested() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("fdc_expand_\(UUID().uuidString)")
        let sub = root.appendingPathComponent("sub")
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        let file = sub.appendingPathComponent("a.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(at: root) }

        let withRecursion = FileDateService.expand(urls: [root], includeDescendants: true)
        #expect(withRecursion.contains { $0.lastPathComponent == "a.txt" })
        #expect(withRecursion.count >= 3) // root, sub, a.txt

        let withoutRecursion = FileDateService.expand(urls: [root], includeDescendants: false)
        #expect(withoutRecursion == [root])
    }
}
