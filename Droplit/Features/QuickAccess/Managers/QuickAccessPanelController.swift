import AppKit
import SwiftUI

@MainActor
final class QuickAccessPanelController: NSObject, NSWindowDelegate {
    private var panel: QuickAccessPanel?
    private var position: QuickAccessPosition = .bottomRight
    private let padding: CGFloat = 22
    private var isAnimating = false
    private var isApplyingProgrammaticFrameChange = false
    private var manualFrameOrigin: NSPoint?
    private var activeContentHeight: CGFloat = 0
    private var shadowMargin: CGFloat = QuickAccessLayout.shadowMargin

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    var isVisible: Bool { panel != nil }

    func show<Content: View>(
        _ content: Content,
        size: CGSize,
        position: QuickAccessPosition,
        activeContentHeight: CGFloat,
        shadowMargin: CGFloat,
        handlesKeyboardShortcuts: Bool,
        onCancel: @escaping () -> Void
    ) {
        guard !isAnimating else { return }
        self.position = position
        self.manualFrameOrigin = nil
        self.activeContentHeight = activeContentHeight
        self.shadowMargin = shadowMargin

        let screen = ScreenUtility.activeScreen()
        let targetOrigin = position.calculateOrigin(
            for: size,
            on: screen,
            padding: padding,
            shadowMargin: shadowMargin
        )
        let targetFrame = NSRect(origin: targetOrigin, size: size)

        let panel = QuickAccessPanel(contentRect: targetFrame)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: size)
        panel.delegate = self
        panel.handlesKeyboardShortcuts = handlesKeyboardShortcuts
        panel.onEscapeKey = onCancel
        panel.contentView = hostingView
        panel.updatePassthroughRegion(activeContentHeight: activeContentHeight, edge: position.edge)
        self.panel = panel

        if reduceMotion {
            panel.alphaValue = 0
            present(panel)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = QuickAccessAnimations.panelExitDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else {
            let offscreenOrigin = position.offscreenOrigin(
                for: size,
                on: screen,
                padding: padding,
                shadowMargin: shadowMargin
            )
            applyProgrammaticFrameChange {
                panel.setFrame(NSRect(origin: offscreenOrigin, size: size), display: false)
            }
            panel.alphaValue = 1
            present(panel)

            isAnimating = true
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = QuickAccessAnimations.panelEnterDuration
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
                panel.animator().setFrame(targetFrame, display: true)
            }, completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    panel.updatePassthroughRegion(
                        activeContentHeight: self?.activeContentHeight ?? 0,
                        edge: self?.position.edge ?? .bottom
                    )
                    self?.manualFrameOrigin = nil
                    self?.isAnimating = false
                }
            })
        }
    }

    func updatePosition(_ newPosition: QuickAccessPosition) {
        position = newPosition
        manualFrameOrigin = nil
        panel?.updatePassthroughRegion(activeContentHeight: activeContentHeight, edge: newPosition.edge)
        repositionPanel()
    }

    func updateSize(_ size: CGSize, shadowMargin: CGFloat) {
        guard let panel, !isAnimating else { return }
        self.shadowMargin = shadowMargin
        let screen = ScreenUtility.activeScreen()
        let origin = manualFrameOrigin ?? position.calculateOrigin(
            for: size,
            on: screen,
            padding: padding,
            shadowMargin: shadowMargin
        )
        let targetFrame = NSRect(origin: origin, size: size)
        if panel.frame != targetFrame {
            applyProgrammaticFrameChange {
                panel.setFrame(targetFrame, display: true, animate: false)
            }
            if manualFrameOrigin != nil {
                manualFrameOrigin = panel.frame.origin
            }
        }
        panel.updatePassthroughRegion(activeContentHeight: activeContentHeight, edge: position.edge)
    }

    func updateInteractionMetrics(activeContentHeight: CGFloat) {
        self.activeContentHeight = activeContentHeight
        panel?.updatePassthroughRegion(activeContentHeight: activeContentHeight, edge: position.edge)
    }

    func hide() {
        guard let panel else { return }
        if isAnimating {
            hideImmediately()
            return
        }

        if reduceMotion {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = QuickAccessAnimations.panelExitDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    self?.closePanel(panel)
                }
            })
        } else {
            let screen = ScreenUtility.activeScreen()
            let size = panel.frame.size
            let offscreenOrigin = position.offscreenOrigin(
                for: size,
                on: screen,
                padding: padding,
                shadowMargin: shadowMargin
            )
            isAnimating = true
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = QuickAccessAnimations.panelExitDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(NSRect(origin: offscreenOrigin, size: size), display: true)
                panel.animator().alphaValue = 0.5
            }, completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    self?.closePanel(panel)
                }
            })
        }
    }

    func hideImmediately() {
        guard let panel else { return }
        closePanel(panel)
    }

    func windowDidMove(_ notification: Notification) {
        guard let movedPanel = notification.object as? QuickAccessPanel,
              movedPanel === panel,
              !isAnimating,
              !isApplyingProgrammaticFrameChange else {
            return
        }

        manualFrameOrigin = movedPanel.frame.origin
        movedPanel.updatePassthroughRegion(activeContentHeight: activeContentHeight, edge: position.edge)
    }

    private func present(_ panel: QuickAccessPanel) {
        panel.orderFrontRegardless()
        if panel.canBecomeKey {
            panel.makeKey()
        }
    }

    private func applyProgrammaticFrameChange(_ change: () -> Void) {
        isApplyingProgrammaticFrameChange = true
        change()
        isApplyingProgrammaticFrameChange = false
    }

    private func closePanel(_ closingPanel: QuickAccessPanel) {
        closingPanel.delegate = nil
        closingPanel.onEscapeKey = nil
        closingPanel.orderOut(nil)
        closingPanel.close()
        if panel === closingPanel {
            panel = nil
            manualFrameOrigin = nil
            isAnimating = false
            isApplyingProgrammaticFrameChange = false
        }
    }

    private func repositionPanel() {
        guard let panel, !isAnimating else { return }
        let screen = ScreenUtility.activeScreen()
        let origin = position.calculateOrigin(
            for: panel.frame.size,
            on: screen,
            padding: padding,
            shadowMargin: shadowMargin
        )

        if reduceMotion {
            applyProgrammaticFrameChange {
                panel.setFrameOrigin(origin)
            }
            panel.updatePassthroughRegion(activeContentHeight: activeContentHeight, edge: position.edge)
        } else {
            isApplyingProgrammaticFrameChange = true
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrameOrigin(origin)
            }, completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    self?.isApplyingProgrammaticFrameChange = false
                    panel.updatePassthroughRegion(
                        activeContentHeight: self?.activeContentHeight ?? 0,
                        edge: self?.position.edge ?? .bottom
                    )
                }
            })
        }
    }
}
