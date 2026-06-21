import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showConfirm = false
    @State private var isTargetedForDrop = false

    var body: some View {
        HSplitView {
            fileList
                .frame(minWidth: 460)
            ActionPanelView()
                .frame(width: 320)
        }
        .toolbar { toolbarContent }
        .dropDestination(for: URL.self) { urls, _ in
            model.addURLs(urls)
            return true
        } isTargeted: { isTargetedForDrop = $0 }
        .overlay(dropHighlight)
        .confirmationDialog(
            "Apply changes to \(model.changeCount) item\(model.changeCount == 1 ? "" : "s")?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Perform Changes", role: .destructive) { model.performChanges() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will modify file dates on disk. This cannot be undone.")
        }
        .alert(item: $model.lastResult) { result in
            Alert(
                title: Text(result.failed == 0 ? "Done" : "Completed with errors"),
                message: Text(resultMessage(result)),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: File list

    @ViewBuilder private var fileList: some View {
        if model.items.isEmpty {
            emptyState
        } else {
            Table(model.plannedChanges, selection: $model.selection) {
                TableColumn("Name") { change in
                    Label(change.item.name,
                          systemImage: change.item.isDirectory ? "folder" : "doc")
                        .lineLimit(1)
                        .help(change.item.path)
                }
                .width(min: 140, ideal: 200)

                TableColumn("Creation") { change in
                    DateCell(current: change.item.creationDate,
                             new: change.newCreation,
                             changed: change.creationChanged)
                }
                .width(min: 150, ideal: 190)

                TableColumn("Modification") { change in
                    DateCell(current: change.item.modificationDate,
                             new: change.newModification,
                             changed: change.modificationChanged)
                }
                .width(min: 150, ideal: 190)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Drag files or folders here")
                .font(.title3)
            Text("…or use the + button in the toolbar.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder private var dropHighlight: some View {
        if isTargetedForDrop {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.accentColor, lineWidth: 3)
                .padding(4)
                .allowsHitTesting(false)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { addFiles() } label: { Label("Add", systemImage: "plus") }
                .help("Add files or folders")

            Button { model.removeSelected() } label: { Label("Remove", systemImage: "minus") }
                .disabled(model.selection.isEmpty)
                .help("Remove selected items")

            Button { model.clear() } label: { Label("Clear", systemImage: "trash") }
                .disabled(model.items.isEmpty)
                .help("Remove all items")

            Spacer()

            if model.isProcessing { ProgressView().controlSize(.small) }

            Text("\(model.changeCount) of \(model.items.count) will change")
                .foregroundStyle(.secondary)
                .font(.callout)

            Button { showConfirm = true } label: { Label("Perform Changes", systemImage: "checkmark.circle.fill") }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.changeCount == 0 || model.isProcessing)
        }
    }

    // MARK: Helpers

    private func addFiles() {
        model.presentAddPanel()
    }

    private func resultMessage(_ result: ProcessResult) -> String {
        var parts = ["\(result.succeeded) item\(result.succeeded == 1 ? "" : "s") changed."]
        if result.failed > 0 {
            parts.append("\(result.failed) failed.")
            parts.append(contentsOf: result.errors.prefix(5))
        }
        return parts.joined(separator: "\n")
    }
}

/// A single date column cell showing the current value and, if it will change,
/// the new value beneath it.
private struct DateCell: View {
    let current: Date?
    let new: Date?
    let changed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(current.displayString)
                .foregroundStyle(changed ? .secondary : .primary)
                .strikethrough(changed)
            if changed {
                Text(new.displayString)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .font(.callout)
        .monospacedDigit()
    }
}

#Preview {
    ContentView().environmentObject(AppModel())
}
