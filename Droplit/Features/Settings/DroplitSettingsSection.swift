import Foundation

struct DroplitSettingsSidebarGroup: Identifiable {
    let title: String
    let sections: [DroplitSettingsSection]

    var id: String { title }
}

enum DroplitSettingsSection: String, CaseIterable, Identifiable {
    case general
    case quickAccess
    case output
    case conversion
    case tools
    case queue
    case concurrency
    case storage
    case appearance
    case privacy
    case advanced
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "About"
        case .quickAccess: "Quick Access"
        case .output: "Output & Storage"
        case .conversion: "Conversion"
        case .tools: "Optimizer Tools"
        case .queue: "Media Optimization"
        case .concurrency: "Concurrency"
        case .storage: "Storage"
        case .appearance: "Appearance"
        case .privacy: "Privacy"
        case .advanced: "Advanced Settings"
        case .about: "About"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "App details and shortcuts"
        case .quickAccess: "Trigger, placement, and concurrency"
        case .output: "Save location, storage, and conversion output"
        case .conversion: "How converted files are written"
        case .tools: "Optimizer availability and setup"
        case .queue: "Current optimization jobs and imports"
        case .concurrency: "Parallel optimization limits"
        case .storage: "Temporary output retention"
        case .appearance: "Window, material, and control style"
        case .privacy: "Local processing and file handling"
        case .advanced: "Defaults, recovery, and power-user details"
        case .about: "Version, build, and app details"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape.fill"
        case .quickAccess: "sparkles.rectangle.stack.fill"
        case .output: "folder.fill"
        case .conversion: "arrow.triangle.2.circlepath"
        case .tools: "wrench.and.screwdriver.fill"
        case .queue: "tray.full.fill"
        case .concurrency: "bolt.horizontal.circle.fill"
        case .storage: "internaldrive.fill"
        case .appearance: "circle.lefthalf.filled"
        case .privacy: "hand.raised.fill"
        case .advanced: "slider.horizontal.3"
        case .about: "info.circle.fill"
        }
    }

    var searchText: String {
        "\(title) \(subtitle) \(searchKeywords) \(rawValue)"
    }

    var canonicalSection: DroplitSettingsSection {
        switch self {
        case .conversion, .storage:
            .output
        case .concurrency:
            .quickAccess
        default:
            self
        }
    }

    private var searchKeywords: String {
        switch self {
        case .quickAccess:
            "concurrency jobs hold shake alignment edge"
        case .output:
            "conversion storage retention folder temporary destination"
        default:
            ""
        }
    }

    static let sidebarGroups: [DroplitSettingsSidebarGroup] = [
        DroplitSettingsSidebarGroup(
            title: "Settings",
            sections: [.quickAccess, .output, .appearance, .privacy, .advanced]
        ),
        DroplitSettingsSidebarGroup(
            title: "Tool",
            sections: [.tools, .queue]
        )
    ]

    static let standaloneSections: [DroplitSettingsSection] = [.about]

    func matches(_ query: String) -> Bool {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else { return true }
        return searchText.localizedCaseInsensitiveContains(cleanedQuery)
    }
}
