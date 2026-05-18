import AppKit
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var selectedStepIndex = 0
    @State private var toolRefreshID = UUID()
    @State private var permissionRefreshID = UUID()

    private var steps: [OnboardingStep] {
        var result: [OnboardingStep] = [.welcome, .tools]
        if !OnboardingPermissions.requirements.isEmpty {
            result.append(.permissions)
        }
        result.append(.complete)
        return result
    }

    private var currentStep: OnboardingStep {
        steps[min(selectedStepIndex, steps.count - 1)]
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                GeometryReader { proxy in
                    ScrollView {
                        stepContent
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: proxy.size.height, alignment: .center)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }

                footer
            }
        }
        .frame(
            minWidth: 720,
            idealWidth: 920,
            maxWidth: .infinity,
            minHeight: 520,
            idealHeight: 680,
            maxHeight: .infinity
        )
        .containerBackground(.ultraThinMaterial, for: .window)
        .toolbarVisibility(.hidden, for: .windowToolbar)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .overlay(alignment: .top) {
            Color.clear
                .frame(height: 52)
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents(true)
        }
    }

    private var stepContent: some View {
        VStack(alignment: .center, spacing: 24) {
            VStack(alignment: .center, spacing: 8) {
                Text(currentStep.title)
                    .font(.largeTitle.weight(.semibold))

                Text(currentStep.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            switch currentStep {
            case .welcome:
                welcomeContent
            case .tools:
                OnboardingToolSetupView(
                    refreshID: toolRefreshID,
                    onRefresh: refreshTools
                )
                .frame(maxWidth: 620)
            case .permissions:
                OnboardingPermissionsView(
                    requirements: OnboardingPermissions.requirements,
                    onRefresh: refreshPermissions
                )
                .id(permissionRefreshID)
                .frame(maxWidth: 620)
            case .complete:
                completeContent
            }
        }
        .frame(maxWidth: 660, alignment: .center)
        .padding(.horizontal, 52)
        .padding(.top, 58)
        .padding(.bottom, 26)
    }

    private var welcomeContent: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            Text("Quickly optimize images, videos, GIFs, and PDFs with local tools on your Mac.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Label("Drag a supported file, trigger Quick Access, then drop it into Droplit.", systemImage: "sparkles.rectangle.stack")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 520, alignment: .center)
    }

    private var completeContent: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 58))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.green)

            Text("Droplit is ready.")
                .font(.title2.weight(.semibold))

            Text("Open the app window and start using Quick Access or import files from the queue.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 500, alignment: .center)
    }

    private var footer: some View {
        ZStack {
            HStack {
                Button("Back") {
                    selectedStepIndex = max(selectedStepIndex - 1, 0)
                }
                .disabled(selectedStepIndex == 0)

                Spacer()

                Button(primaryButtonTitle) {
                    advance()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdvance)
            }

            stepDots
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 34)
        .padding(.top, 14)
        .padding(.bottom, 34)
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(steps.indices, id: \.self) { index in
                Circle()
                    .fill(index == selectedStepIndex ? Color.primary : Color.secondary.opacity(0.28))
                    .frame(width: index == selectedStepIndex ? 7 : 6, height: index == selectedStepIndex ? 7 : 6)
                    .accessibilityLabel(steps[index].title)
                    .accessibilityValue(index == selectedStepIndex ? "Current step" : "")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var primaryButtonTitle: String {
        currentStep == .complete ? "Start Using Droplit" : "Continue"
    }

    private var canAdvance: Bool {
        switch currentStep {
        case .welcome, .complete:
            true
        case .tools:
            HomebrewBootstrapService.missingTools().isEmpty
        case .permissions:
            OnboardingPermissions.allRequirementsGranted
        }
    }

    private func advance() {
        if currentStep == .complete {
            onFinish()
            return
        }

        selectedStepIndex = min(selectedStepIndex + 1, steps.count - 1)
    }

    private func refreshTools() {
        toolRefreshID = UUID()
    }

    private func refreshPermissions() {
        permissionRefreshID = UUID()
    }
}
