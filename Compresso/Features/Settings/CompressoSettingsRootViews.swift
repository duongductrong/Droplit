//
//  CompressoSettingsRootViews.swift
//  Compresso
//
//  Settings root views extracted from ContentView for reuse in SettingsWindowManager.
//

import SwiftUI

@available(macOS 13.0, *)
struct CompressoModernSettingsRoot: View {
    @ObservedObject var quickAccess: QuickAccessManager
    @Binding var selectedSection: CompressoSettingsSection?
    let selectedDetailSection: Binding<CompressoSettingsSection>
    @Binding var searchText: String
    @Binding var isImporting: Bool
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            CompressoSettingsSidebarView(
                selection: $selectedSection,
                searchText: $searchText,
                toggleSidebar: toggleSidebar
            )
        } detail: {
            CompressoSettingsDetailView(
                selection: selectedDetailSection,
                quickAccess: quickAccess,
                isImporting: $isImporting
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .overlay(alignment: .topLeading) {
            if columnVisibility == .detailOnly {
                collapsedSidebarChromeOverlay
            }
        }
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.18)) {
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
        }
    }

    private var sidebarToggleButton: some View {
        Button(action: toggleSidebar) {
            Image(systemName: "sidebar.left")
                .compressoHierarchicalSymbolRendering()
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.borderless)
        .help("Toggle Sidebar")
    }

    private var collapsedSidebarChrome: some View {
        HStack(spacing: 16) {
            CompressoTrafficLightsView()

            sidebarToggleButton
        }
    }

    private var collapsedSidebarChromeOverlay: some View {
        GeometryReader { proxy in
            collapsedSidebarChrome
                .padding(.top, 16)
                .padding(.leading, 18)
                .offset(y: -proxy.safeAreaInsets.top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct CompressoLegacySettingsRoot: View {
    @ObservedObject var quickAccess: QuickAccessManager
    @Binding var selectedSection: CompressoSettingsSection?
    let selectedDetailSection: Binding<CompressoSettingsSection>
    @Binding var searchText: String
    @Binding var isImporting: Bool
    @State private var isSidebarVisible = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                if isSidebarVisible {
                    CompressoSettingsSidebarView(
                        selection: $selectedSection,
                        searchText: $searchText,
                        toggleSidebar: toggleSidebar
                    )
                    .frame(width: CompressoSettingsSidebarMetrics.width)

                    Divider()
                }

                CompressoSettingsDetailView(
                    selection: selectedDetailSection,
                    quickAccess: quickAccess,
                    isImporting: $isImporting
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            if !isSidebarVisible {
                collapsedSidebarChrome
                    .padding(.top, 16)
                    .padding(.leading, 18)
            }
        }
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isSidebarVisible.toggle()
        }
    }

    private var sidebarToggleButton: some View {
        Button(action: toggleSidebar) {
            Image(systemName: "sidebar.left")
                .compressoHierarchicalSymbolRendering()
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.borderless)
        .help("Toggle Sidebar")
    }

    private var collapsedSidebarChrome: some View {
        HStack(spacing: 16) {
            CompressoTrafficLightsView()

            sidebarToggleButton
        }
    }
}
