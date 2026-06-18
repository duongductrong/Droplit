//
//  WorkspaceConfigurationPane.swift
//  Compresso
//
//  Right pane: configuration sidebar (header, quality/output/watcher/capacity
//  sections, action footer with overall progress).
//

import AppKit
import SwiftUI

struct WorkspaceConfigurationPane: View {
    @ObservedObject var quickAccess: QuickAccessManager
    @Binding var isSidebarCollapsed: Bool
    @Binding var isShowingSettings: Bool

    @State private var concurrency: Int = 3
    @State private var optimizationOutputMode = OptimizationOutputSettings.optimizationOutputMode
    @State private var saveLocationEnabled = OptimizationOutputSettings.saveLocationEnabled
    @State private var outputDirectory = OptimizationOutputSettings.outputDirectory
    @State private var watchedFolderEnabled = OptimizationOutputSettings.watchedFolderEnabled
    @State private var watchedFolderURL = OptimizationOutputSettings.watchedFolderURL

    var body: some View {
        VStack(spacing: 0) {
            configurationHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    WorkspaceQualitySection(quickAccess: quickAccess)
                    outputSection
                    watcherSection
                    capacitySection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .padding(.top, 10)
            }
            .compressoScrollBounceBasedOnSize()

            actionFooter
        }
        .onAppear {
            concurrency = quickAccess.maximumConcurrentOptimizations

            // Sync settings
            optimizationOutputMode = OptimizationOutputSettings.optimizationOutputMode
            saveLocationEnabled = OptimizationOutputSettings.saveLocationEnabled
            outputDirectory = OptimizationOutputSettings.outputDirectory
            watchedFolderEnabled = OptimizationOutputSettings.watchedFolderEnabled
            watchedFolderURL = OptimizationOutputSettings.watchedFolderURL
        }
        .onChange(of: optimizationOutputMode) { newValue in
            OptimizationOutputSettings.optimizationOutputMode = newValue
        }
        .onChange(of: saveLocationEnabled) { newValue in
            OptimizationOutputSettings.saveLocationEnabled = newValue
        }
        .onChange(of: watchedFolderEnabled) { newValue in
            OptimizationOutputSettings.watchedFolderEnabled = newValue
            if newValue {
                FolderWatcherService.shared.start()
            } else {
                FolderWatcherService.shared.stop()
            }
        }
        .onChange(of: watchedFolderURL) { newValue in
            OptimizationOutputSettings.watchedFolderURL = newValue
            if watchedFolderEnabled {
                FolderWatcherService.shared.start()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            let newMode = OptimizationOutputSettings.optimizationOutputMode
            if optimizationOutputMode != newMode {
                optimizationOutputMode = newMode
            }
            let newSave = OptimizationOutputSettings.saveLocationEnabled
            if saveLocationEnabled != newSave {
                saveLocationEnabled = newSave
            }
            let newDir = OptimizationOutputSettings.outputDirectory
            if outputDirectory != newDir {
                outputDirectory = newDir
            }
            let newWatchEnabled = OptimizationOutputSettings.watchedFolderEnabled
            if watchedFolderEnabled != newWatchEnabled {
                watchedFolderEnabled = newWatchEnabled
            }
            let newWatchURL = OptimizationOutputSettings.watchedFolderURL
            if watchedFolderURL != newWatchURL {
                watchedFolderURL = newWatchURL
            }
        }
    }

    // MARK: - Header

    private var configurationHeader: some View {
        HStack {
            Text("Configuration")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 32, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Open Settings")

            Button {
                toggleSidebar()
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 32, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .help("Hide Sidebar (Cmd+Shift+B)")
        }
        .frame(height: 28)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Output Section

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            workspaceSectionLabel("Output")

            VStack(alignment: .leading, spacing: 8) {
                WorkspaceConfigRow(title: "Save Mode") {
                    Picker("", selection: $optimizationOutputMode) {
                        Text("Replace Original").tag(ConversionOutputMode.replace)
                        Text("Create New File").tag(ConversionOutputMode.duplicate)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 150, alignment: .trailing)
                }

                if optimizationOutputMode == .duplicate {
                    WorkspaceConfigRow(title: "Destination") {
                        Picker("", selection: $saveLocationEnabled) {
                            Text("Temporary Folder").tag(false)
                            Text("Custom Folder").tag(true)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 150, alignment: .trailing)
                    }

                    if saveLocationEnabled {
                        HStack(spacing: 8) {
                            Spacer()

                            Text(OptimizationOutputSettings.displayName(for: outputDirectory))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .multilineTextAlignment(.trailing)

                            Button("Choose...") {
                                chooseOutputDirectory()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.accentColor)
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    // MARK: - Watcher Section

    private var watcherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            workspaceSectionLabel("Folder Watcher")

            VStack(alignment: .leading, spacing: 8) {
                WorkspaceConfigRow(title: "Enable Folder Watch") {
                    Toggle("", isOn: $watchedFolderEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }

                if watchedFolderEnabled {
                    HStack(spacing: 8) {
                        Spacer()

                        Text(watchedFolderURL.map { OptimizationOutputSettings.displayName(for: $0) } ?? "Select Folder...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .multilineTextAlignment(.trailing)

                        Button("Choose...") {
                            chooseWatchedFolder()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Capacity Section

    private var capacitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            workspaceSectionLabel("Capacity")

            WorkspaceConfigRow(title: "Concurrent Jobs") {
                HStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { Double(concurrency) },
                            set: { newValue in
                                let rounded = Int(round(newValue))
                                if rounded != concurrency {
                                    concurrency = rounded
                                    quickAccess.setMaximumConcurrentOptimizations(rounded)
                                }
                            }
                        ),
                        in: 1...12
                    )
                    .frame(width: 100)

                    WorkspaceValueReadout(value: concurrency)
                }
            }
        }
    }

    // MARK: - Action Footer

    private var actionFooter: some View {
        VStack(spacing: 10) {
            Button {
                quickAccess.startStagedJobs()
            } label: {
                Text("Compress")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .compressoProminentButtonStyle()
            .controlSize(.large)
            .disabled(!canStartCompression)
            .help(canStartCompression ? "Start optimizing all staged files" : "No files ready to optimize")

            if hasActiveJobs {
                overallProgressView
            }
        }
        .padding(16)
    }

    private var overallProgressView: some View {
        VStack(spacing: 4) {
            ProgressView(value: overallProgress)
                .progressViewStyle(.linear)

            HStack {
                Text(progressStatusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(overallProgress * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var canStartCompression: Bool {
        quickAccess.stagedCount > 0
    }

    private var hasActiveJobs: Bool {
        quickAccess.processingCount > 0 || quickAccess.queuedCount > 0
    }

    private var overallProgress: Double {
        let total = quickAccess.items.count
        guard total > 0 else { return 0 }
        let completed = quickAccess.items.filter { $0.state == .completed || $0.state == .failed }.count
        return Double(completed) / Double(total)
    }

    private var progressStatusText: String {
        let processing = quickAccess.processingCount
        let queued = quickAccess.queuedCount
        var parts: [String] = []
        if processing > 0 { parts.append("\(processing) running") }
        if queued > 0 { parts.append("\(queued) queued") }
        return parts.isEmpty ? "Idle" : parts.joined(separator: ", ")
    }

    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Destination Folder"
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

    private func chooseWatchedFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Folder to Watch"
        panel.message = "Compresso will automatically optimize new files added here."
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if let current = watchedFolderURL {
            panel.directoryURL = current
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }
        watchedFolderURL = url
    }

    private func toggleSidebar() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isSidebarCollapsed.toggle()
        }
    }
}
