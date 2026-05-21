import AppKit
import SwiftUI

enum QuickAccessCursorStyle: Equatable {
    case arrow
    case pointingHand
    case closedHand

    var cursor: NSCursor {
        switch self {
        case .arrow:
            return .arrow
        case .pointingHand:
            return .pointingHand
        case .closedHand:
            return .closedHand
        }
    }
}

private struct QuickAccessCursorModifier: ViewModifier {
    let style: QuickAccessCursorStyle

    func body(content: Content) -> some View {
        content
            .background(QuickAccessCursorRectView(style: style))
    }
}

private struct QuickAccessCursorRectView: NSViewRepresentable {
    let style: QuickAccessCursorStyle

    func makeNSView(context: Context) -> QuickAccessCursorRectNSView {
        QuickAccessCursorRectNSView(style: style)
    }

    func updateNSView(_ nsView: QuickAccessCursorRectNSView, context: Context) {
        nsView.style = style
    }
}

private final class QuickAccessCursorRectNSView: NSView {
    var style: QuickAccessCursorStyle {
        didSet {
            window?.invalidateCursorRects(for: self)
            refreshCursorIfMouseIsInside()
        }
    }

    init(style: QuickAccessCursorStyle) {
        self.style = style
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: style.cursor)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.invalidateCursorRects(for: self)
        refreshCursorIfMouseIsInside()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        window?.invalidateCursorRects(for: self)
    }

    private func refreshCursorIfMouseIsInside() {
        guard let window else { return }
        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let localPoint = convert(windowPoint, from: nil)
        if bounds.contains(localPoint) {
            style.cursor.set()
        }
    }
}

extension View {
    func quickAccessCursor(_ style: QuickAccessCursorStyle) -> some View {
        modifier(QuickAccessCursorModifier(style: style))
    }
}
