import AppKit

@MainActor
enum QuickAccessExternalDragSession {
    static func begin(
        fileURL: URL,
        thumbnail: NSImage,
        onEnded: @escaping @MainActor (Bool) -> Void
    ) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let event = NSApp.currentEvent,
              let contentView = dragContentView(for: event) else {
            return false
        }

        let dragID = UUID()
        let source = QuickAccessExternalDraggingSource(dragID: dragID) { success in
            Task { @MainActor in
                QuickAccessExternalDragRegistry.release(for: dragID)
                onEnded(success)
            }
        }
        QuickAccessExternalDragRegistry.retain(source, for: dragID)

        let dragItem = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        let dragImage = makeDragImage(from: thumbnail)
        let mouseLocation = contentView.convert(event.locationInWindow, from: nil)
        dragItem.setDraggingFrame(
            NSRect(
                x: mouseLocation.x - dragImage.size.width / 2,
                y: mouseLocation.y - dragImage.size.height / 2,
                width: dragImage.size.width,
                height: dragImage.size.height
            ),
            contents: dragImage
        )

        let session = contentView.beginDraggingSession(
            with: [dragItem],
            event: event,
            source: source
        )
        session.animatesToStartingPositionsOnCancelOrFail = true
        return true
    }

    private static func dragContentView(for event: NSEvent) -> NSView? {
        if let contentView = event.window?.contentView {
            return contentView
        }
        if let contentView = NSApp.keyWindow?.contentView {
            return contentView
        }
        return NSApp.windows.first(where: \.isVisible)?.contentView
    }

    private static func makeDragImage(from thumbnail: NSImage) -> NSImage {
        let imageSize = dragImageSize(for: thumbnail.size)
        let image = NSImage(size: imageSize)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        thumbnail.draw(
            in: NSRect(origin: .zero, size: imageSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 0.84
        )
        image.unlockFocus()
        return image
    }

    private static func dragImageSize(for sourceSize: NSSize) -> NSSize {
        let fallback = NSSize(width: 112, height: 72)
        guard sourceSize.width > 0, sourceSize.height > 0 else { return fallback }

        let maximumSize = NSSize(width: 116, height: 76)
        let scale = min(maximumSize.width / sourceSize.width, maximumSize.height / sourceSize.height)
        return NSSize(
            width: max(sourceSize.width * scale, 40),
            height: max(sourceSize.height * scale, 40)
        )
    }
}

private final class QuickAccessExternalDraggingSource: NSObject, NSDraggingSource {
    let dragID: UUID
    private let onEnded: (Bool) -> Void

    init(dragID: UUID, onEnded: @escaping (Bool) -> Void) {
        self.dragID = dragID
        self.onEnded = onEnded
        super.init()
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        onEnded(operation != [])
    }
}

@MainActor
private enum QuickAccessExternalDragRegistry {
    private static var activeSources: [UUID: QuickAccessExternalDraggingSource] = [:]

    static func retain(_ source: QuickAccessExternalDraggingSource, for id: UUID) {
        activeSources[id] = source
    }

    static func release(for id: UUID) {
        activeSources[id] = nil
    }
}
