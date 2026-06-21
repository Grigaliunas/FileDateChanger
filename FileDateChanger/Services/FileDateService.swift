import Foundation

enum FileDateError: LocalizedError {
    case cannotWrite(URL, underlying: Error)

    var errorDescription: String? {
        switch self {
        case let .cannotWrite(url, underlying):
            return "Could not change dates for “\(url.lastPathComponent)”: \(underlying.localizedDescription)"
        }
    }
}

/// Stateless helpers for reading, planning and writing file dates.
///
/// The planning logic (`plannedChange`) is a pure function so the preview shown
/// in the UI is computed by exactly the same code that performs the write.
enum FileDateService {

    /// HFS+ epoch zero — 1904-01-01 00:00:00 GMT. Writing this value makes the
    /// Finder display the date as "-----" (i.e. "no date"). It is the sentinel
    /// used by the "Remove dates" action.
    static let noDate = Date(timeIntervalSince1970: -2_082_844_800)

    /// True if a date is the `noDate` sentinel (compared at whole-second
    /// granularity, like every other date comparison in the app).
    static func isNoDate(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Int(date.timeIntervalSince1970) == Int(noDate.timeIntervalSince1970)
    }

    // MARK: Reading

    static func readDates(at url: URL) -> (creation: Date?, modification: Date?, isDirectory: Bool) {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        let exists = fm.fileExists(atPath: url.path, isDirectory: &isDir)
        guard exists else { return (nil, nil, false) }
        let attrs = try? fm.attributesOfItem(atPath: url.path)
        return (attrs?[.creationDate] as? Date,
                attrs?[.modificationDate] as? Date,
                isDir.boolValue)
    }

    /// Expands a list of dropped/selected URLs, optionally recursing into folders.
    static func expand(urls: [URL], includeDescendants: Bool) -> [URL] {
        let fm = FileManager.default
        var result: [URL] = []
        for url in urls {
            result.append(url)
            guard includeDescendants else { continue }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { continue }
            if let enumerator = fm.enumerator(at: url,
                                              includingPropertiesForKeys: nil,
                                              options: [.skipsHiddenFiles]) {
                for case let child as URL in enumerator {
                    result.append(child)
                }
            }
        }
        return result
    }

    // MARK: Planning (pure)

    static func plannedChange(for item: FileItem, config: ActionConfig, now: Date = Date()) -> PlannedChange {
        var creation = item.creationDate
        var modification = item.modificationDate

        switch config.kind {
        case .setSpecific:
            if config.fields.affectsCreation { creation = config.specificDate }
            if config.fields.affectsModification { modification = config.specificDate }

        case .shift:
            let interval = config.shiftInterval
            if config.fields.affectsCreation, let c = item.creationDate {
                creation = c.addingTimeInterval(interval)
            }
            if config.fields.affectsModification, let m = item.modificationDate {
                modification = m.addingTimeInterval(interval)
            }

        case .copyCreationToModification:
            modification = item.creationDate

        case .copyModificationToCreation:
            creation = item.modificationDate

        case .liftFromFile:
            if config.fields.affectsCreation { creation = config.liftCreation }
            if config.fields.affectsModification { modification = config.liftModification }

        case .removeDates:
            if config.fields.affectsCreation { creation = noDate }
            if config.fields.affectsModification { modification = noDate }
        }

        // Removing dates intentionally writes the 1904 sentinel; running the
        // consistency rules would clamp it (e.g. push a "removed" modification
        // back up to creation), so skip correction for that action.
        if config.correctInconsistencies && config.kind != .removeDates {
            (creation, modification) = correct(creation: creation, modification: modification, now: now)
        }

        return PlannedChange(item: item, newCreation: creation, newModification: modification)
    }

    /// Applies macOS's "common sense" rules: dates can't be in the future and a
    /// file cannot be modified before it was created.
    static func correct(creation: Date?, modification: Date?, now: Date) -> (Date?, Date?) {
        var c = creation
        var m = modification
        if let cc = c, cc > now { c = now }
        if let mm = m, mm > now { m = now }
        if let cc = c, let mm = m, mm < cc { m = cc }
        return (c, m)
    }

    // MARK: Writing

    static func apply(_ change: PlannedChange) throws {
        var attrs: [FileAttributeKey: Any] = [:]
        if change.creationChanged, let c = change.newCreation { attrs[.creationDate] = c }
        if change.modificationChanged, let m = change.newModification { attrs[.modificationDate] = m }
        guard !attrs.isEmpty else { return }
        do {
            try FileManager.default.setAttributes(attrs, ofItemAtPath: change.item.url.path)
        } catch {
            throw FileDateError.cannotWrite(change.item.url, underlying: error)
        }
    }
}
