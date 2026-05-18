import SwiftUI

struct DroplitSettingsSidebarView: View {
    @Binding var selection: DroplitSettingsSection?
    @Binding var searchText: String

    var body: some View {
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
        .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 280)
        .overlay {
            if !hasFilteredResults {
                ContentUnavailableView.search(text: searchText)
            }
        }
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

    private var canonicalSelection: Binding<DroplitSettingsSection?> {
        Binding(
            get: { selection?.canonicalSection },
            set: { selection = $0?.canonicalSection }
        )
    }

    private func sidebarRow(_ section: DroplitSettingsSection) -> some View {
        HStack(spacing: 10) {
            Image(systemName: section.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .lineLimit(1)

                Text(section.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
