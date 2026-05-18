import AppKit
import SwiftUI

struct OutputSettingsView: View {
    @ObservedObject var quickAccess: QuickAccessManager
    @State private var saveLocationEnabled = OptimizationOutputSettings.saveLocationEnabled
    @State private var outputDirectory = OptimizationOutputSettings.outputDirectory
    @State private var temporaryRetentionDays = OptimizationOutputSettings.temporaryRetentionDays

    var body: some View {
        DroplitSettingsPage(
            title: DroplitSettingsSection.output.title,
            subtitle: "Choose where optimized files are saved and how temporary results are retained."
        ) {
            DroplitSettingsGroup(
                "Storage",
                description: "Pick a permanent folder or let Droplit manage temporary outputs."
            ) {
                DroplitSettingsControlRow(
                    title: "Save Location",
                    subtitle: saveLocationEnabled ? "Keep optimized files in a selected folder" : "Use app-managed temporary storage"
                ) {
                    Toggle("", isOn: saveLocationBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                DroplitSettingsDivider()
                DroplitSettingsControlRow(
                    title: saveLocationEnabled ? "Destination Folder" : "Temporary Storage",
                    subtitle: destinationDescription
                ) {
                    if saveLocationEnabled {
                        Button("Choose...") {
                            chooseOutputDirectory()
                        }
                    } else {
                        Text("Managed by Droplit")
                            .foregroundStyle(.secondary)
                    }
                }

                if !saveLocationEnabled {
                    DroplitSettingsDivider()
                    DroplitSettingsControlRow(
                        title: "Delete After",
                        subtitle: retentionText
                    ) {
                        retentionStepper
                    }
                }
            }

            DroplitSettingsGroup(
                "Conversion",
                description: "Control whether a format conversion replaces the source or creates a second file."
            ) {
                DroplitSettingsControlRow(
                    title: "On Conversion",
                    subtitle: quickAccess.conversionOutputMode.displayName
                ) {
                    DroplitSettingsMenuPicker(selection: $quickAccess.conversionOutputMode) {
                        ForEach(ConversionOutputMode.allCases) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                }
            }
        }
        .onAppear {
            refreshState()
        }
    }

    private var saveLocationBinding: Binding<Bool> {
        Binding(
            get: { saveLocationEnabled },
            set: { newValue in
                saveLocationEnabled = newValue
                OptimizationOutputSettings.saveLocationEnabled = newValue
                if !newValue {
                    OptimizationTemporaryFileStore.cleanupExpiredOutputsInBackground(retentionDays: temporaryRetentionDays)
                }
            }
        )
    }

    private var retentionBinding: Binding<Int> {
        Binding(
            get: { temporaryRetentionDays },
            set: { newValue in
                let clamped = OptimizationOutputSettings.clampTemporaryRetentionDays(newValue)
                temporaryRetentionDays = clamped
                OptimizationOutputSettings.temporaryRetentionDays = clamped
                OptimizationTemporaryFileStore.cleanupExpiredOutputsInBackground(retentionDays: clamped)
            }
        )
    }

    private var destinationName: String {
        if saveLocationEnabled {
            return OptimizationOutputSettings.displayName(for: outputDirectory)
        }
        return "Temporary Storage"
    }

    private var destinationPath: String {
        if saveLocationEnabled {
            return outputDirectory.path
        }
        return OptimizationTemporaryFileStore.outputDirectory.path
    }

    private var destinationDescription: String {
        "\(destinationName)\n\(destinationPath)"
    }

    private var retentionText: String {
        temporaryRetentionDays == 1 ? "1 day" : "\(temporaryRetentionDays) days"
    }

    private var retentionStepper: some View {
        HStack(spacing: 10) {
            Text(retentionText)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 62, alignment: .trailing)

            Stepper(
                "",
                value: retentionBinding,
                in: OptimizationOutputSettings.allowedTemporaryRetentionDays
            )
            .labelsHidden()
        }
    }

    private func refreshState() {
        saveLocationEnabled = OptimizationOutputSettings.saveLocationEnabled
        outputDirectory = OptimizationOutputSettings.outputDirectory
        temporaryRetentionDays = OptimizationOutputSettings.temporaryRetentionDays
    }

    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Output Folder"
        panel.message = "Optimized files will be saved here."
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = outputDirectory

        guard panel.runModal() == .OK, let url = panel.url else { return }
        OptimizationOutputSettings.outputDirectory = url
        outputDirectory = url
    }
}
