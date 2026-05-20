import AppKit
import SwiftUI

enum DroplitSettingsSidebarMetrics {
    static let width: CGFloat = 250
}

struct DroplitSettingsSidebarView: View {
    @Binding var selection: DroplitSettingsSection?
    @Binding var searchText: String
    let toggleSidebar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            List(selection: canonicalSelection) {
                ForEach(filteredStandaloneSections) { section in
                    sidebarRow(section)
                        .tag(section as DroplitSettingsSection?)
                }

                ForEach(filteredGroups) { group in
                    Section {
                        ForEach(group.sections) { section in
                            sidebarRow(section)
                                .tag(section as DroplitSettingsSection?)
                        }
                    } header: {
                        Text(group.title)
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                    }
                }
            }
            .listStyle(.sidebar)
            .overlay(emptySearchOverlay)
        }
        .ignoresSafeArea(.container, edges: .top)
        .droplitSidebarColumnWidth(
            min: DroplitSettingsSidebarMetrics.width,
            ideal: DroplitSettingsSidebarMetrics.width,
            max: DroplitSettingsSidebarMetrics.width
        )
    }

    private var sidebarHeader: some View {
        VStack(spacing: 12) {
            sidebarChrome

            sidebarSearchField
        }
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var sidebarChrome: some View {
        HStack(alignment: .center, spacing: 0) {
            DroplitTrafficLightsView()

            Spacer(minLength: 12)

            Button(action: toggleSidebar) {
                Image(systemName: "sidebar.left")
                    .droplitHierarchicalSymbolRendering()
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("Toggle Sidebar")
        }
        .frame(height: 24)
        .padding(.leading, 18)
        .padding(.trailing, 16)
    }

    private var sidebarSearchField: some View {
        DroplitSidebarSearchField(text: $searchText)
            .frame(height: 38)
            .padding(.horizontal, 16)
    }

    private var filteredGroups: [DroplitSettingsSidebarGroup] {
        DroplitSettingsSection.sidebarGroups
            .compactMap { group in
                let filteredSections = group.sections.filter { $0.matches(searchText) }
                guard !filteredSections.isEmpty else { return nil }
                return DroplitSettingsSidebarGroup(
                    title: group.title,
                    sections: filteredSections
                )
            }
    }

    private var filteredStandaloneSections: [DroplitSettingsSection] {
        DroplitSettingsSection.standaloneSections.filter { $0.matches(searchText) }
    }

    private var hasFilteredResults: Bool {
        !filteredStandaloneSections.isEmpty || !filteredGroups.isEmpty
    }

    @ViewBuilder
    private var emptySearchOverlay: some View {
        if !hasFilteredResults {
            DroplitEmptyStateView(
                title: "No Results",
                systemImage: "magnifyingglass",
                description: "No settings match \"\(searchText)\"."
            )
        }
    }

    private var canonicalSelection: Binding<DroplitSettingsSection?> {
        Binding(
            get: { selection?.canonicalSection },
            set: { selection = $0?.canonicalSection }
        )
    }

    private func sidebarRow(_ section: DroplitSettingsSection) -> some View {
        HStack(spacing: 10) {
            Image(systemName: section.systemImage)
                .foregroundColor(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .lineLimit(1)

                Text(section.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

struct DroplitTrafficLightsView: View {
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            trafficLight(color: Color(red: 1.0, green: 0.32, blue: 0.31), symbol: "xmark") {
                activeWindow?.performClose(nil)
            }

            trafficLight(color: Color(red: 1.0, green: 0.78, blue: 0.20), symbol: "minus") {
                activeWindow?.miniaturize(nil)
            }

            trafficLight(color: Color(red: 0.20, green: 0.80, blue: 0.32), symbol: "plus") {
                activeWindow?.zoom(nil)
            }
        }
        .onHover { isHovering = $0 }
        .help("Window Controls")
    }

    private func trafficLight(color: Color, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 13, height: 13)
                .overlay(
                    Group {
                        if isHovering {
                            Image(systemName: symbol)
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.black.opacity(0.55))
                        }
                    }
                )
                .overlay(
                    Circle()
                        .stroke(.black.opacity(0.16), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var activeWindow: NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow
    }
}

private struct DroplitSidebarSearchField: NSViewRepresentable {
    @Binding var text: String
    private let searchFieldHeight: CGFloat = 34

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let searchField = NSSearchField()
        searchField.delegate = context.coordinator
        searchField.placeholderString = "Search Settings"
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.controlSize = .large
        searchField.bezelStyle = .roundedBezel
        searchField.focusRingType = .default
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchField.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(searchField)
        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            searchField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: searchFieldHeight)
        ])

        context.coordinator.searchField = searchField
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let searchField = context.coordinator.searchField else {
            return
        }

        if searchField.stringValue != text {
            searchField.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        private let text: Binding<String>
        weak var searchField: NSSearchField?

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else {
                return
            }
            text.wrappedValue = searchField.stringValue
        }
    }
}
