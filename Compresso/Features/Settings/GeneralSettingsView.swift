import SwiftUI

struct GeneralSettingsView: View {
    @Binding var selection: CompressoSettingsSection
    @ObservedObject var quickAccess: QuickAccessManager

    var body: some View {
        CompressoSettingsPage(
            title: CompressoSettingsSection.general.title,
            subtitle: "Manage Quick Access, output, tools, and media optimization from a single native macOS settings surface."
        ) {
            CompressoSettingsGroup(
                "Overview",
                description: "High-level app status and related system pages."
            ) {
                CompressoSettingsNavigationRow(
                    section: .about,
                    subtitle: "Version, build, and app details"
                ) {
                    selection = .about
                }
                CompressoSettingsDivider()
                CompressoSettingsNavigationRow(
                    section: .tools,
                    subtitle: toolStatusText
                ) {
                    selection = .tools
                }
                CompressoSettingsDivider()
                CompressoSettingsNavigationRow(
                    title: CompressoSettingsSection.storage.title,
                    subtitle: outputSummary
                ) {
                    selection = .output
                }
            }

            CompressoSettingsGroup(
                "Workflow",
                description: "Core behavior for Quick Access, output, conversions, and job capacity."
            ) {
                CompressoSettingsNavigationRow(
                    section: .quickAccess,
                    subtitle: quickAccessSummary
                ) {
                    selection = .quickAccess
                }
                CompressoSettingsDivider()
                CompressoSettingsNavigationRow(
                    section: .output,
                    subtitle: "Save location, retention, and folder picker"
                ) {
                    selection = .output
                }
                CompressoSettingsDivider()
                CompressoSettingsNavigationRow(
                    title: CompressoSettingsSection.conversion.title,
                    subtitle: quickAccess.conversionOutputMode.displayName
                ) {
                    selection = .output
                }
                CompressoSettingsDivider()
                CompressoSettingsNavigationRow(
                    title: CompressoSettingsSection.concurrency.title,
                    subtitle: "\(quickAccess.maximumConcurrentOptimizations) parallel jobs"
                ) {
                    selection = .quickAccess
                }
            }
        }
    }

    private var quickAccessSummary: String {
        "\(quickAccess.triggerInteraction.displayName), \(quickAccess.position.edge.displayName.lowercased()) \(quickAccess.position.alignment.displayName.lowercased())"
    }

    private var outputSummary: String {
        if OptimizationOutputSettings.saveLocationEnabled {
            return OptimizationOutputSettings.displayName(for: OptimizationOutputSettings.outputDirectory)
        }
        return "Temporary storage, \(OptimizationOutputSettings.temporaryRetentionDays)d retention"
    }

    private var toolStatusText: String {
        let missingCount = HomebrewBootstrapService.missingTools().count
        if missingCount == 0 {
            return "All dependencies ready"
        }
        return "\(missingCount) missing dependencies"
    }
}
