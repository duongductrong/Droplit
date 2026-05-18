import SwiftUI

struct ToolsSettingsView: View {
    @State private var toolRefreshID = UUID()
    @State private var isInstallingTools = false
    @State private var toolBootstrapMessage: String?

    var body: some View {
        DroplitSettingsPage(
            title: DroplitSettingsSection.tools.title,
            subtitle: "Check local optimizer binaries and install missing Homebrew packages when available."
        ) {
            DroplitSettingsGroup(
                "Status",
                description: "Droplit uses local command-line tools for each optimization format."
            ) {
                DroplitSettingsControlRow(
                    title: "Optimizer Status",
                    subtitle: toolBootstrapMessage ?? toolStatusText
                ) {
                    toolBootstrapControl
                }
            }

            DroplitSettingsGroup(
                "Installed Tools",
                description: "Availability is checked against the current machine, not a bundled copy."
            ) {
                ForEach(Array(OptimizationTool.catalog.enumerated()), id: \.element.id) { index, tool in
                    toolRow(tool)
                    if index < OptimizationTool.catalog.count - 1 {
                        DroplitSettingsDivider()
                    }
                }
            }
            .id(toolRefreshID)
        }
    }

    @ViewBuilder
    private var toolBootstrapControl: some View {
        if isInstallingTools {
            ProgressView()
                .controlSize(.small)
        } else if missingTools.isEmpty {
            Image(systemName: "checkmark.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.green)
                .help("All tools ready")
        } else {
            Button("Install") {
                Task {
                    await installMissingTools()
                }
            }
            .disabled(!HomebrewBootstrapService.isHomebrewAvailable)
            .help(HomebrewBootstrapService.isHomebrewAvailable ? "Install missing tools" : "Homebrew not found")
        }
    }

    private func toolRow(_ tool: OptimizationTool) -> some View {
        DroplitSettingsAlignedRow(
            title: tool.name,
            subtitle: tool.role
        ) {
            Text(tool.isAvailable ? "Ready" : "Missing")
                .foregroundStyle(tool.isAvailable ? .secondary : .tertiary)
        }
    }

    private var missingTools: [OptimizationTool] {
        HomebrewBootstrapService.missingTools()
    }

    private var toolStatusText: String {
        let count = missingTools.count
        if isInstallingTools {
            return "Installing missing tools"
        } else if count == 0 {
            return "All optimizer tools ready"
        } else if !HomebrewBootstrapService.isHomebrewAvailable {
            return "\(count) missing; Homebrew not found"
        } else {
            return "\(count) missing"
        }
    }

    @MainActor
    private func installMissingTools() async {
        let missingBeforeInstall = missingTools
        guard !missingBeforeInstall.isEmpty else {
            toolBootstrapMessage = "All optimizer tools ready"
            toolRefreshID = UUID()
            return
        }

        isInstallingTools = true
        toolBootstrapMessage = "Installing \(missingBeforeInstall.count) missing tools"
        defer {
            isInstallingTools = false
            toolRefreshID = UUID()
        }

        do {
            let result = try await HomebrewBootstrapService.installMissingTools()
            if result.installedEverything {
                toolBootstrapMessage = result.requestedPackages.isEmpty
                    ? "All optimizer tools ready"
                    : "Installed \(result.requestedPackages.joined(separator: ", "))"
            } else {
                toolBootstrapMessage = "Still missing \(toolNames(result.stillMissingTools))"
            }
        } catch {
            toolBootstrapMessage = shortToolMessage(error.localizedDescription)
        }
    }

    private func toolNames(_ tools: [OptimizationTool]) -> String {
        tools.map(\.name).joined(separator: ", ")
    }

    private func shortToolMessage(_ message: String) -> String {
        let firstLine = message
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? message
        return String(firstLine.prefix(140))
    }
}
