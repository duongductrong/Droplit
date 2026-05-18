import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        OptimizationTemporaryFileStore.cleanupExpiredOutputsInBackground()
        startQuickAccessIfReady()
    }

    func applicationWillTerminate(_ notification: Notification) {
        QuickAccessManager.shared.stop()
    }

    private func startQuickAccessIfReady() {
        guard UserDefaults.standard.bool(forKey: OnboardingPreferences.isCompleteKey) else {
            return
        }

        QuickAccessManager.shared.start()
    }
}
