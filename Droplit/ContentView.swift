//
//  ContentView.swift
//  Droplit
//
//  Created by duongductrong on 17/5/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var quickAccess = QuickAccessManager.shared
    @State private var isImporting = false
    @State private var toolRefreshID = UUID()
    @State private var isInstallingTools = false
    @State private var toolBootstrapMessage: String?
    @State private var outputDirectory = OptimizationOutputSettings.outputDirectory

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 440, idealHeight: 520)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: QuickAccessFileKind.importableContentTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                quickAccess.ingestDroppedURLs(urls)
            }
        }
        .onAppear {
            quickAccess.start()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black)
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("Droplit")
                    .font(.system(size: 24, weight: .bold))
                Text("Media optimization queue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                quickAccess.showDropPlaceholder()
            } label: {
                Image(systemName: "rectangle.dashed.badge.record")
            }
            .buttonStyle(.bordered)
            .help("Show Quick Access")

            Button {
                isImporting = true
            } label: {
                Label("Optimize", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }

    private var content: some View {
        HStack(spacing: 0) {
            ScrollView {
                toolGrid
                    .padding(20)
            }
            .frame(width: 270)

            Divider()

            recentJobs
                .padding(20)
        }
    }

    private var toolGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Tools")
                    .font(.headline)

                Spacer()

                toolBootstrapControl
            }

            Text(toolBootstrapMessage ?? toolStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            outputConfiguration
            triggerConfiguration
            concurrencyConfiguration

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(OptimizationTool.catalog) { tool in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: tool.systemImage)
                                .foregroundStyle(tool.isAvailable ? .green : .secondary)
                            Spacer()
                            Circle()
                                .fill(tool.isAvailable ? Color.green : Color.secondary.opacity(0.35))
                                .frame(width: 8, height: 8)
                        }
                        Text(tool.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text(tool.role)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .id(toolRefreshID)

            Spacer()
        }
    }

    private var outputConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Output")
                    .font(.headline)

                Spacer()

                Button {
                    chooseOutputDirectory()
                } label: {
                    Image(systemName: "folder.badge.gearshape")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Choose output folder")
            }

            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 30, height: 30)
                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(OptimizationOutputSettings.displayName(for: outputDirectory))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Text(outputDirectory.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Picker("On conversion", selection: $quickAccess.conversionOutputMode) {
                ForEach(ConversionOutputMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private var triggerConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Quick Access")
                    .font(.headline)

                Spacer()

                Image(systemName: quickAccess.triggerInteraction.systemImage)
                    .foregroundStyle(.secondary)
            }

            Picker("Trigger", selection: $quickAccess.triggerInteraction) {
                ForEach(QuickAccessTriggerInteraction.allCases) { interaction in
                    Label(interaction.displayName, systemImage: interaction.systemImage)
                        .tag(interaction)
                }
            }
            .pickerStyle(.segmented)

            Picker("Edge", selection: quickAccessEdgeBinding) {
                ForEach(QuickAccessPanelEdge.allCases) { edge in
                    Label(edge.displayName, systemImage: edge.systemImage)
                        .tag(edge)
                }
            }
            .pickerStyle(.segmented)

            Picker("Align", selection: quickAccessAlignmentBinding) {
                ForEach(QuickAccessPanelAlignment.allCases) { alignment in
                    Label(alignment.displayName, systemImage: alignment.systemImage)
                        .tag(alignment)
                }
            }
            .pickerStyle(.segmented)

            if quickAccess.triggerInteraction == .hold {
                Stepper(
                    value: holdTriggerDurationBinding,
                    in: QuickAccessManager.allowedHoldTriggerDurationRange,
                    step: 0.1
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: "timer")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.indigo)
                            .frame(width: 30, height: 30)
                            .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hold delay")
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)

                            Text("\(quickAccess.holdTriggerDuration, specifier: "%.1f")s")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private var concurrencyConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Concurrency")
                    .font(.headline)

                Spacer()

                Text("\(quickAccess.maximumConcurrentOptimizations)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Stepper(
                value: concurrencyBinding,
                in: 1...12
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.teal)
                        .frame(width: 30, height: 30)
                        .background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(quickAccess.maximumConcurrentOptimizations) parallel jobs")
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        Text("\(quickAccess.processingCount) running · \(quickAccess.queuedCount) queued")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private var concurrencyBinding: Binding<Int> {
        Binding(
            get: { quickAccess.maximumConcurrentOptimizations },
            set: { quickAccess.setMaximumConcurrentOptimizations($0) }
        )
    }

    private var holdTriggerDurationBinding: Binding<TimeInterval> {
        Binding(
            get: { quickAccess.holdTriggerDuration },
            set: { quickAccess.setHoldTriggerDuration($0) }
        )
    }

    private var quickAccessEdgeBinding: Binding<QuickAccessPanelEdge> {
        Binding(
            get: { quickAccess.position.edge },
            set: { quickAccess.position = quickAccess.position.with(edge: $0) }
        )
    }

    private var quickAccessAlignmentBinding: Binding<QuickAccessPanelAlignment> {
        Binding(
            get: { quickAccess.position.alignment },
            set: { quickAccess.position = quickAccess.position.with(alignment: $0) }
        )
    }

    @ViewBuilder
    private var toolBootstrapControl: some View {
        if isInstallingTools {
            ProgressView()
                .controlSize(.small)
        } else if missingTools.isEmpty {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .help("All tools ready")
        } else {
            Button {
                Task {
                    await installMissingTools()
                }
            } label: {
                Label("Install", systemImage: "arrow.down.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(!HomebrewBootstrapService.isHomebrewAvailable)
            .help(HomebrewBootstrapService.isHomebrewAvailable ? "Install missing tools" : "Homebrew not found")
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

    private func shortToolMessage(_ message: String) -> String {
        let firstLine = message
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? message
        return String(firstLine.prefix(140))
    }

    private var recentJobs: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Queue")
                    .font(.headline)
                Spacer()
                Text(queueSummaryText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if quickAccess.items.isEmpty {
                ContentUnavailableView(
                    "No jobs yet",
                    systemImage: "tray",
                    description: Text("Quick Access appears from the selected drag trigger or the Optimize button.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(quickAccess.items) { item in
                            queueRow(item)
                        }
                    }
                }
            }
        }
    }

    private func queueRow(_ item: QuickAccessItem) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: item.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 58, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.sourceURL.lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(item.detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            statusBadge(for: item)

            Button {
                quickAccess.removeItem(id: item.id)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Remove")
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func statusBadge(for item: QuickAccessItem) -> some View {
        switch item.state {
        case .queued:
            Image(systemName: "clock.fill")
                .foregroundStyle(.secondary)
        case .processing:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private var queueSummaryText: String {
        let total = quickAccess.items.count
        guard total > 0 else { return "0" }
        return "\(quickAccess.processingCount)/\(total)"
    }
}

#Preview {
    ContentView()
}
