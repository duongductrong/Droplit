import AppKit

final class QuickAccessPanel: NSPanel {
    var onEscapeKey: (() -> Void)?
    var handlesKeyboardShortcuts = false

    private var activeContentHeight: CGFloat = 0
    private var activeEdge: QuickAccessPanelEdge = .bottom
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configurePanel()
        installMouseMonitors()
    }

    override func close() {
        removeMouseMonitors()
        super.close()
    }

    func updatePassthroughRegion(activeContentHeight: CGFloat, edge: QuickAccessPanelEdge) {
        self.activeContentHeight = max(0, activeContentHeight)
        self.activeEdge = edge
        refreshMousePassthrough()
    }

    func containsInteractivePoint(_ screenPoint: NSPoint) -> Bool {
        guard activeContentHeight > 0 else { return false }

        let height = min(activeContentHeight, frame.height)
        let minY: CGFloat
        switch activeEdge {
        case .bottom:
            minY = frame.minY
        case .top:
            minY = frame.maxY - height
        }

        return NSRect(
            x: frame.minX,
            y: minY,
            width: frame.width,
            height: height
        ).contains(screenPoint)
    }

    private func configurePanel() {
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false
    }

    private func installMouseMonitors() {
        let mask: NSEvent.EventTypeMask = [
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged
        ]

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated {
                self?.refreshMousePassthrough()
            }
            return event
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            Task { @MainActor in
                self?.refreshMousePassthrough()
            }
        }
    }

    private func removeMouseMonitors() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func refreshMousePassthrough() {
        ignoresMouseEvents = !containsInteractivePoint(NSEvent.mouseLocation)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscapeKey?()
            return
        }

        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscapeKey?()
    }

    override var canBecomeKey: Bool { handlesKeyboardShortcuts }
    override var canBecomeMain: Bool { false }
}
