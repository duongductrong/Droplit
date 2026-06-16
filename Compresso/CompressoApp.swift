//
//  CompressoApp.swift
//  Compresso
//
//  Created by duongductrong on 17/5/26.
//

import AppKit
import SwiftUI

@main
struct CompressoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Compresso") {
            CompressoLaunchView()
                .background(WindowChromeConfigurator())
                .compressoHiddenWindowToolbar()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    UpdaterManager.shared.checkForUpdates()
                }
            }
        }
    }
}

private struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        configureWindow(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWindow(for: nsView)
    }

    private func configureWindow(for view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.minSize = NSSize(width: 800, height: 560)
            
            let isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboarding.isComplete")
            window.standardWindowButton(.closeButton)?.isHidden = !isOnboardingComplete
            window.standardWindowButton(.miniaturizeButton)?.isHidden = !isOnboardingComplete
            window.standardWindowButton(.zoomButton)?.isHidden = !isOnboardingComplete
        }
    }
}
