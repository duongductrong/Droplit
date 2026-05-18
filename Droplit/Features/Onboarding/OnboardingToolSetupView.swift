import AppKit
import Foundation
import SwiftUI

struct OnboardingToolSetupView: View {
    let refreshID: UUID
    let installRequestID: UUID
    @Binding var isInstallingTools: Bool
    let onRefresh: () -> Void

    @State private var isProgressHovering = false
    @State private var message: String?
    @State private var installProgress: HomebrewBootstrapProgress?

    private let progressCircleSize: CGFloat = 176
    private let progressCircleLineWidth: CGFloat = 9

    var body: some View {
        VStack(alignment: .center, spacing: 18) {
            progressInstallControl

            dependencyStatusView

            dependencyList
        }
        .frame(maxWidth: .infinity)
        .onChange(of: installRequestID) { _, _ in
            Task {
                await installMissingTools()
            }
        }
    }

    @ViewBuilder
    private var progressInstallControl: some View {
        if canInstallFromProgress {
            Button {
                Task {
                    await installMissingTools()
                }
            } label: {
                progressCircle
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Install missing dependencies")
            .accessibilityValue("\(installedToolCount) of \(totalToolCount) installed")
        } else {
            progressCircle
                .accessibilityLabel("Dependency install progress")
                .accessibilityValue(progressAccessibilityValue)
        }
    }

    private var progressCircle: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.primary.opacity(0.12),
                    style: StrokeStyle(lineWidth: progressCircleLineWidth, lineCap: .round)
                )

            Circle()
                .trim(from: 0, to: CGFloat(progressFraction))
                .stroke(
                    progressTint,
                    style: StrokeStyle(lineWidth: progressCircleLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: progressTint.opacity(isInstallingTools ? 0.22 : 0.12), radius: 6, y: 2)
                .animation(.easeInOut(duration: 0.24), value: progressFraction)

            VStack(spacing: 5) {
                Text(progressPrimaryText)
                    .font(.system(size: progressPrimaryFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(progressPrimaryColor)
                    .monospacedDigit()

                Text(progressSecondaryText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .frame(width: 118)
            }
        }
        .frame(width: progressCircleSize, height: progressCircleSize)
        .contentShape(Circle())
        .onHover { hovering in
            isProgressHovering = hovering
        }
        .help(progressHelpText)
        .onboardingPointingHandCursor(canInstallFromProgress)
        .animation(.easeInOut(duration: 0.16), value: isProgressHovering)
    }

    private var dependencyStatusView: some View {
        VStack(spacing: 8) {
            Text(message ?? statusSubtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if shouldShowHomebrewActions {
                homebrewFallbackActions
            }
        }
        .frame(maxWidth: 500)
    }

    private var homebrewFallbackActions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Link("Install Homebrew", destination: URL(string: "https://brew.sh")!)
                    .controlSize(.small)

                Button("Refresh") {
                    onRefresh()
                }
                .controlSize(.small)
            }

            Text("You can also install the linked dependencies yourself, then refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dependencyList: some View {
        Text(dependencyParagraph)
            .font(.callout)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 520)
            .padding(.top, 4)
            .id(refreshID)
    }

    private var missingTools: [OptimizationTool] {
        HomebrewBootstrapService.missingTools()
    }

    private var totalToolCount: Int {
        OptimizationTool.catalog.count
    }

    private var installedToolCount: Int {
        max(totalToolCount - missingTools.count, 0)
    }

    private var progressFraction: Double {
        let value: Double
        if isInstallingTools, let installProgress {
            value = installProgress.fractionCompleted
        } else if totalToolCount == 0 {
            value = 1
        } else {
            value = Double(installedToolCount) / Double(totalToolCount)
        }

        return min(max(value, 0), 1)
    }

    private var progressTint: Color {
        if isInstallingTools || missingTools.isEmpty {
            return .accentColor
        } else {
            return .white
        }
    }

    private var progressPrimaryText: String {
        if missingTools.isEmpty, !isInstallingTools {
            return "Done"
        } else if isInstallingTools {
            return "\(Int((progressFraction * 100).rounded()))%"
        } else {
            return "\(installedToolCount)/\(totalToolCount)"
        }
    }

    private var progressPrimaryFontSize: CGFloat {
        missingTools.isEmpty && !isInstallingTools ? 30 : 34
    }

    private var progressPrimaryColor: Color {
        .primary
    }

    private var progressSecondaryText: String {
        if isInstallingTools, let installProgress {
            return progressDetailText(installProgress)
        } else if missingTools.isEmpty {
            return "100%"
        } else if isProgressHovering, HomebrewBootstrapService.isHomebrewAvailable {
            return "Click to install"
        } else if !HomebrewBootstrapService.isHomebrewAvailable {
            return "Homebrew required"
        } else {
            return "installed"
        }
    }

    private var progressAccessibilityValue: String {
        if missingTools.isEmpty {
            return "Done, 100 percent"
        } else if isInstallingTools {
            return "\(Int((progressFraction * 100).rounded())) percent"
        } else {
            return "\(installedToolCount) of \(totalToolCount) installed"
        }
    }

    private var progressHelpText: String {
        if isInstallingTools {
            return "Installing dependencies"
        } else if missingTools.isEmpty {
            return "All dependencies installed"
        } else if HomebrewBootstrapService.isHomebrewAvailable {
            return "Click to install missing dependencies"
        } else {
            return "Install Homebrew first to install missing dependencies"
        }
    }

    private var canInstallFromProgress: Bool {
        !isInstallingTools && !missingTools.isEmpty && HomebrewBootstrapService.isHomebrewAvailable
    }

    private var shouldShowHomebrewActions: Bool {
        !isInstallingTools && !missingTools.isEmpty && !HomebrewBootstrapService.isHomebrewAvailable
    }

    private var statusSubtitle: String {
        if missingTools.isEmpty {
            return "All required dependencies are installed."
        } else if HomebrewBootstrapService.isHomebrewAvailable {
            return "Droplit will install only the missing Homebrew packages."
        } else {
            return "Homebrew is not installed, so Droplit cannot install dependencies automatically."
        }
    }

    private var dependencyParagraph: AttributedString {
        var paragraph = dependencyText("Droplit uses ")

        for (index, tool) in OptimizationTool.catalog.enumerated() {
            var link = AttributedString(tool.name)
            link.link = tool.projectURL
            link.foregroundColor = .accentColor

            paragraph += link

            if index < OptimizationTool.catalog.count - 2 {
                paragraph += dependencyText(", ")
            } else if index == OptimizationTool.catalog.count - 2 {
                paragraph += dependencyText(", and ")
            }
        }

        paragraph += dependencyText(" to optimize media locally.")
        return paragraph
    }

    private func dependencyText(_ text: String) -> AttributedString {
        var string = AttributedString(text)
        string.foregroundColor = .secondary
        return string
    }

    @MainActor
    private func installMissingTools() async {
        let missingBeforeInstall = missingTools
        guard !missingBeforeInstall.isEmpty else {
            message = "All required dependencies are installed."
            onRefresh()
            return
        }

        isInstallingTools = true
        message = "Installing \(missingBeforeInstall.count) missing dependencies"
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
                    ? "All required dependencies are installed."
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

    private func shortToolMessage(_ message: String) -> String {
        let firstLine = message
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? message
        return String(firstLine.prefix(140))
    }
}

private struct OnboardingPointingHandCursorModifier: ViewModifier {
    let isEnabled: Bool
    @State private var isActive = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering, isEnabled {
                    push()
                } else {
                    pop()
                }
            }
            .onChange(of: isEnabled) { _, newValue in
                if newValue {
                    return
                }

                pop()
            }
            .onDisappear {
                pop()
            }
    }

    private func push() {
        guard !isActive else { return }
        NSCursor.pointingHand.push()
        isActive = true
    }

    private func pop() {
        guard isActive else { return }
        NSCursor.pop()
        isActive = false
    }
}

private extension View {
    func onboardingPointingHandCursor(_ isEnabled: Bool) -> some View {
        modifier(OnboardingPointingHandCursorModifier(isEnabled: isEnabled))
    }
}
