import Foundation
import SwiftUI

struct OnboardingToolSetupView: View {
    let refreshID: UUID
    let onRefresh: () -> Void

    @State private var isInstallingTools = false
    @State private var message: String?
    @State private var installProgress: HomebrewBootstrapProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: statusSystemImage)
                            .font(.title2)
                            .foregroundStyle(statusColor)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(statusTitle)
                                .font(.headline)

                            Text(message ?? statusSubtitle)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 16)

                        statusAction
                    }

                    if isInstallingTools, let installProgress {
                        installProgressView(installProgress)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(OptimizationTool.catalog.enumerated()), id: \.element.id) { index, tool in
                        toolRow(tool)

                        if index < OptimizationTool.catalog.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
            } label: {
                Text("Required Tools")
                    .font(.headline)
                    .padding(.bottom, 6)
            }
            .id(refreshID)
        }
    }

    private func installProgressView(_ progress: HomebrewBootstrapProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: progress.fractionCompleted)

            HStack(spacing: 12) {
                Text(progressDetailText(progress))
                    .lineLimit(1)

                Spacer(minLength: 12)

                Text(progressCountText(progress))
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.leading, 44)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private var statusAction: some View {
        if isInstallingTools {
            ProgressView()
                .controlSize(.small)
        } else if missingTools.isEmpty {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .help("All tools ready")
        } else if HomebrewBootstrapService.isHomebrewAvailable {
            Button("Install Missing") {
                Task {
                    await installMissingTools()
                }
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
        } else {
            HStack(spacing: 8) {
                Link("Get Homebrew", destination: URL(string: "https://brew.sh")!)
                    .controlSize(.small)

                Button("Refresh") {
                    onRefresh()
                }
                .controlSize(.small)
            }
        }
    }

    private func toolRow(_ tool: OptimizationTool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: tool.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.body)

                Text(tool.role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Text(tool.isAvailable ? "Ready" : "Missing")
                .font(.callout)
                .foregroundStyle(tool.isAvailable ? .secondary : .tertiary)
        }
        .padding(.vertical, 10)
    }

    private var missingTools: [OptimizationTool] {
        HomebrewBootstrapService.missingTools()
    }

    private var statusSystemImage: String {
        missingTools.isEmpty ? "checkmark.seal.fill" : "wrench.and.screwdriver.fill"
    }

    private var statusColor: Color {
        missingTools.isEmpty ? .green : .secondary
    }

    private var statusTitle: String {
        if isInstallingTools {
            return "Installing tools"
        } else if missingTools.isEmpty {
            return "All optimizer tools ready"
        } else {
            return "\(missingTools.count) tools need setup"
        }
    }

    private var statusSubtitle: String {
        if missingTools.isEmpty {
            return "Droplit can optimize supported media formats on this Mac."
        } else if HomebrewBootstrapService.isHomebrewAvailable {
            return "Install the missing Homebrew packages before continuing."
        } else {
            return "Homebrew is required to install the missing optimizer packages."
        }
    }

    @MainActor
    private func installMissingTools() async {
        let missingBeforeInstall = missingTools
        guard !missingBeforeInstall.isEmpty else {
            message = "All optimizer tools ready"
            onRefresh()
            return
        }

        isInstallingTools = true
        message = "Installing \(missingBeforeInstall.count) missing tools"
        defer {
            isInstallingTools = false
            installProgress = nil
            onRefresh()
        }

        do {
            let result = try await HomebrewBootstrapService.installMissingTools { progress in
                if Thread.isMainThread {
                    installProgress = progress
                    message = progressDetailText(progress)
                } else {
                    DispatchQueue.main.sync {
                        installProgress = progress
                        message = progressDetailText(progress)
                    }
                }
            }
            if result.installedEverything {
                message = result.requestedPackages.isEmpty
                    ? "All optimizer tools ready"
                    : "Installed \(result.requestedPackages.joined(separator: ", "))"
            } else {
                message = "Still missing \(toolNames(result.stillMissingTools))"
            }
        } catch {
            message = shortToolMessage(error.localizedDescription)
        }
    }

    private func toolNames(_ tools: [OptimizationTool]) -> String {
        tools.map(\.name).joined(separator: ", ")
    }

    private func progressDetailText(_ progress: HomebrewBootstrapProgress) -> String {
        switch progress.phase {
        case .preparing:
            return "Preparing installer"
        case .installing:
            return "Installing \(progress.currentPackage ?? "package")"
        case .verifying:
            return "Verifying optimizer tools"
        case .finished:
            return "Install complete"
        }
    }

    private func progressCountText(_ progress: HomebrewBootstrapProgress) -> String {
        guard progress.totalPackageCount > 0 else { return "Complete" }

        let visibleCount = progress.phase == .installing
            ? min(progress.completedPackageCount + 1, progress.totalPackageCount)
            : progress.completedPackageCount
        return "\(visibleCount) of \(progress.totalPackageCount)"
    }

    private func shortToolMessage(_ message: String) -> String {
        let firstLine = message
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? message
        return String(firstLine.prefix(140))
    }
}
