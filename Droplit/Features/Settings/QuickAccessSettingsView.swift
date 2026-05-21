import SwiftUI

struct QuickAccessSettingsView: View {
    @ObservedObject var quickAccess: QuickAccessManager

    var body: some View {
        DroplitSettingsPage(
            title: DroplitSettingsSection.quickAccess.title,
            subtitle: "Control how the floating optimization card appears while you drag media around your Mac."
        ) {
            DroplitSettingsGroup(
                "Activation",
                description: "Choose how Quick Access appears and where it anchors on screen."
            ) {
                DroplitSettingsControlRow(
                    title: "Trigger",
                    subtitle: "Choose the gesture that reveals Quick Access"
                ) {
                    DroplitSettingsMenuPicker(selection: $quickAccess.triggerInteraction) {
                        ForEach(QuickAccessTriggerInteraction.allCases) { interaction in
                            Text(interaction.displayName)
                                .tag(interaction)
                        }
                    }
                }

                if quickAccess.triggerInteraction == .hold {
                    DroplitSettingsDivider()
                    DroplitSettingsControlRow(
                        title: "Hold Delay",
                        subtitle: holdTriggerDurationText
                    ) {
                        holdDelayStepper
                    }
                }

                DroplitSettingsDivider()
                DroplitSettingsControlRow(
                    title: "Style",
                    subtitle: quickAccess.presentationStyle.description
                ) {
                    DroplitSettingsMenuPicker(selection: $quickAccess.presentationStyle) {
                        ForEach(QuickAccessPresentationStyle.allCases) { style in
                            Text(style.displayName)
                                .tag(style)
                        }
                    }
                }

                DroplitSettingsDivider()
                DroplitSettingsControlRow(
                    title: "Edge",
                    subtitle: "Where the panel attaches"
                ) {
                    DroplitSettingsMenuPicker(selection: quickAccessEdgeBinding) {
                        ForEach(QuickAccessPanelEdge.allCases) { edge in
                            Text(edge.displayName)
                                .tag(edge)
                        }
                    }
                }

                DroplitSettingsDivider()
                DroplitSettingsControlRow(
                    title: "Alignment",
                    subtitle: "Horizontal placement on the selected edge"
                ) {
                    DroplitSettingsMenuPicker(selection: quickAccessAlignmentBinding) {
                        ForEach(QuickAccessPanelAlignment.allCases) { alignment in
                            Text(alignment.displayName)
                                .tag(alignment)
                        }
                    }
                }
            }

            DroplitSettingsGroup(
                "After Processing",
                description: "Choose what happens after a Quick Access job finishes."
            ) {
                DroplitSettingsControlRow(
                    title: "Show Result Card",
                    subtitle: "Completed card visibility"
                ) {
                    DroplitSettingsMenuPicker(selection: $quickAccess.completedCardDisplayDuration) {
                        ForEach(QuickAccessCompletedCardDisplayDuration.allCases) { duration in
                            Text(duration.displayName)
                                .tag(duration)
                        }
                    }
                }

                DroplitSettingsDivider()
                DroplitSettingsControlRow(
                    title: "Auto Copy Result",
                    subtitle: "Copy the optimized file to the clipboard when processing finishes"
                ) {
                    DroplitSettingsSwitch(
                        "Auto Copy Result",
                        isOn: $quickAccess.autoCopyOptimizedOutputToClipboard
                    )
                }
            }

            DroplitSettingsGroup(
                "Capacity",
                description: "Control optimization throughput and preview the floating Quick Access surface."
            ) {
                DroplitSettingsControlRow(
                    title: "Concurrent Jobs",
                    subtitle: "\(quickAccess.processingCount) running, \(quickAccess.queuedCount) queued"
                ) {
                    concurrencyStepper
                }

                DroplitSettingsDivider()
                DroplitSettingsControlRow(
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
                .droplitMonospacedDigit()
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
                .droplitMonospacedDigit()
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
