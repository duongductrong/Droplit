import SwiftUI

private enum CompressoSettingsMetrics {
    static let pageSpacing: CGFloat = 24
    static let pageHeaderSpacing: CGFloat = 6
    static let pageHorizontalPadding: CGFloat = 32
    static let pageTopPadding: CGFloat = 48
    static let pageBottomPadding: CGFloat = 22
    static let pageHeaderLift: CGFloat = 10
    static let labelColumnWidth: CGFloat = 260
    static let rowSpacing: CGFloat = 20
    static let rowVerticalPadding: CGFloat = 12
    static let groupContentPadding: CGFloat = 16
    static let groupContentTitlePadding: CGFloat = 8
    static let trailingColumnWidth: CGFloat = 180
    static let pickerWidth: CGFloat = 180
    static let switchScale: CGFloat = 0.82
    static let switchWidth: CGFloat = 42
    static let switchHeight: CGFloat = 22
}

struct CompressoSettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    let showsHeader: Bool
    private let content: Content

    init(
        title: String,
        subtitle: String,
        showsHeader: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsHeader = showsHeader
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CompressoSettingsMetrics.pageSpacing) {
                if showsHeader {
                    VStack(alignment: .leading, spacing: CompressoSettingsMetrics.pageHeaderSpacing) {
                        Text(title)
                            .font(.title.weight(.semibold))

                        Text(subtitle)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, -CompressoSettingsMetrics.pageHeaderLift)
                }

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CompressoSettingsMetrics.pageHorizontalPadding)
            .padding(.top, showsHeader ? CompressoSettingsMetrics.pageTopPadding : 20)
            .padding(.bottom, CompressoSettingsMetrics.pageBottomPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea(.container, edges: .top)
    }
}

struct CompressoSettingsGroup<Content: View>: View {
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
            .padding(.horizontal, CompressoSettingsMetrics.groupContentPadding)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                // if let description {
                //     Text(description)
                //         .font(.callout)
                //         .foregroundColor(.secondary)
                //         .fixedSize(horizontal: false, vertical: true)
                // }
            }
            .padding(.bottom, CompressoSettingsMetrics.groupContentTitlePadding)
        }
    }
}

struct CompressoSettingsControlRow<Trailing: View>: View {
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
        CompressoSettingsAlignedRow(
            title: title,
            subtitle: subtitle
        ) {
            trailing
        }
    }
}

struct CompressoSettingsValueRow: View {
    let title: String
    let subtitle: String?
    let value: String

    var body: some View {
        CompressoSettingsAlignedRow(
            title: title,
            subtitle: subtitle
        ) {
            Text(value)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
                .truncationMode(.middle)
                .compressoTextSelectionEnabled()
        }
    }
}

struct CompressoSettingsMenuPicker<SelectionValue: Hashable, Content: View>: View {
    private let selection: Binding<SelectionValue>
    private let width: CGFloat
    private let content: Content

    init(
        selection: Binding<SelectionValue>,
        width: CGFloat = CompressoSettingsMetrics.pickerWidth,
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

struct CompressoSettingsSwitch: View {
    let title: String
    @Binding private var isOn: Bool
    @State private var isHovering = false

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                isOn.toggle()
            }
        }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOn ? Color.accentColor : (isHovering ? Color.primary.opacity(0.16) : Color.primary.opacity(0.12)))
                    .frame(width: 36, height: 20)
                
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .frame(width: 16, height: 16)
                    .padding(.horizontal, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover { hovering in
            isHovering = hovering
        }
        .frame(
            width: CompressoSettingsMetrics.switchWidth,
            height: CompressoSettingsMetrics.switchHeight,
            alignment: .trailing
        )
    }
}

struct CompressoSettingsNavigationRow: View {
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
        section: CompressoSettingsSection,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = section.title
        self.subtitle = subtitle ?? section.subtitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: CompressoSettingsMetrics.rowSpacing) {
                CompressoSettingsRowLabel(title: title, subtitle: subtitle)
                    .frame(width: CompressoSettingsMetrics.labelColumnWidth, alignment: .leading)

                Spacer(minLength: 16)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary.opacity(0.72))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, CompressoSettingsMetrics.rowVerticalPadding)
    }
}

struct CompressoSettingsDivider: View {
    var body: some View {
        Divider()
    }
}

private struct CompressoSettingsRowLabel: View {
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
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.leading)
    }
}

struct CompressoSettingsAlignedRow<Trailing: View>: View {
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
        HStack(alignment: .center, spacing: CompressoSettingsMetrics.rowSpacing) {
            CompressoSettingsRowLabel(title: title, subtitle: subtitle)
                .frame(width: CompressoSettingsMetrics.labelColumnWidth, alignment: .leading)

            Spacer(minLength: 16)

            trailing
                .frame(width: CompressoSettingsMetrics.trailingColumnWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, CompressoSettingsMetrics.rowVerticalPadding)
    }
}
