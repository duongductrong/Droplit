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
    @State private var selectedSection: CompressoSettingsSection = .quickAccess
    @State private var isImporting = false
    @Environment(\.presentationMode) private var presentationMode
    @State private var hoveredTab: CompressoSettingsSection? = nil

    private let sidebarWidth: CGFloat = 200

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar (Aesthetic Style)
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                    .frame(height: 16)

                ForEach([CompressoSettingsSection.quickAccess, .output, .tools, .queue, .about], id: \.self) { section in
                    sidebarTabRow(section: section)
                }

                Spacer()
            }
            .frame(width: sidebarWidth)
            .frame(maxHeight: .infinity)
            .background(
                VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                    .overlay(Color.black.opacity(0.15))
            )

            // Separator
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 0.5)
                .frame(maxHeight: .infinity)

            // Content Column (Aesthetic Style)
            VStack(spacing: 0) {
                // Header Bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(selectedSection.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()

                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.3))
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(selectedSection.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()
                    .opacity(0.12)

                // Content View
                CompressoSettingsDetailView(
                    selection: $selectedSection,
                    quickAccess: quickAccess,
                    isImporting: $isImporting
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 860, height: 580)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .overlay(Color.black.opacity(0.35))
        )
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: QuickAccessFileKind.importableContentTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                quickAccess.stageDroppedURLs(urls)
            }
        }
    }

    private func sidebarTabRow(section: CompressoSettingsSection) -> some View {
        let isSelected = selectedSection == section
        let isHovered = hoveredTab == section

        return Button(action: {
            selectedSection = section
        }) {
            HStack(spacing: 8) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 16, height: 16)

                Text(section.title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : (isHovered ? Color.white.opacity(0.06) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                hoveredTab = section
            } else if hoveredTab == section {
                hoveredTab = nil
            }
        }
        .padding(.horizontal, 8)
    }
}
