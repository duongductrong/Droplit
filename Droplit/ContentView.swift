//
//  ContentView.swift
//  Droplit
//
//  Created by duongductrong on 17/5/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var quickAccess = QuickAccessManager.shared
    @State private var selectedSection: DroplitSettingsSection? = .about
    @State private var searchText = ""
    @State private var isImporting = false

    var body: some View {
        NavigationSplitView {
            DroplitSettingsSidebarView(
                selection: $selectedSection,
                searchText: $searchText
            )
        } detail: {
            DroplitSettingsDetailView(
                selection: selectedSectionBinding,
                quickAccess: quickAccess,
                isImporting: $isImporting
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search Settings")
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

    private var selectedSectionBinding: Binding<DroplitSettingsSection> {
        Binding(
            get: { (selectedSection ?? .about).canonicalSection },
            set: { selectedSection = $0.canonicalSection }
        )
    }
}

#Preview {
    ContentView()
}
