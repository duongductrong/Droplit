import SwiftUI

struct CompressoSettingsDetailView: View {
    @Binding var selection: CompressoSettingsSection
    @ObservedObject var quickAccess: QuickAccessManager

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
                quickAccess: quickAccess
            )
        case .quickAccess, .concurrency:
            QuickAccessSettingsView(quickAccess: quickAccess)
        case .output, .conversion, .storage:
            OutputSettingsView(quickAccess: quickAccess)
        case .tools:
            ToolsSettingsView()
        case .about:
            InfoSettingsView(section: selection)
        }
    }
}
