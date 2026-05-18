import SwiftUI

enum OnboardingPreferences {
    static let isCompleteKey = "onboarding.isComplete"
}

struct DroplitLaunchView: View {
    @AppStorage(OnboardingPreferences.isCompleteKey) private var isOnboardingComplete = false

    var body: some View {
        Group {
            if isOnboardingComplete {
                ContentView()
            } else {
                OnboardingView {
                    isOnboardingComplete = true
                }
            }
        }
        .animation(.snappy(duration: 0.22), value: isOnboardingComplete)
    }
}
