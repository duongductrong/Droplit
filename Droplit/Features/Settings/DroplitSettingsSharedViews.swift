import SwiftUI

private enum DroplitSettingsMetrics {
    static let pageSpacing: CGFloat = 24
    static let pageHeaderSpacing: CGFloat = 6
    static let pageHorizontalPadding: CGFloat = 32
    static let pageTopPadding: CGFloat = 48
    static let pageBottomPadding: CGFloat = 22
    static let pageHeaderLift: CGFloat = 10
    static let labelColumnWidth: CGFloat = 330
    static let rowSpacing: CGFloat = 24
    static let rowVerticalPadding: CGFloat = 12
    static let groupContentPadding: CGFloat = 16
    static let groupContentTitlePadding: CGFloat = 8
    static let trailingColumnMinWidth: CGFloat = 220
    static let pickerWidth: CGFloat = 220
}

struct DroplitSettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    let showsHeader: Bool
    private let content: Content

    init(
        title: String,
        subtitle: String,
        showsHeader: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsHeader = showsHeader
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DroplitSettingsMetrics.pageSpacing) {
                if showsHeader {
                    VStack(alignment: .leading, spacing: DroplitSettingsMetrics.pageHeaderSpacing) {
                        Text(title)
                            .font(.title.weight(.semibold))

                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, -DroplitSettingsMetrics.pageHeaderLift)
                }

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DroplitSettingsMetrics.pageHorizontalPadding)
            .padding(.top, DroplitSettingsMetrics.pageTopPadding)
            .padding(.bottom, DroplitSettingsMetrics.pageBottomPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea(.container, edges: .top)
    }
}

struct DroplitSettingsGroup<Content: View>: View {
    let title: String
    let description: String?
    private let content: Content

    init(
        _ title: String,
        description: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, DroplitSettingsMetrics.groupContentPadding)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                // if let description {
                //     Text(description)
                //         .font(.callout)
                //         .foregroundStyle(.secondary)
                //         .fixedSize(horizontal: false, vertical: true)
                // }
            }
            .padding(.bottom, DroplitSettingsMetrics.groupContentTitlePadding)
        }
    }
}

struct DroplitSettingsControlRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    private let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        DroplitSettingsAlignedRow(
            title: title,
            subtitle: subtitle
        ) {
            trailing
        }
    }
}

struct DroplitSettingsValueRow: View {
    let title: String
    let subtitle: String?
    let value: String

    var body: some View {
        DroplitSettingsAlignedRow(
            title: title,
            subtitle: subtitle
        ) {
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

struct DroplitSettingsMenuPicker<SelectionValue: Hashable, Content: View>: View {
    private let selection: Binding<SelectionValue>
    private let width: CGFloat
    private let content: Content

    init(
        selection: Binding<SelectionValue>,
        width: CGFloat = DroplitSettingsMetrics.pickerWidth,
        @ViewBuilder content: () -> Content
    ) {
        self.selection = selection
        self.width = width
        self.content = content()
    }

    var body: some View {
        Picker("", selection: selection) {
            content
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: width, alignment: .trailing)
    }
}

struct DroplitSettingsNavigationRow: View {
    let title: String
    let subtitle: String?
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    init(
        section: DroplitSettingsSection,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = section.title
        self.subtitle = subtitle ?? section.subtitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: DroplitSettingsMetrics.rowSpacing) {
                DroplitSettingsRowLabel(title: title, subtitle: subtitle)
                    .frame(width: DroplitSettingsMetrics.labelColumnWidth, alignment: .leading)

                Spacer(minLength: 24)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, DroplitSettingsMetrics.rowVerticalPadding)
    }
}

struct DroplitSettingsDivider: View {
    var body: some View {
        Divider()
    }
}

private struct DroplitSettingsRowLabel: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.leading)
    }
}

struct DroplitSettingsAlignedRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    private let trailing: Trailing

    init(
        title: String,
        subtitle: String?,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: DroplitSettingsMetrics.rowSpacing) {
            DroplitSettingsRowLabel(title: title, subtitle: subtitle)
                .frame(width: DroplitSettingsMetrics.labelColumnWidth, alignment: .leading)

            Spacer(minLength: 24)

            trailing
                .frame(minWidth: DroplitSettingsMetrics.trailingColumnMinWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DroplitSettingsMetrics.rowVerticalPadding)
    }
}
