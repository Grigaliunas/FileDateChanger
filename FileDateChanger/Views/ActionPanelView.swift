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

struct ActionPanelView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Action") {
                Picker("Operation", selection: $model.config.kind) {
                    ForEach(DateActionKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .labelsHidden()

                if model.config.kind.usesFieldSelection {
                    Picker("Apply to", selection: $model.config.fields) {
                        ForEach(DateFieldSelection.allCases) { field in
                            Text(field.rawValue).tag(field)
                        }
                    }
                }
            }

            Section("Settings") {
                settings
            }

            Section("Options") {
                Toggle("Auto-correct inconsistent dates", isOn: $model.config.correctInconsistencies)
                    .help("Clamp future dates to now and keep modification ≥ creation.")
                Toggle("Include subfolder contents when adding", isOn: $model.config.includeSubfolderContents)
                    .help("Applies to items added after this is turned on.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: Per-action settings

    @ViewBuilder private var settings: some View {
        switch model.config.kind {
        case .setSpecific:
            DatePicker("New date",
                       selection: $model.config.specificDate,
                       displayedComponents: [.date, .hourAndMinute])

        case .shift:
            Picker("Direction", selection: $model.config.shiftDirection) {
                ForEach(ShiftDirection.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Stepper("Days: \(model.config.shiftDays)", value: $model.config.shiftDays, in: 0...100_000)
            Stepper("Hours: \(model.config.shiftHours)", value: $model.config.shiftHours, in: 0...10_000)
            Stepper("Minutes: \(model.config.shiftMinutes)", value: $model.config.shiftMinutes, in: 0...10_000)
            Stepper("Seconds: \(model.config.shiftSeconds)", value: $model.config.shiftSeconds, in: 0...10_000)

        case .copyCreationToModification:
            Text("Each file's modification date will be set to its own creation date.")
                .foregroundStyle(.secondary)

        case .copyModificationToCreation:
            Text("Each file's creation date will be set to its own modification date.")
                .foregroundStyle(.secondary)

        case .liftFromFile:
            liftSettings

        case .removeDates:
            Text("The selected dates will be removed and shown as “-----” in the Finder.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var liftSettings: some View {
        Button("Choose source file…") { chooseLiftSource() }

        if let url = model.config.liftSourceURL {
            LabeledContent("Source", value: url.lastPathComponent)
            LabeledContent("Creation", value: model.config.liftCreation.displayString)
            LabeledContent("Modification", value: model.config.liftModification.displayString)
        } else {
            Text("Pick a file to copy its dates from.")
                .foregroundStyle(.secondary)
        }
    }

    private func chooseLiftSource() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose the file whose dates you want to copy."
        if panel.runModal() == .OK, let url = panel.url {
            model.setLiftSource(url)
        }
    }
}

#Preview {
    ActionPanelView()
        .environmentObject(AppModel())
        .frame(width: 320, height: 500)
}
