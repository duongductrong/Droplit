import AppKit
import Foundation
import UniformTypeIdentifiers

nonisolated enum QuickAccessPanelEdge: String, CaseIterable, Codable, Identifiable {
    case bottom
    case top

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bottom: "Bottom"
        case .top: "Top"
        }
    }

    var systemImage: String {
        switch self {
        case .bottom: "arrow.down.to.line"
        case .top: "arrow.up.to.line"
        }
    }
}

nonisolated enum QuickAccessPanelAlignment: String, CaseIterable, Codable, Identifiable {
    case left
    case center
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: "Left"
        case .center: "Center"
        case .right: "Right"
        }
    }

    var systemImage: String {
        switch self {
        case .left: "align.horizontal.left.fill"
        case .center: "align.horizontal.center.fill"
        case .right: "align.horizontal.right.fill"
        }
    }
}

nonisolated enum QuickAccessPosition: String, CaseIterable, Codable, Identifiable {
    case topLeft
    case topCenter
    case topRight
    case bottomLeft
    case bottomCenter
    case bottomRight

    var id: String { rawValue }

    init(edge: QuickAccessPanelEdge, alignment: QuickAccessPanelAlignment) {
        switch (edge, alignment) {
        case (.top, .left): self = .topLeft
        case (.top, .center): self = .topCenter
        case (.top, .right): self = .topRight
        case (.bottom, .left): self = .bottomLeft
        case (.bottom, .center): self = .bottomCenter
        case (.bottom, .right): self = .bottomRight
        }
    }

    var displayName: String {
        switch self {
        case .topLeft: "Top Left"
        case .topCenter: "Top Center"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomCenter: "Bottom Center"
        case .bottomRight: "Bottom Right"
        }
    }

    var systemImage: String {
        switch self {
        case .topLeft: "arrow.up.left.circle"
        case .topCenter: "arrow.up.circle"
        case .topRight: "arrow.up.right.circle"
        case .bottomLeft: "arrow.down.left.circle"
        case .bottomCenter: "arrow.down.circle"
        case .bottomRight: "arrow.down.right.circle"
        }
    }

    var edge: QuickAccessPanelEdge {
        switch self {
        case .topLeft, .topCenter, .topRight: .top
        case .bottomLeft, .bottomCenter, .bottomRight: .bottom
        }
    }

    var alignment: QuickAccessPanelAlignment {
        switch self {
        case .topLeft, .bottomLeft: .left
        case .topCenter, .bottomCenter: .center
        case .topRight, .bottomRight: .right
        }
    }

    var isTopEdge: Bool { edge == .top }
    var isLeftSide: Bool { alignment == .left }
    var dismissDirection: CGFloat { isLeftSide ? -1 : 1 }

    func with(edge newEdge: QuickAccessPanelEdge) -> QuickAccessPosition {
        QuickAccessPosition(edge: newEdge, alignment: alignment)
    }

    func with(alignment newAlignment: QuickAccessPanelAlignment) -> QuickAccessPosition {
        QuickAccessPosition(edge: edge, alignment: newAlignment)
    }

    func calculateOrigin(
        for size: CGSize,
        on screen: NSScreen,
        padding: CGFloat = 22,
        shadowMargin: CGFloat = QuickAccessLayout.shadowMargin
    ) -> CGPoint {
        let frame = screen.visibleFrame
        let x: CGFloat
        switch alignment {
        case .left:
            x = frame.minX + padding - shadowMargin
        case .center:
            x = frame.midX - size.width / 2
        case .right:
            x = frame.maxX - size.width - padding + shadowMargin
        }

        let y = panelY(
            matchingCardBoundary: cardBoundaryY(on: screen, padding: padding),
            size: size,
            shadowMargin: shadowMargin
        )

        return CGPoint(x: x, y: y)
    }

    func offscreenOrigin(
        for size: CGSize,
        on screen: NSScreen,
        padding: CGFloat = 22,
        shadowMargin: CGFloat = QuickAccessLayout.shadowMargin
    ) -> CGPoint {
        let frame = screen.visibleFrame
        let margin: CGFloat = 48
        if isTopEdge {
            let targetOrigin = calculateOrigin(
                for: size,
                on: screen,
                padding: padding,
                shadowMargin: shadowMargin
            )
            return CGPoint(x: targetOrigin.x, y: frame.maxY + margin)
        }

        switch alignment {
        case .left:
            return CGPoint(x: frame.minX - size.width - margin, y: frame.minY + padding)
        case .center:
            return CGPoint(x: frame.midX - size.width / 2, y: frame.minY - size.height - margin)
        case .right:
            return CGPoint(x: frame.maxX + margin, y: frame.minY + padding)
        }
    }

    private func cardBoundaryY(on screen: NSScreen, padding: CGFloat) -> CGFloat {
        let frame = screen.visibleFrame
        switch edge {
        case .bottom:
            return frame.minY + padding
        case .top:
            return frame.maxY + topSafeAreaCompensation(on: screen) - padding
        }
    }

    private func topSafeAreaCompensation(on screen: NSScreen) -> CGFloat {
        let frameInset = screen.frame.maxY - screen.visibleFrame.maxY
        if #available(macOS 12.0, *) {
            return max(frameInset, screen.safeAreaInsets.top)
        }
        return frameInset
    }

    private func panelY(matchingCardBoundary boundaryY: CGFloat, size: CGSize, shadowMargin: CGFloat) -> CGFloat {
        switch edge {
        case .bottom:
            return boundaryY - shadowMargin
        case .top:
            return boundaryY + shadowMargin - size.height
        }
    }
}

nonisolated enum QuickAccessTriggerInteraction: String, CaseIterable, Codable, Identifiable {
    case shake
    case hold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shake: "Shake"
        case .hold: "Hold"
        }
    }

    var systemImage: String {
        switch self {
        case .shake: "waveform.path.ecg"
        case .hold: "timer"
        }
    }
}

nonisolated struct QuickAccessPendingDropSummary: Equatable {
    let count: Int
    let singularName: String
    let pluralName: String

    var displayText: String {
        "\(count) \(count == 1 ? singularName : pluralName)"
    }
}

nonisolated enum QuickAccessCompletedCardDisplayDuration: String, CaseIterable, Codable, Identifiable {
    case fiveSeconds
    case tenSeconds
    case fifteenSeconds
    case thirtySeconds
    case sixtySeconds
    case never

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fiveSeconds: "5 seconds"
        case .tenSeconds: "10 seconds"
        case .fifteenSeconds: "15 seconds"
        case .thirtySeconds: "30 seconds"
        case .sixtySeconds: "60 seconds"
        case .never: "Never"
        }
    }

    var description: String {
        switch self {
        case .never:
            return "Keep completed cards visible until you remove them"
        default:
            return "Hide completed cards after \(displayName)"
        }
    }

    var timeoutNanoseconds: UInt64? {
        switch self {
        case .fiveSeconds:
            return 5_000_000_000
        case .tenSeconds:
            return 10_000_000_000
        case .fifteenSeconds:
            return 15_000_000_000
        case .thirtySeconds:
            return 30_000_000_000
        case .sixtySeconds:
            return 60_000_000_000
        case .never:
            return nil
        }
    }
}

nonisolated enum QuickAccessLayout {
    static let cardWidth: CGFloat = 180
    static let cardHeight: CGFloat = 112
    static let overflowCardHeight: CGFloat = cardHeight
    static let conversionActionRowHeight: CGFloat = 16
    static let conversionActionVisualHeight: CGFloat = 13
    static let conversionActionSpacing: CGFloat = 3
    static let conversionActionButtonSpacing: CGFloat = 3
    static let conversionActionFontSize: CGFloat = 6.5
    static let closeButtonHitSize: CGFloat = 30
    static let closeButtonVisualSize: CGFloat = 20
    static let closeButtonIconSize: CGFloat = 10
    static let kindBadgeWidth: CGFloat = 24
    static let kindBadgeHeight: CGFloat = 16
    static let kindBadgeIconSize: CGFloat = 9
    static let kindBadgeCornerRadius: CGFloat = 5
    static let topControlHorizontalPadding: CGFloat = 6
    static let topControlTopPadding: CGFloat = 6
    static let cornerRadius: CGFloat = 16
    static let cardSpacing: CGFloat = 8
    static let shadowMargin: CGFloat = 24
    static let containerPadding: CGFloat = shadowMargin
    static let stackMaximumItems = 4

    static func itemHeight(hasConversionActions: Bool) -> CGFloat {
        cardHeight + (hasConversionActions ? conversionActionSpacing + conversionActionRowHeight : 0)
    }

    static func stackPanelSize(
        itemCardCount: Int,
        conversionActionRowCount: Int,
        dropPlaceholderCount: Int,
        includesOverflowCard: Bool
    ) -> CGSize {
        let visibleCount = max(
            itemCardCount + dropPlaceholderCount + (includesOverflowCard ? 1 : 0),
            1
        )
        let itemHeight = cardHeight * CGFloat(itemCardCount)
            + (conversionActionSpacing + conversionActionRowHeight) * CGFloat(conversionActionRowCount)
        let dropPlaceholderHeight = cardHeight * CGFloat(dropPlaceholderCount)
        let overflowHeight = includesOverflowCard ? overflowCardHeight : 0
        let height = itemHeight + dropPlaceholderHeight + overflowHeight
            + (cardSpacing * CGFloat(max(visibleCount - 1, 0)))
            + (containerPadding * 2)
        return CGSize(width: cardWidth + containerPadding * 2, height: height)
    }

    static func fixedStackPanelSize(includesDropPlaceholder: Bool) -> CGSize {
        stackPanelSize(
            itemCardCount: stackMaximumItems,
            conversionActionRowCount: stackMaximumItems,
            dropPlaceholderCount: includesDropPlaceholder ? 1 : 0,
            includesOverflowCard: true
        )
    }
}

nonisolated enum QuickAccessJobSource: String, Codable {
    case quickAccess
    case workspace
}

nonisolated enum QuickAccessJobState: Equatable {
    case staged
    case queued
    case processing
    case completed
    case failed
}

nonisolated enum QuickAccessFileKind: String, CaseIterable, Codable {
    case png
    case jpeg
    case gif
    case video
    case pdf
    case image
    case unknown

    static let importableContentTypes: [UTType] = [
        .png,
        .jpeg,
        .gif,
        .image,
        .movie,
        .mpeg4Movie,
        .quickTimeMovie,
        .pdf
    ]

    static func detect(from url: URL) -> QuickAccessFileKind {
        switch url.pathExtension.lowercased() {
        case "png": .png
        case "jpg", "jpeg": .jpeg
        case "gif": .gif
        case "mov", "mp4", "m4v", "avi", "mkv", "webm": .video
        case "pdf": .pdf
        case "heic", "heif", "tif", "tiff", "webp": .image
        default: .unknown
        }
    }

    var isSupported: Bool { self != .unknown }

    var displayName: String {
        switch self {
        case .png: "PNG"
        case .jpeg: "JPEG"
        case .gif: "GIF"
        case .video: "Video"
        case .pdf: "PDF"
        case .image: "Image"
        case .unknown: "File"
        }
    }

    var systemImage: String {
        switch self {
        case .png, .jpeg, .image: "photo.fill"
        case .gif: "sparkles"
        case .video: "video.fill"
        case .pdf: "doc.richtext.fill"
        case .unknown: "doc.fill"
        }
    }
}

nonisolated enum QuickAccessConversionTarget: String, CaseIterable, Codable, Identifiable {
    case png
    case jpeg
    case webp
    case heic
    case gif
    case mov
    case mp4

    var id: String { rawValue }

    static let imageTargets: [QuickAccessConversionTarget] = [.png, .jpeg, .webp, .heic]
    static let videoTargets: [QuickAccessConversionTarget] = [.gif, .mov, .mp4]

    static func targets(for kind: QuickAccessFileKind) -> [QuickAccessConversionTarget] {
        switch kind {
        case .png, .jpeg, .image:
            return imageTargets
        case .gif, .video:
            return videoTargets
        case .pdf, .unknown:
            return []
        }
    }

    static func sourceTarget(for url: URL, kind: QuickAccessFileKind) -> QuickAccessConversionTarget? {
        let pathExtension = url.pathExtension.lowercased()
        let target: QuickAccessConversionTarget?

        switch pathExtension {
        case "png":
            target = .png
        case "jpg", "jpeg":
            target = .jpeg
        case "webp":
            target = .webp
        case "heic", "heif":
            target = .heic
        case "gif":
            target = .gif
        case "mov":
            target = .mov
        case "mp4":
            target = .mp4
        default:
            target = nil
        }

        guard let target, targets(for: kind).contains(target) else {
            return nil
        }
        return target
    }

    var displayName: String {
        switch self {
        case .jpeg:
            return "JPEG"
        default:
            return rawValue.uppercased()
        }
    }

    var fileExtension: String {
        rawValue
    }

    var isImageTarget: Bool {
        Self.imageTargets.contains(self)
    }

    var isVideoTarget: Bool {
        Self.videoTargets.contains(self)
    }

    var processingTitle: String {
        "Converting to \(displayName)"
    }
}

nonisolated struct QuickAccessItem: Identifiable {
    let id: UUID
    let sourceURL: URL
    let kind: QuickAccessFileKind
    var thumbnail: NSImage
    let createdAt: Date
    let originalBytes: Int64
    var mediaDuration: TimeInterval?
    var state: QuickAccessJobState
    var elapsed: TimeInterval
    var progress: Double?
    var optimizedBytes: Int64?
    var outputURL: URL?
    var pixelSize: CGSize?
    var failureMessage: String?
    var activeOperationName: String
    var activeConversionTarget: QuickAccessConversionTarget?
    let source: QuickAccessJobSource

    init(
        sourceURL: URL,
        kind: QuickAccessFileKind,
        thumbnail: NSImage,
        originalBytes: Int64,
        mediaDuration: TimeInterval?,
        pixelSize: CGSize?,
        state: QuickAccessJobState = .queued,
        source: QuickAccessJobSource = .quickAccess
    ) {
        self.id = UUID()
        self.sourceURL = sourceURL
        self.kind = kind
        self.thumbnail = thumbnail
        self.createdAt = Date()
        self.originalBytes = originalBytes
        self.mediaDuration = mediaDuration
        self.pixelSize = pixelSize
        self.state = state
        self.elapsed = 0
        self.progress = nil
        self.optimizedBytes = nil
        self.outputURL = nil
        self.failureMessage = nil
        self.activeOperationName = "Optimizing"
        self.activeConversionTarget = QuickAccessConversionTarget.sourceTarget(for: sourceURL, kind: kind)
        self.source = source
    }

    var originalSizeText: String {
        ByteCountFormatter.compressoString(fromByteCount: originalBytes)
    }

    var optimizedSizeText: String {
        ByteCountFormatter.compressoString(fromByteCount: optimizedBytes ?? originalBytes)
    }

    var sizeComparisonText: String {
        "\(originalSizeText) -> \(optimizedSizeText)"
    }

    var displayTitle: String {
        let title = sourceURL.deletingPathExtension().lastPathComponent
        return title.isEmpty ? sourceURL.lastPathComponent : title
    }

    var conversionTargets: [QuickAccessConversionTarget] {
        QuickAccessConversionTarget.targets(for: kind)
    }

    var sourceConversionTarget: QuickAccessConversionTarget? {
        QuickAccessConversionTarget.sourceTarget(for: sourceURL, kind: kind)
    }

    var hasConversionTargets: Bool {
        !conversionTargets.isEmpty
    }

    var dimensionsText: String {
        guard let pixelSize, pixelSize.width > 0, pixelSize.height > 0 else {
            return kind.displayName
        }
        return "\(Int(pixelSize.width))x\(Int(pixelSize.height))"
    }

    var detailLine: String {
        switch state {
        case .staged:
            return "Ready"
        case .queued:
            return "Queued"
        case .processing:
            if let mediaDuration, mediaDuration > 0 {
                return "\(activeOperationName) \(elapsed.timecode3) of \(mediaDuration.timecode3)"
            }
            return "\(activeOperationName) \(elapsed.timecode3)"
        case .completed:
            return sizeComparisonText
        case .failed:
            return failureMessage ?? "Failed"
        }
    }

    var preferredExternalDragURL: URL? {
        if let outputURL,
           FileManager.default.fileExists(atPath: outputURL.path) {
            return outputURL
        }
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            return sourceURL
        }
        return nil
    }

    var usesOptimizedExternalDragURL: Bool {
        guard let outputURL,
              let preferredExternalDragURL else {
            return false
        }
        return outputURL == preferredExternalDragURL
    }

    var removesAfterExternalDrag: Bool {
        state == .completed && usesOptimizedExternalDragURL
    }
}

extension ByteCountFormatter {
    nonisolated static func compressoString(fromByteCount bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes).replacingOccurrences(of: " ", with: "")
    }
}

extension TimeInterval {
    nonisolated var timecode3: String {
        String(format: "%.3fs", self)
    }
}
