import AppKit
import SwiftUI

struct QuickAccessDropReceiverView: NSViewRepresentable {
    @Binding var isTargeted: Bool
    var movesWindowOnMouseDown = true
    let onDrop: ([URL]) -> Void

    func makeNSView(context: Context) -> DropReceiverNSView {
        DropReceiverNSView(
            isTargeted: $isTargeted,
            movesWindowOnMouseDown: movesWindowOnMouseDown,
            onDrop: onDrop
        )
    }

    func updateNSView(_ nsView: DropReceiverNSView, context: Context) {
        nsView.isTargeted = $isTargeted
        nsView.movesWindowOnMouseDown = movesWindowOnMouseDown
        nsView.onDrop = onDrop
    }
}

final class DropReceiverNSView: NSView {
    var isTargeted: Binding<Bool>
    var movesWindowOnMouseDown: Bool
    var onDrop: ([URL]) -> Void
    private var cachedPasteboardChangeCount: Int?
    private var cachedHasSupportedPayload = false

    init(
        isTargeted: Binding<Bool>,
        movesWindowOnMouseDown: Bool,
        onDrop: @escaping ([URL]) -> Void
    ) {
        self.isTargeted = isTargeted
        self.movesWindowOnMouseDown = movesWindowOnMouseDown
        self.onDrop = onDrop
        super.init(frame: .zero)
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .png,
            .tiff,
            QuickAccessPasteboardPayload.jpegType,
            QuickAccessPasteboardPayload.gifType,
            QuickAccessPasteboardPayload.pdfType
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dragOperation(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        dragOperation(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        resetPayloadCache()
        updateTargeted(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        resetPayloadCache()
        updateTargeted(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dragOperation(for: sender) != []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = QuickAccessPasteboardPayload.extractOptimizableURLs(from: sender.draggingPasteboard)
        updateTargeted(false)
        guard !urls.isEmpty else { return false }
        onDrop(urls)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        resetPayloadCache()
        updateTargeted(false)
    }

    override var mouseDownCanMoveWindow: Bool { movesWindowOnMouseDown }

    override func mouseDown(with event: NSEvent) {
        if movesWindowOnMouseDown {
            window?.performDrag(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }

    private func dragOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        let canCopy = sender.draggingSourceOperationMask.contains(.copy)
        let acceptsPayload = hasSupportedPayload(sender.draggingPasteboard)
        let operation: NSDragOperation = canCopy && acceptsPayload ? .copy : []
        updateTargeted(operation != [])
        return operation
    }

    private func updateTargeted(_ targeted: Bool) {
        guard isTargeted.wrappedValue != targeted else { return }
        isTargeted.wrappedValue = targeted
    }

    private func hasSupportedPayload(_ pasteboard: NSPasteboard) -> Bool {
        let changeCount = pasteboard.changeCount
        if cachedPasteboardChangeCount == changeCount {
            return cachedHasSupportedPayload
        }

        let hasPayload = QuickAccessPasteboardPayload.hasOptimizablePayload(pasteboard)
        cachedPasteboardChangeCount = changeCount
        cachedHasSupportedPayload = hasPayload
        return hasPayload
    }

    private func resetPayloadCache() {
        cachedPasteboardChangeCount = nil
        cachedHasSupportedPayload = false
    }
}

enum QuickAccessPasteboardPayload {
    static let gifType = NSPasteboard.PasteboardType("com.compuserve.gif")
    static let jpegType = NSPasteboard.PasteboardType("public.jpeg")
    static let pdfType = NSPasteboard.PasteboardType("com.adobe.pdf")
    private static let inlineDataTypes: [NSPasteboard.PasteboardType] = [
        .png,
        .tiff,
        jpegType,
        gifType,
        pdfType
    ]

    static func hasOptimizablePayload(_ pasteboard: NSPasteboard) -> Bool {
        !extractOptimizableFileURLs(from: pasteboard).isEmpty
            || pasteboard.availableType(from: inlineDataTypes) != nil
    }

    static func pendingDropSummary(from pasteboard: NSPasteboard) -> QuickAccessPendingDropSummary? {
        let fileKinds = extractOptimizableFileURLs(from: pasteboard).map(QuickAccessFileKind.detect)
        if let summary = pendingDropSummary(for: fileKinds) {
            return summary
        }

        guard let inlineType = pasteboard.availableType(from: inlineDataTypes) else {
            return nil
        }

        return inlineType == pdfType
            ? QuickAccessPendingDropSummary(count: 1, singularName: "PDF", pluralName: "PDFs")
            : QuickAccessPendingDropSummary(count: 1, singularName: "Image", pluralName: "Images")
    }

    static func extractOptimizableURLs(from pasteboard: NSPasteboard) -> [URL] {
        var urls = extractOptimizableFileURLs(from: pasteboard)

        if urls.isEmpty {
            if let pngData = pasteboard.data(forType: .png),
               let url = try? writeDroppedImage(data: pngData, extension: "png") {
                urls.append(url)
            } else if let jpegData = pasteboard.data(forType: jpegType),
                      let url = try? writeDroppedImage(data: jpegData, extension: "jpg") {
                urls.append(url)
            } else if let gifData = pasteboard.data(forType: gifType),
                      let url = try? writeDroppedImage(data: gifData, extension: "gif") {
                urls.append(url)
            } else if let pdfData = pasteboard.data(forType: pdfType),
                      let url = try? writeDroppedImage(data: pdfData, extension: "pdf") {
                urls.append(url)
            } else if let tiffData = pasteboard.data(forType: .tiff),
                      let image = NSImage(data: tiffData),
                      let data = image.pngData,
                      let url = try? writeDroppedImage(data: data, extension: "png") {
                urls.append(url)
            }
        }

        return urls
    }

    private static func extractOptimizableFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        var urls: [URL] = []
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        if let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) {
            urls.append(contentsOf: objects.compactMap { object in
                guard let nsURL = object as? NSURL, nsURL.isFileURL else { return nil }
                return nsURL as URL
            })
        }

        if urls.isEmpty, let string = pasteboard.string(forType: .fileURL),
           let url = URL(string: string), url.isFileURL {
            urls.append(url)
        }

        return urls.filter { QuickAccessFileKind.detect(from: $0).isSupported }
    }

    private static func pendingDropSummary(for kinds: [QuickAccessFileKind]) -> QuickAccessPendingDropSummary? {
        guard !kinds.isEmpty else { return nil }

        if kinds.allSatisfy(\.isImageLikeForDropSummary) {
            return QuickAccessPendingDropSummary(count: kinds.count, singularName: "Image", pluralName: "Images")
        }
        if kinds.allSatisfy({ $0 == .video }) {
            return QuickAccessPendingDropSummary(count: kinds.count, singularName: "Video", pluralName: "Videos")
        }
        if kinds.allSatisfy({ $0 == .pdf }) {
            return QuickAccessPendingDropSummary(count: kinds.count, singularName: "PDF", pluralName: "PDFs")
        }
        return QuickAccessPendingDropSummary(count: kinds.count, singularName: "File", pluralName: "Files")
    }

    private static func writeDroppedImage(data: Data, extension pathExtension: String) throws -> URL {
        let directory = try OptimizationTemporaryFileStore.ensureDroppedInputDirectory()
        let url = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
        try data.write(to: url, options: .atomic)
        return url
    }
}

private extension QuickAccessFileKind {
    var isImageLikeForDropSummary: Bool {
        switch self {
        case .png, .jpeg, .gif, .image:
            return true
        case .video, .pdf, .unknown:
            return false
        }
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
