import AppKit
import SwiftUI

struct QuickAccessBoxView: View {
    let context: QuickAccessPresentationContext
    let actions: QuickAccessPresentationActions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTargeted = false
    @State private var isItemsPopoverPresented = false
    @State private var isBatchActionsPopoverPresented = false

    private typealias Layout = QuickAccessBoxLayout

    var body: some View {
        ZStack {
            boxPlacement

            if showsDropReceiver {
                expandedDropReceiver
            }
        }
        .frame(width: Layout.panelSize.width, height: Layout.panelSize.height)
        .onChange(of: context.items.isEmpty) { isEmpty in
            if isEmpty {
                isItemsPopoverPresented = false
                isBatchActionsPopoverPresented = false
            }
        }
        .onChange(of: showsDropReceiver) { isVisible in
            if !isVisible {
                isTargeted = false
            }
        }
    }

    private var boxPlacement: some View {
        VStack(spacing: 0) {
            if context.position.isTopEdge {
                boxSurface
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                boxSurface
            }
        }
        .padding(Layout.shadowMargin)
    }

    private var boxSurface: some View {
        ZStack {
            boxBackground
            QuickAccessBoxDragHandleView(passthroughRects: boxDragPassthroughRects)
                .frame(width: Layout.boxSize.width, height: Layout.boxSize.height)

            if showsPreviewStack {
                previewStack
            } else {
                QuickAccessBoxEmptyStateView(
                    isTargeted: isTargeted,
                    hasPendingDropSummary: context.pendingDropSummary != nil
                )
                    .offset(y: -7)
            }

            chromeOverlay
        }
        .frame(width: Layout.boxSize.width, height: Layout.boxSize.height)
        .clipShape(boxShape)
        .overlay(boxBorder)
        .contentShape(boxShape)
        .contextMenu {
            QuickAccessBoxActionMenu(items: context.items, actions: actions)
        }
        .onTapGesture(count: 2) {
            if let item = latestItem {
                actions.openItem(item.id)
            }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(isTargeted ? 0.18 : 0.12), radius: isTargeted ? 16 : 13, x: 0, y: 5)
        .shadow(color: .black.opacity(isTargeted ? 0.08 : 0.055), radius: isTargeted ? 5 : 4, x: 0, y: 1)
        .animation(QuickAccessAnimations.hoverOverlay, value: isTargeted)
    }

    private var expandedDropReceiver: some View {
        QuickAccessDropReceiverView(
            isTargeted: $isTargeted,
            movesWindowOnMouseDown: dropReceiverMovesWindowOnMouseDown
        ) { urls in
            actions.stageDroppedURLs(urls)
        }
        .frame(width: Layout.panelSize.width, height: Layout.panelSize.height)
    }

    private var previewStack: some View {
        QuickAccessBoxPreviewView(
            items: context.items,
            isTargeted: isTargeted,
            reduceMotion: reduceMotion,
            onExternalDragCompleted: actions.clearItemsKeepingSurfaceVisible
        )
            .offset(y: -5)
            .contentShape(Rectangle())
    }

    private var boxBackground: some View {
        ZStack {
            boxShape.fill(Color(red: 0.115, green: 0.115, blue: 0.112))
            DroplitMaterialFill(shape: boxShape, kind: .regular, fallbackOpacity: 0.86)
                .opacity(0.18)
            boxShape.fill(.white.opacity(isTargeted ? 0.045 : 0.018))
        }
    }

    private var chromeOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                chromeButton(systemImage: "xmark") {
                    actions.removeAllItems()
                }
                .help(context.items.isEmpty ? "Close" : "Clear all items")

                Spacer()
                batchActionButton
            }
            .padding(Layout.chromeInset)

            Spacer(minLength: 0)
            if showsPreviewStack {
                countPill
                    .padding(.bottom, Layout.countPillBottomInset)
            }
        }
    }

    private var batchActionButton: some View {
        chromeButton(systemImage: topRightIcon) {
            guard !context.items.isEmpty else { return }
            isBatchActionsPopoverPresented.toggle()
        }
        .popover(isPresented: $isBatchActionsPopoverPresented) {
            QuickAccessBoxActionsPopoverView(items: context.items, actions: actions)
        }
        .help(topRightHelp)
    }

    private var countPill: some View {
        Button {
            if !context.items.isEmpty {
                isItemsPopoverPresented.toggle()
            }
        } label: {
            countPillContent
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isItemsPopoverPresented) {
            QuickAccessBoxItemsPopoverView(items: context.items, actions: actions)
        }
        .help(context.items.isEmpty ? "Drop items to inspect" : "Show dropped items")
    }

    private var countPillContent: some View {
        HStack(spacing: 7) {
            Text(countText)
                .font(.system(size: Layout.countFontSize, weight: .regular))
                .foregroundColor(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Image(systemName: countPillIcon)
                .font(.system(size: showsPreviewStack ? 17 : 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.62))
        }
        .padding(.leading, 11)
        .padding(.trailing, 5)
        .frame(height: Layout.countPillHeight)
        .background(Capsule().fill(Color.white.opacity(0.105)))
    }

    private func chromeButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            chromeCircle(systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func chromeCircle(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(
                size: systemImage == "ellipsis" ? Layout.chromeMoreIconSize : Layout.chromeCloseIconSize,
                weight: .semibold
            ))
            .foregroundColor(.black.opacity(0.70))
            .frame(width: Layout.chromeButtonSize, height: Layout.chromeButtonSize)
            .background(Circle().fill(Color.white.opacity(0.68)))
            .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
            .contentShape(Circle())
    }

    private var countText: String {
        let count = context.items.count
        guard count > 0 else {
            return context.pendingDropSummary?.displayText ?? (isTargeted ? "Release" : "Drop Items")
        }
        if activeItemCount > 0 {
            return "\(finishedItemCount)/\(count) Done"
        }
        if !hasStagedItems, let batchSizeComparisonText {
            return batchSizeComparisonText
        }
        if failedItemCount > 0 {
            return "\(completedItemCount)/\(count) Done"
        }
        if completedItemCount == count {
            return batchSizeComparisonText ?? "All Done"
        }
        return "\(count) \(itemNoun(for: count))"
    }

    private var countPillIcon: String {
        guard showsPreviewStack else { return "tray.and.arrow.down.fill" }
        if activeItemCount > 0 { return "clock.fill" }
        if failedItemCount > 0 { return "exclamationmark.circle.fill" }
        if completedItemCount == context.items.count { return "checkmark.circle.fill" }
        return "chevron.down.circle.fill"
    }

    private var topRightIcon: String {
        guard !context.items.isEmpty else { return "ellipsis" }
        if hasStagedItems { return "play.fill" }
        if activeItemCount > 0 { return "clock.fill" }
        if failedItemCount > 0 { return "exclamationmark" }
        if completedItemCount == context.items.count { return "checkmark" }
        return "ellipsis"
    }

    private var topRightHelp: String {
        if hasStagedItems { return "Choose batch action" }
        if activeItemCount > 0 { return "\(finishedItemCount) of \(context.items.count) finished" }
        if failedItemCount > 0 { return "\(failedItemCount) failed" }
        if completedItemCount == context.items.count, !context.items.isEmpty { return "All items complete" }
        return "No staged items"
    }

    private var hasStagedItems: Bool {
        context.items.contains { $0.state == .staged }
    }

    private var activeItemCount: Int {
        context.items.filter { $0.state == .queued || $0.state == .processing }.count
    }

    private var completedItemCount: Int {
        context.items.filter { $0.state == .completed }.count
    }

    private var failedItemCount: Int {
        context.items.filter { $0.state == .failed }.count
    }

    private var finishedItemCount: Int {
        completedItemCount + failedItemCount
    }

    private var completedOutputItems: [QuickAccessItem] {
        context.items.filter { outputURL(for: $0) != nil }
    }

    private var batchSizeComparisonText: String? {
        let outputItems = completedOutputItems.filter { $0.optimizedBytes != nil }
        guard !outputItems.isEmpty else { return nil }

        let originalBytes = outputItems.reduce(Int64(0)) { $0 + $1.originalBytes }
        let optimizedBytes = outputItems.reduce(Int64(0)) { $0 + ($1.optimizedBytes ?? $1.originalBytes) }
        return "\(ByteCountFormatter.droplitString(fromByteCount: originalBytes)) -> \(ByteCountFormatter.droplitString(fromByteCount: optimizedBytes))"
    }

    private func outputURL(for item: QuickAccessItem) -> URL? {
        guard item.state == .completed,
              let outputURL = item.outputURL,
              FileManager.default.fileExists(atPath: outputURL.path) else {
            return nil
        }
        return outputURL
    }

    private var showsPreviewStack: Bool {
        !context.items.isEmpty
    }

    private var showsDropReceiver: Bool {
        context.pendingDropSummary != nil
            || isTargeted
            || (!showsPreviewStack && context.isDropPlaceholderVisible)
    }

    private var dropReceiverMovesWindowOnMouseDown: Bool {
        !showsPreviewStack && context.pendingDropSummary == nil
    }

    private func itemNoun(for count: Int) -> String {
        let singular = count == 1
        if context.items.allSatisfy(\.kind.isImageLike) { return singular ? "Image" : "Images" }
        if context.items.allSatisfy({ $0.kind == .video }) { return singular ? "Video" : "Videos" }
        if context.items.allSatisfy({ $0.kind == .pdf }) { return singular ? "PDF" : "PDFs" }
        return singular ? "File" : "Files"
    }

    private var latestItem: QuickAccessItem? { context.items.first }

    private var boxShape: RoundedRectangle { RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous) }

    private var boxBorder: some View {
        boxShape.strokeBorder(.white.opacity(isTargeted ? 0.18 : 0.08), lineWidth: isTargeted ? 1 : 0.8)
    }

    private var boxDragPassthroughRects: [CGRect] {
        var rects = [
            handlePassthroughRect(
                center: CGPoint(
                    x: Layout.chromeInset + Layout.chromeButtonSize / 2,
                    y: Layout.boxSize.height - Layout.chromeInset - Layout.chromeButtonSize / 2
                ),
                size: CGSize(width: 46, height: 46)
            ),
            handlePassthroughRect(
                center: CGPoint(
                    x: Layout.boxSize.width - Layout.chromeInset - Layout.chromeButtonSize / 2,
                    y: Layout.boxSize.height - Layout.chromeInset - Layout.chromeButtonSize / 2
                ),
                size: CGSize(width: 46, height: 46)
            )
        ]

        if showsPreviewStack {
            rects.append(
                handlePassthroughRect(
                    center: CGPoint(x: Layout.boxSize.width / 2, y: Layout.boxSize.height / 2),
                    size: CGSize(width: 160, height: 146)
                )
            )
            rects.append(
                handlePassthroughRect(
                    center: CGPoint(x: Layout.boxSize.width / 2, y: Layout.countPillBottomInset + Layout.countPillHeight / 2),
                    size: CGSize(width: 146, height: 42)
                )
            )
        }

        return rects
    }

    private func handlePassthroughRect(center: CGPoint, size: CGSize) -> CGRect {
        CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

private extension QuickAccessFileKind {
    var isImageLike: Bool {
        switch self {
        case .png, .jpeg, .gif, .image:
            return true
        case .video, .pdf, .unknown:
            return false
        }
    }
}

private struct QuickAccessBoxDragHandleView: NSViewRepresentable {
    let passthroughRects: [CGRect]

    func makeNSView(context: Context) -> QuickAccessBoxDragHandleNSView {
        let view = QuickAccessBoxDragHandleNSView()
        view.passthroughRects = passthroughRects
        return view
    }

    func updateNSView(_ nsView: QuickAccessBoxDragHandleNSView, context: Context) {
        nsView.passthroughRects = passthroughRects
    }
}

private final class QuickAccessBoxDragHandleNSView: NSView {
    var passthroughRects: [CGRect] = []

    override var mouseDownCanMoveWindow: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        passthroughRects.contains { $0.contains(point) } ? nil : super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
