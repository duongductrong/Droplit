import SwiftUI

struct DroplitSettingsDetailView: View {
    @Binding var selection: DroplitSettingsSection
    @ObservedObject var quickAccess: QuickAccessManager
    @Binding var isImporting: Bool

    var body: some View {
        pageContent
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selection {
        case .general:
            GeneralSettingsView(
                selection: $selection,
                quickAccess: quickAccess,
                isImporting: $isImporting
            )
        case .quickAccess, .concurrency:
            QuickAccessSettingsView(quickAccess: quickAccess)
        case .output, .conversion, .storage:
            OutputSettingsView(quickAccess: quickAccess)
        case .tools:
            ToolsSettingsView()
        case .queue:
            QueueSettingsView(quickAccess: quickAccess, isImporting: $isImporting)
        case .about:
            InfoSettingsView(section: selection)
        }
    }
}
