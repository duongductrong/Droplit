import AppKit
import SwiftUI

enum CompressoSettingsSidebarMetrics {
    static let width: CGFloat = 250
}

struct CompressoSettingsSidebarView: View {
    @Binding var selection: CompressoSettingsSection?
    @Binding var searchText: String
    let showChrome: Bool
    let toggleSidebar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            List(selection: canonicalSelection) {
                ForEach(filteredStandaloneSections) { section in
                    sidebarRow(section)
                        .tag(section as CompressoSettingsSection?)
                }

                ForEach(filteredGroups) { group in
                    Section {
                        ForEach(group.sections) { section in
                            sidebarRow(section)
                                .tag(section as CompressoSettingsSection?)
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
        .compressoSidebarColumnWidth(
            min: CompressoSettingsSidebarMetrics.width,
            ideal: CompressoSettingsSidebarMetrics.width,
            max: CompressoSettingsSidebarMetrics.width
        )
    }

    private var sidebarHeader: some View {
        VStack(spacing: 12) {
            if showChrome {
                sidebarChrome
            }

            sidebarSearchField
        }
        .padding(.top, showChrome ? 18 : 52)
        .padding(.bottom, 12)
    }

    private var sidebarChrome: some View {
        HStack(alignment: .center, spacing: 0) {
            CompressoTrafficLightsView()

            Spacer(minLength: 12)

            CompressoSidebarToggleButton(action: toggleSidebar)
        }
        .frame(height: 24)
        .padding(.leading, 18)
        .padding(.trailing, 16)
    }

    private var sidebarSearchField: some View {
        CompressoSidebarSearchField(text: $searchText)
            .padding(.horizontal, 16)
    }

    private var filteredGroups: [CompressoSettingsSidebarGroup] {
        CompressoSettingsSection.sidebarGroups
            .compactMap { group in
                let filteredSections = group.sections.filter { $0.matches(searchText) }
                guard !filteredSections.isEmpty else { return nil }
                return CompressoSettingsSidebarGroup(
                    title: group.title,
                    sections: filteredSections
                )
            }
    }

    private var filteredStandaloneSections: [CompressoSettingsSection] {
        CompressoSettingsSection.standaloneSections.filter { $0.matches(searchText) }
    }

    private var hasFilteredResults: Bool {
        !filteredStandaloneSections.isEmpty || !filteredGroups.isEmpty
    }

    @ViewBuilder
    private var emptySearchOverlay: some View {
        if !hasFilteredResults {
            CompressoEmptyStateView(
                title: "No Results",
                systemImage: "magnifyingglass",
                description: "No settings match \"\(searchText)\"."
            )
        }
    }

    private var canonicalSelection: Binding<CompressoSettingsSection?> {
        Binding(
            get: { selection?.canonicalSection },
            set: { selection = $0?.canonicalSection }
        )
    }

    private func sidebarRow(_ section: CompressoSettingsSection) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(section.iconColor)
                    .frame(width: 24, height: 24)
                
                Image(systemName: section.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(section.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

struct CompressoTrafficLightsView: View {
    @State private var isHovering = false
    @Environment(\.controlActiveState) var controlActiveState

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
        let isWindowActive = controlActiveState != .inactive
        let lightColor = isWindowActive ? color : Color.secondary.opacity(0.24)
        
        return Button(action: action) {
            Circle()
                .fill(lightColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Group {
                        if isHovering && isWindowActive {
                            Image(systemName: symbol)
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.black.opacity(0.55))
                        }
                    }
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(isWindowActive ? 0.16 : 0.08), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var activeWindow: NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow
    }
}

struct CompressoSidebarSearchField: View {
    @Binding var text: String
    @State private var isFocused = false
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 11, weight: .medium))

            TextField("Search Settings", text: $text, onEditingChanged: { editing in
                isFocused = editing
            })
            .textFieldStyle(.plain)
            .font(.system(size: 12))

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.8))
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(isFocused ? 0.08 : (isHovering ? 0.05 : 0.03)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isFocused ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 0.8)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeOut(duration: 0.12), value: isFocused)
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

struct CompressoSidebarToggleButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary.opacity(0.85))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help("Toggle Sidebar")
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}
