import SwiftUI

struct OnboardingPermissionRequirement: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let isGranted: () -> Bool
    let openSettings: () -> Void
}

enum OnboardingPermissions {
    static var requirements: [OnboardingPermissionRequirement] {
        []
    }

    static var allRequirementsGranted: Bool {
        requirements.allSatisfy { $0.isGranted() }
    }
}

struct OnboardingPermissionsView: View {
    let requirements: [OnboardingPermissionRequirement]
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(requirements) { requirement in
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: requirement.systemImage)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(requirement.title)
                            .font(.body.weight(.medium))

                        Text(requirement.subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 16)

                    if requirement.isGranted() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .help("Granted")
                    } else {
                        Button("Open Settings") {
                            requirement.openSettings()
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 6)
            }

            Button("Refresh") {
                onRefresh()
            }
            .controlSize(.small)
        }
    }
}
