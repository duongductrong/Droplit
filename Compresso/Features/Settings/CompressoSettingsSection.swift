import Foundation
import SwiftUI

struct CompressoSettingsSidebarGroup: Identifiable {
    let title: String
    let sections: [CompressoSettingsSection]

    var id: String { title }
}

enum CompressoSettingsSection: String, CaseIterable, Identifiable {
    case general
    case quickAccess
    case output
    case conversion
    case tools
    case queue
    case concurrency
    case storage
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "About"
        case .quickAccess: "Quick Access"
        case .output: "Output & Storage"
        case .conversion: "Conversion"
        case .tools: "Dependencies"
        case .queue: "Media Optimization"
        case .concurrency: "Concurrency"
        case .storage: "Storage"
        case .about: "About"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "App details and shortcuts"
        case .quickAccess: "Trigger, placement, and concurrency"
        case .output: "Save location, storage, and conversion output"
        case .conversion: "How converted files are written"
        case .tools: "Dependency availability and setup"
        case .queue: "Current optimization jobs and imports"
        case .concurrency: "Parallel optimization limits"
        case .storage: "Temporary output retention"
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
        case .about: "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .general, .about:
            return Color.blue
        case .quickAccess, .concurrency:
            return Color.purple
        case .output, .conversion, .storage:
            return Color.green
        case .tools:
            return Color.orange
        case .queue:
            return Color.pink
        }
    }

    var searchText: String {
        "\(title) \(subtitle) \(searchKeywords) \(rawValue)"
    }

    var canonicalSection: CompressoSettingsSection {
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

    static let sidebarGroups: [CompressoSettingsSidebarGroup] = [
        CompressoSettingsSidebarGroup(
            title: "Settings",
            sections: [.quickAccess, .output, .tools]
        ),
        CompressoSettingsSidebarGroup(
            title: "Tool",
            sections: [.queue]
        )
    ]

    static let standaloneSections: [CompressoSettingsSection] = [.about]

    func matches(_ query: String) -> Bool {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else { return true }
        return searchText.localizedCaseInsensitiveContains(cleanedQuery)
    }
}
