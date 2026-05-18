import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        OptimizationTemporaryFileStore.cleanupExpiredOutputsInBackground()
    }

    func applicationWillTerminate(_ notification: Notification) {
        QuickAccessManager.shared.stop()
    }
}
