import SwiftUI

struct QuickAccessSettingsView: View {
    @ObservedObject var quickAccess: QuickAccessManager

    var body: some View {
        CompressoSettingsPage(
            title: CompressoSettingsSection.quickAccess.title,
            subtitle: "Control how the floating optimization card appears while you drag media around your Mac."
        ) {
            CompressoSettingsGroup(
                "Quick Access Control",
                description: "Enable/disable the Quick Access feature globally or sync it with workspace drops."
            ) {
                CompressoSettingsControlRow(
                    title: "Enable Quick Access",
                    subtitle: "Allows summoning the floating panel by shaking/holding cursor while dragging files"
                ) {
                    CompressoSettingsSwitch(
                        "Enable Quick Access",
                        isOn: $quickAccess.isQuickAccessEnabled
                    )
                }

                if quickAccess.isQuickAccessEnabled {
                    CompressoSettingsDivider()
                    CompressoSettingsControlRow(
                        title: "Show for Workspace Drops",
                        subtitle: "Show the floating card when dropping files directly into the main window"
                    ) {
                        CompressoSettingsSwitch(
                            "Show for Workspace Drops",
                            isOn: $quickAccess.showPanelForWorkspaceJobs
                        )
                    }
                }
            }

            if quickAccess.isQuickAccessEnabled {
                CompressoSettingsGroup(
                    "Activation",
                    description: "Choose how Quick Access appears and where it anchors on screen."
                ) {
                    CompressoSettingsControlRow(
                        title: "Trigger",
                        subtitle: "Choose the gesture that reveals Quick Access"
                    ) {
                        CompressoSettingsMenuPicker(selection: $quickAccess.triggerInteraction) {
                            ForEach(QuickAccessTriggerInteraction.allCases) { interaction in
                                Text(interaction.displayName)
                                    .tag(interaction)
                            }
                        }
                    }

                    if quickAccess.triggerInteraction == .hold {
                        CompressoSettingsDivider()
                        CompressoSettingsControlRow(
                            title: "Hold Delay",
                            subtitle: holdTriggerDurationText
                        ) {
                            holdDelayStepper
                        }
                    }

                    CompressoSettingsDivider()
                    CompressoSettingsControlRow(
                        title: "Edge",
                        subtitle: "Where the panel attaches"
                    ) {
                        CompressoSettingsMenuPicker(selection: quickAccessEdgeBinding) {
                            ForEach(QuickAccessPanelEdge.allCases) { edge in
                                Text(edge.displayName)
                                    .tag(edge)
                            }
                        }
                    }

                    CompressoSettingsDivider()
                    CompressoSettingsControlRow(
                        title: "Alignment",
                        subtitle: "Horizontal placement on the selected edge"
                    ) {
                        CompressoSettingsMenuPicker(selection: quickAccessAlignmentBinding) {
                            ForEach(QuickAccessPanelAlignment.allCases) { alignment in
                                Text(alignment.displayName)
                                    .tag(alignment)
                            }
                        }
                    }
                }

                CompressoSettingsGroup(
                    "After Processing",
                    description: "Choose what happens after a Quick Access job finishes."
                ) {
                    CompressoSettingsControlRow(
                        title: "Show Result Card",
                        subtitle: "Completed card visibility"
                    ) {
                        CompressoSettingsMenuPicker(selection: $quickAccess.completedCardDisplayDuration) {
                            ForEach(QuickAccessCompletedCardDisplayDuration.allCases) { duration in
                                Text(duration.displayName)
                                    .tag(duration)
                            }
                        }
                    }

                    CompressoSettingsDivider()
                    CompressoSettingsControlRow(
                        title: "Auto Copy Result",
                        subtitle: "Copy the optimized file to the clipboard when processing finishes"
                    ) {
                        CompressoSettingsSwitch(
                            "Auto Copy Result",
                            isOn: $quickAccess.autoCopyOptimizedOutputToClipboard
                        )
                    }
                }

                CompressoSettingsGroup(
                    "Capacity",
                    description: "Control optimization throughput and preview the floating Quick Access surface."
                ) {
                    CompressoSettingsControlRow(
                        title: "Concurrent Jobs",
                        subtitle: "\(quickAccess.processingCount) running, \(quickAccess.queuedCount) queued"
                    ) {
                        concurrencyStepper
                    }

                    CompressoSettingsDivider()
                    CompressoSettingsControlRow(
                        title: "Preview",
                        subtitle: "Show the floating Quick Access card on screen"
                    ) {
                        Button("Show Preview") {
                            quickAccess.showDropPlaceholder()
                        }
                    }
                }
            }
        }
    }

    private var concurrencyBinding: Binding<Int> {
        Binding(
            get: { quickAccess.maximumConcurrentOptimizations },
            set: { quickAccess.setMaximumConcurrentOptimizations($0) }
        )
    }

    private var holdTriggerDurationText: String {
        String(format: "%.1f seconds", quickAccess.holdTriggerDuration)
    }

    private var holdTriggerDurationBinding: Binding<TimeInterval> {
        Binding(
            get: { quickAccess.holdTriggerDuration },
            set: { quickAccess.setHoldTriggerDuration($0) }
        )
    }

    private var holdDelayStepper: some View {
        HStack(spacing: 10) {
            Text(holdTriggerDurationText)
                .compressoMonospacedDigit()
                .foregroundColor(.secondary)
                .frame(minWidth: 82, alignment: .trailing)

            Stepper(
                "",
                value: holdTriggerDurationBinding,
                in: QuickAccessManager.allowedHoldTriggerDurationRange,
                step: 0.1
            )
            .labelsHidden()
        }
    }

    private var concurrencyStepper: some View {
        HStack(spacing: 10) {
            Text("\(quickAccess.maximumConcurrentOptimizations)")
                .compressoMonospacedDigit()
                .foregroundColor(.secondary)
                .frame(minWidth: 20, alignment: .trailing)

            Stepper("", value: concurrencyBinding, in: 1...12)
                .labelsHidden()
        }
    }

    private var quickAccessEdgeBinding: Binding<QuickAccessPanelEdge> {
        Binding(
            get: { quickAccess.position.edge },
            set: { quickAccess.position = quickAccess.position.with(edge: $0) }
        )
    }

    private var quickAccessAlignmentBinding: Binding<QuickAccessPanelAlignment> {
        Binding(
            get: { quickAccess.position.alignment },
            set: { quickAccess.position = quickAccess.position.with(alignment: $0) }
        )
    }
}
