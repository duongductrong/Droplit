import Foundation

enum OnboardingStep: String, Identifiable {
    case welcome
    case tools
    case permissions
    case complete

    var id: String { rawValue }

    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .tools: "Set Up Tools"
        case .permissions: "Permissions"
        case .complete: "Ready"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: "Fast local media optimization, built for macOS."
        case .tools: "Install required optimizer tools before continuing."
        case .permissions: "Grant the permissions Droplit needs on this Mac."
        case .complete: "Setup is complete."
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: "hand.wave.fill"
        case .tools: "wrench.and.screwdriver.fill"
        case .permissions: "hand.raised.fill"
        case .complete: "checkmark.circle.fill"
        }
    }
}
