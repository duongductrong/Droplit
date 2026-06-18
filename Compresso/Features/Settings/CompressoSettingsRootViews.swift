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
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            CompressoSettingsSidebarView(
                selection: $selectedSection,
                searchText: $searchText,
                showChrome: false,
                toggleSidebar: toggleSidebar
            )
        } detail: {
            CompressoSettingsDetailView(
                selection: selectedDetailSection,
                quickAccess: quickAccess
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .background(
            Button(action: toggleSidebar) {
                EmptyView()
            }
            .keyboardShortcut("b", modifiers: .command)
        )
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.18)) {
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
        }
    }
}

struct CompressoLegacySettingsRoot: View {
    @ObservedObject var quickAccess: QuickAccessManager
    @Binding var selectedSection: CompressoSettingsSection?
    let selectedDetailSection: Binding<CompressoSettingsSection>
    @Binding var searchText: String
    @State private var isSidebarVisible = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                if isSidebarVisible {
                    CompressoSettingsSidebarView(
                        selection: $selectedSection,
                        searchText: $searchText,
                        showChrome: false,
                        toggleSidebar: toggleSidebar
                    )
                    .frame(width: CompressoSettingsSidebarMetrics.width)

                    Divider()
                }

                CompressoSettingsDetailView(
                    selection: selectedDetailSection,
                    quickAccess: quickAccess
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            if !isSidebarVisible {
                collapsedSidebarChrome
                    .padding(.top, 16)
                    .padding(.leading, 18)
            }
        }
        .background(
            Button(action: toggleSidebar) {
                EmptyView()
            }
            .keyboardShortcut("b", modifiers: .command)
        )
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isSidebarVisible.toggle()
        }
    }

    private var sidebarToggleButton: some View {
        CompressoSidebarToggleButton(action: toggleSidebar)
    }

    private var collapsedSidebarChrome: some View {
        HStack(spacing: 16) {
            sidebarToggleButton
        }
    }
}
