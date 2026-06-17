//
//  ContentView.swift
//  Compresso
//
//  Created by duongductrong on 17/5/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - View Style Setting

enum CompressoWorkspaceViewStyle: String, CaseIterable, Identifiable {
    case list
    case grid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .list: "List"
        case .grid: "Grid"
        }
    }

    var systemImage: String {
        switch self {
        case .list: "list.bullet"
        case .grid: "square.grid.2x2"
        }
    }

    private static let key = "workspace.viewStyle"

    static var current: CompressoWorkspaceViewStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key) else {
                return .list
            }
            if raw == "stack" {
                return .grid
            }
            return CompressoWorkspaceViewStyle(rawValue: raw) ?? .list
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}

// MARK: - Window Metrics

private enum CompressoWorkspaceMetrics {
    static let minWidth: CGFloat = 800
    static let idealWidth: CGFloat = 920
    static let minHeight: CGFloat = 560
    static let idealHeight: CGFloat = 680
    static let sidebarWidth: CGFloat = 280
}

// MARK: - ContentView (Workspace)

struct ContentView: View {
    @ObservedObject private var quickAccess = QuickAccessManager.shared
    @State private var viewStyle: CompressoWorkspaceViewStyle = .current
    @State private var imageQuality: Double = Double(OptimizationQualitySettings.imageQuality)
    @State private var videoQuality: Double = Double(OptimizationQualitySettings.videoQuality)
    @State private var concurrency: Int = 3
    @State private var isImporting = false
    @State private var isDropTargeted = false

    @State private var optimizationOutputMode = OptimizationOutputSettings.optimizationOutputMode
    @State private var saveLocationEnabled = OptimizationOutputSettings.saveLocationEnabled
    @State private var outputDirectory = OptimizationOutputSettings.outputDirectory
    @State private var watchedFolderEnabled = OptimizationOutputSettings.watchedFolderEnabled
    @State private var watchedFolderURL = OptimizationOutputSettings.watchedFolderURL

    var body: some View {
        HStack(spacing: 0) {
            dropZonePane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(width: 1)
                .ignoresSafeArea(.container, edges: .top)

            configurationPane
                .frame(width: 300)
        }
        .ignoresSafeArea(.container, edges: .top)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: QuickAccessFileKind.importableContentTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                quickAccess.stageDroppedURLs(urls)
            }
        }
        .onAppear {
            quickAccess.start()
            concurrency = quickAccess.maximumConcurrentOptimizations
            
            // Sync settings
            optimizationOutputMode = OptimizationOutputSettings.optimizationOutputMode
            saveLocationEnabled = OptimizationOutputSettings.saveLocationEnabled
            outputDirectory = OptimizationOutputSettings.outputDirectory
            watchedFolderEnabled = OptimizationOutputSettings.watchedFolderEnabled
            watchedFolderURL = OptimizationOutputSettings.watchedFolderURL
            
            if watchedFolderEnabled {
                FolderWatcherService.shared.start()
            }
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
        .background(WorkspaceWindowConfigurator())
        .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow).ignoresSafeArea())
        .frame(
            minWidth: CompressoWorkspaceMetrics.minWidth,
            idealWidth: CompressoWorkspaceMetrics.idealWidth,
            maxWidth: .infinity,
            minHeight: CompressoWorkspaceMetrics.minHeight,
            idealHeight: CompressoWorkspaceMetrics.idealHeight,
            maxHeight: .infinity
        )
    }

    // MARK: - Left Pane: Drop Zone / File List

    private var dropZonePane: some View {
        ZStack {
            QuickAccessDropReceiverView(isTargeted: $isDropTargeted, movesWindowOnMouseDown: false) { urls in
                quickAccess.stageDroppedURLs(urls)
            }

            if quickAccess.items.isEmpty {
                emptyDropZone
            } else {
                populatedFileList
            }
        }
        .overlay(
            floatingViewStylePicker
                .padding(.top, 12)
                .padding(.trailing, 16),
            alignment: .topTrailing
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var floatingViewStylePicker: some View {
        HStack(spacing: 2) {
            ForEach(CompressoWorkspaceViewStyle.allCases) { style in
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        viewStyle = style
                        CompressoWorkspaceViewStyle.current = style
                    }
                } label: {
                    Image(systemName: style.systemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(viewStyle == style ? .primary : .secondary.opacity(0.85))
                        .frame(width: 26, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(viewStyle == style ? Color.primary.opacity(0.12) : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(style.displayName + " View")
            }
        }
        .padding(3)
        .background(
            VisualEffectView(material: .titlebar, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1.5)
    }

    private var emptyDropZone: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 5])
                    )
                    .foregroundColor(isDropTargeted ? .accentColor : .secondary.opacity(0.4))

                VStack(spacing: 14) {
                    Image(systemName: isDropTargeted ? "tray.full.fill" : "tray.and.arrow.down.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(isDropTargeted ? .accentColor : .secondary)
                        .scaleEffect(isDropTargeted ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDropTargeted)

                    VStack(spacing: 4) {
                        Text(isDropTargeted ? "Release to optimize" : "Drop files here")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isDropTargeted ? .primary : .secondary)

                        Text("Images, videos, GIFs, and PDFs")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: 280, maxHeight: 200)

            Button {
                isImporting = true
            } label: {
                Label("Choose Files", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.accentColor)

            Spacer()
        }
        .padding(24)
    }

    private var populatedFileList: some View {
        VStack(spacing: 0) {
            if viewStyle == .list {
                fileListView
            } else {
                fileGridView
            }

            compactDropHeader
        }
    }

    private var compactDropHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Info label (no icon)
                Text(isDropTargeted ? "Release to add files" : "\(quickAccess.items.count) " + (quickAccess.items.count == 1 ? "file" : "files") + " in queue")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isDropTargeted ? .accentColor : .secondary)

                Spacer()

                // "Add Files" text-only button
                Button {
                    isImporting = true
                } label: {
                    Text("Add Files")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help("Add files")

                // "Clear All" text-only button
                if !quickAccess.items.isEmpty {
                    Button {
                        quickAccess.removeAllItems()
                    } label: {
                        Text("Clear All")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4.5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.red.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Remove all files")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                isDropTargeted
                    ? Color.accentColor.opacity(0.05)
                    : Color.clear
            )
        }
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
    }

    private var fileListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(quickAccess.items) { item in
                    WorkspaceFileRow(
                        item: item,
                        onRemove: { quickAccess.removeItem(id: item.id) },
                        onOpen: { quickAccess.openItem(for: item.id) },
                        onReveal: { quickAccess.revealOutput(for: item.id) }
                    )
                }
            }
            .padding(.top, 48)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .compressoScrollBounceBasedOnSize()
    }

    private var fileGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 14)], spacing: 14) {
                ForEach(quickAccess.items) { item in
                    WorkspaceFileCard(
                        item: item,
                        onRemove: { quickAccess.removeItem(id: item.id) },
                        onOpen: { quickAccess.openItem(for: item.id) },
                        onReveal: { quickAccess.revealOutput(for: item.id) }
                    )
                }
            }
            .padding(.top, 48)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .compressoScrollBounceBasedOnSize()
    }

    // MARK: - Right Pane: Configuration Sidebar

    private var configurationPane: some View {
        VStack(spacing: 0) {
            configurationHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    qualitySection
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
    }


    private var configurationHeader: some View {
        HStack {
            Text("Configuration")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button {
                SettingsWindowManager.shared.showSettings(quickAccess: quickAccess)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.borderless)
            .help("Open Settings")
        }
        .frame(height: 28)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Configuration Sections

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Quality")

            VStack(alignment: .leading, spacing: 8) {
                configRow(title: "Image Quality") {
                    HStack(spacing: 8) {
                        Slider(
                            value: $imageQuality,
                            in: 10...100
                        )
                        .frame(width: 100)
                        .onChange(of: imageQuality) { newValue in
                            let rounded = round(newValue / 5.0) * 5.0
                            if rounded != imageQuality {
                                imageQuality = rounded
                            }
                            OptimizationQualitySettings.imageQuality = Int(rounded)
                        }

                        Text("\(Int(imageQuality))")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 28, alignment: .trailing)
                    }
                }

                configRow(title: "Video CRF") {
                    HStack(spacing: 8) {
                        Slider(
                            value: $videoQuality,
                            in: 18...51
                        )
                        .frame(width: 100)
                        .onChange(of: videoQuality) { newValue in
                            let rounded = round(newValue)
                            if rounded != videoQuality {
                                videoQuality = rounded
                            }
                            OptimizationQualitySettings.videoQuality = Int(rounded)
                        }

                        Text("\(Int(videoQuality))")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Output")

            VStack(alignment: .leading, spacing: 8) {
                configRow(title: "Save Mode") {
                    Picker("", selection: $optimizationOutputMode) {
                        Text("Replace Original").tag(ConversionOutputMode.replace)
                        Text("Create New File").tag(ConversionOutputMode.duplicate)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 150, alignment: .trailing)
                }

                if optimizationOutputMode == .duplicate {
                    configRow(title: "Destination") {
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

    private var watcherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Folder Watcher")

            VStack(alignment: .leading, spacing: 8) {
                configRow(title: "Enable Folder Watch") {
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

    private var capacitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Capacity")

            configRow(title: "Concurrent Jobs") {
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

                    Text("\(concurrency)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Action Footer

    private var actionFooter: some View {
        VStack(spacing: 10) {
            Button {
                compressAction()
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

    private func compressAction() {
        quickAccess.startStagedJobs()
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

    // MARK: - Layout Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
    }

    private func configRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            content()
        }
        .frame(minHeight: 22)
    }
}

// MARK: - File Row (List Style)

private struct WorkspaceFileRow: View {
    let item: QuickAccessItem
    let onRemove: () -> Void
    let onOpen: () -> Void
    let onReveal: () -> Void

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var isHoveringRemove = false

    var body: some View {
        ZStack {
            Image(nsImage: item.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 100)
                .scaleEffect(isHovering ? 1.03 : 1.0)
                .blur(radius: isHovering ? 1.5 : 0)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    // Top-left file type badge (text badge instead of icon, avoiding icon overuse)
                    Text(item.sourceURL.pathExtension.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.black.opacity(0.6))
                        )

                    Spacer()

                    // Top-right close/remove button on hover
                    if isHovering {
                        Button {
                            onRemove()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 18, height: 18)
                                .background(
                                    Circle()
                                        .fill(isHoveringRemove ? Color.black.opacity(0.8) : Color.black.opacity(0.5))
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringRemove = $0 }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 8) {
                        Text(item.detailLine)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(detailLineColor)
                            .lineLimit(1)
                        
                        if isHovering && item.outputURL != nil {
                            Spacer()
                            
                            Button("Reveal in Finder") {
                                onReveal()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.accentColor)
                        }
                    }

                    if item.state == .processing {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.25))
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: proxy.size.width * CGFloat(item.progress ?? 0.1))
                            }
                        }
                        .frame(height: 3)
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55), .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isHovering ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.12), lineWidth: isHovering ? 1.5 : 1)
        )
        .shadow(color: Color.black.opacity(isHovering ? 0.16 : 0.08), radius: isHovering ? 8 : 4, x: 0, y: isHovering ? 4 : 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isHovering = hovering
            }
        }
        .onTapGesture(count: 2) {
            onOpen()
        }
        .contextMenu {
            Button("Open") { onOpen() }
            if item.outputURL != nil {
                Button("Reveal in Finder") { onReveal() }
            }
            Divider()
            Button("Remove") { onRemove() }
        }
        .gesture(externalDragGesture)
    }

    private var detailLineColor: Color {
        switch item.state {
        case .completed:
            return .green
        case .failed:
            return .red
        case .queued:
            return .orange
        default:
            return .white.opacity(0.85)
        }
    }

    private var externalDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { _ in
                guard !isDragging else { return }
                guard let dragURL = item.preferredExternalDragURL else { return }
                isDragging = true
                _ = QuickAccessExternalDragSession.begin(
                    fileURL: dragURL,
                    thumbnail: item.thumbnail,
                    onEnded: { _ in
                        isDragging = false
                    }
                )
            }
    }
}

// MARK: - File Card (Stack Style)

private struct WorkspaceFileCard: View {
    let item: QuickAccessItem
    let onRemove: () -> Void
    let onOpen: () -> Void
    let onReveal: () -> Void

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var isHoveringRemove = false

    var body: some View {
        ZStack {
            Image(nsImage: item.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 140)
                .scaleEffect(isHovering ? 1.04 : 1.0)
                .blur(radius: isHovering ? 1.5 : 0)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    // Top-left file type badge (text badge instead of icon, avoiding icon overuse)
                    Text(item.sourceURL.pathExtension.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.black.opacity(0.6))
                        )

                    Spacer()

                    // Top-right close/remove button on hover
                    if isHovering {
                        Button {
                            onRemove()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 18, height: 18)
                                .background(
                                    Circle()
                                        .fill(isHoveringRemove ? Color.black.opacity(0.8) : Color.black.opacity(0.5))
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringRemove = $0 }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(item.detailLine)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(detailLineColor)
                        .lineLimit(1)

                    if item.state == .processing {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.25))
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: proxy.size.width * CGFloat(item.progress ?? 0.1))
                            }
                        }
                        .frame(height: 3)
                        .padding(.top, 2)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55), .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isHovering ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.12), lineWidth: isHovering ? 1.5 : 1)
        )
        .shadow(color: Color.black.opacity(isHovering ? 0.16 : 0.08), radius: isHovering ? 8 : 4, x: 0, y: isHovering ? 4 : 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isHovering = hovering
            }
        }
        .onTapGesture(count: 2) {
            onOpen()
        }
        .contextMenu {
            Button("Open") { onOpen() }
            if item.outputURL != nil {
                Button("Reveal in Finder") { onReveal() }
            }
            Divider()
            Button("Remove") { onRemove() }
        }
        .gesture(externalDragGesture)
    }

    private var detailLineColor: Color {
        switch item.state {
        case .completed:
            return .green
        case .failed:
            return .red
        case .queued:
            return .orange
        default:
            return .white.opacity(0.85)
        }
    }

    private var externalDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { _ in
                guard !isDragging else { return }
                guard let dragURL = item.preferredExternalDragURL else { return }
                isDragging = true
                _ = QuickAccessExternalDragSession.begin(
                    fileURL: dragURL,
                    thumbnail: item.thumbnail,
                    onEnded: { _ in
                        isDragging = false
                    }
                )
            }
    }
}

// MARK: - Window Configurator

private struct WorkspaceWindowConfigurator: NSViewRepresentable {
    final class Coordinator {
        var configuredWindow: NSWindow?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        configureWindow(for: view, context: context)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWindow(for: nsView, context: context)
    }

    private func configureWindow(for view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }

            window.minSize = NSSize(
                width: CompressoWorkspaceMetrics.minWidth,
                height: CompressoWorkspaceMetrics.minHeight
            )

            // Transparency & Vibrancy configuration
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)

            // Force traffic lights to be visible
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false

            guard context.coordinator.configuredWindow !== window else { return }

            context.coordinator.configuredWindow = window
            window.setContentSize(
                NSSize(
                    width: CompressoWorkspaceMetrics.idealWidth,
                    height: CompressoWorkspaceMetrics.idealHeight
                )
            )
            window.center()
        }
    }
}

#Preview {
    ContentView()
}
