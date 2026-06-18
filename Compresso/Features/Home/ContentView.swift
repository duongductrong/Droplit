//
//  ContentView.swift
//  Compresso
//
//  Created by duongductrong on 17/5/26.
//
//  Post-onboarding workspace: a two-pane layout (drop zone on the left,
//  configuration sidebar on the right) backed by QuickAccessManager.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var quickAccess = QuickAccessManager.shared
    @AppStorage("workspace.isSidebarCollapsed") private var isSidebarCollapsed = false
    @State private var viewStyle: CompressoWorkspaceViewStyle = .current
    @State private var isImporting = false
    @State private var isDropTargeted = false
    @State private var isShowingSettings = false

    var body: some View {
        HStack(spacing: 0) {
            WorkspaceDropZonePane(
                quickAccess: quickAccess,
                viewStyle: $viewStyle,
                isImporting: $isImporting,
                isDropTargeted: $isDropTargeted,
                isSidebarCollapsed: isSidebarCollapsed,
                toggleSidebar: toggleSidebar
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !isSidebarCollapsed {
                Rectangle()
                    .fill(Color(NSColor.separatorColor))
                    .frame(width: 1)
                    .ignoresSafeArea(.container, edges: .top)
                    .transition(.opacity)

                WorkspaceConfigurationPane(
                    quickAccess: quickAccess,
                    isSidebarCollapsed: $isSidebarCollapsed,
                    isShowingSettings: $isShowingSettings
                )
                .frame(width: 300)
                .transition(.move(edge: .trailing))
            }
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
        .sheet(isPresented: $isShowingSettings) {
            SettingsViewWrapper(quickAccess: quickAccess)
        }
        .onAppear {
            quickAccess.start()

            if OptimizationOutputSettings.watchedFolderEnabled {
                FolderWatcherService.shared.start()
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

    private func toggleSidebar() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isSidebarCollapsed.toggle()
        }
    }
}

#Preview {
    ContentView()
}
