import SwiftUI

@main
struct FileDateChangerApp: App {
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
