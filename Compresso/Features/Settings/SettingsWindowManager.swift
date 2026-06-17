import AppKit
import SwiftUI

@MainActor
final class SettingsWindowManager: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowManager()

    private var settingsWindow: NSWindow?

    func showSettings(quickAccess: QuickAccessManager) {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsViewWrapper(quickAccess: quickAccess)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Cài đặt"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 860, height: 560)
        window.contentViewController = hostingController
        window.delegate = self
        window.isReleasedWhenClosed = false

        // Standard traffic lights will be visible and fully functional
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false

        window.center()
        window.makeKeyAndOrderFront(nil)
        self.settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        settingsWindow = nil
    }
}

struct SettingsViewWrapper: View {
    @ObservedObject var quickAccess: QuickAccessManager
    @State private var selectedSection: CompressoSettingsSection? = .about
    @State private var searchText = ""
    @State private var isImporting = false

    var body: some View {
        Group {
            if #available(macOS 13.0, *) {
                CompressoModernSettingsRoot(
                    quickAccess: quickAccess,
                    selectedSection: $selectedSection,
                    selectedDetailSection: selectedSectionBinding,
                    searchText: $searchText,
                    isImporting: $isImporting
                )
            } else {
                CompressoLegacySettingsRoot(
                    quickAccess: quickAccess,
                    selectedSection: $selectedSection,
                    selectedDetailSection: selectedSectionBinding,
                    searchText: $searchText,
                    isImporting: $isImporting
                )
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: QuickAccessFileKind.importableContentTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                quickAccess.ingestDroppedURLs(urls)
            }
        }
        .frame(
            minWidth: 860,
            idealWidth: 860,
            maxWidth: .infinity,
            minHeight: 560,
            idealHeight: 760,
            maxHeight: .infinity
        )
    }

    private var selectedSectionBinding: Binding<CompressoSettingsSection> {
        Binding(
            get: { (selectedSection ?? .about).canonicalSection },
            set: { selectedSection = $0.canonicalSection }
        )
    }
}
