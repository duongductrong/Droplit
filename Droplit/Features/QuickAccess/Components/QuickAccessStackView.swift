import AppKit
import SwiftUI

struct QuickAccessStackView: View {
    let context: QuickAccessPresentationContext
    let actions: QuickAccessPresentationActions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: QuickAccessLayout.cardSpacing) {
            if context.position.isTopEdge {
                positionedCards
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                positionedCards
            }
        }
        .padding(QuickAccessLayout.containerPadding)
        .frame(
            width: panelSize.width,
            height: panelSize.height
        )
    }

    private var panelSize: CGSize {
        QuickAccessLayout.fixedStackPanelSize(
            includesDropPlaceholder: context.isDropPlaceholderVisible
        )
    }

    @ViewBuilder
    private var positionedCards: some View {
        if context.position.isTopEdge {
            if context.isDropPlaceholderVisible {
                QuickAccessDropZoneCardView(onDrop: actions.ingestDroppedURLs)
                    .transition(cardTransition)
            }

            ForEach(stackItemsInVisualOrder) { item in
                cardView(for: item)
            }

            if hasOverflowCard {
                QuickAccessOverflowCardView(
                    summary: overflowSummary,
                    dragBundle: overflowDragBundle,
                    onRemove: actions.removeItem,
                    reduceMotion: reduceMotion
                )
                    .transition(cardTransition)
            }
        } else {
            if hasOverflowCard {
                QuickAccessOverflowCardView(
                    summary: overflowSummary,
                    dragBundle: overflowDragBundle,
                    onRemove: actions.removeItem,
                    reduceMotion: reduceMotion
                )
                    .transition(cardTransition)
            }

            ForEach(stackItemsInVisualOrder) { item in
                cardView(for: item)
            }

            if context.isDropPlaceholderVisible {
                QuickAccessDropZoneCardView(onDrop: actions.ingestDroppedURLs)
                    .transition(cardTransition)
            }
        }
    }

    private func cardView(for item: QuickAccessItem) -> some View {
        QuickAccessCardView(
            item: item,
            position: context.position,
            onRemove: actions.removeItem,
            onOpen: actions.openItem,
            onReveal: actions.revealOutput,
            onConvert: actions.convertItem,
            reduceMotion: reduceMotion
        )
        .equatable()
        .transition(cardTransition)
    }

    private var cardTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: transitionEdge)
                .combined(with: .opacity),
            removal: .move(edge: transitionEdge)
                .combined(with: .opacity)
        )
    }

    private var transitionEdge: Edge {
        if context.position.isTopEdge {
            return .top
        }

        switch context.position.alignment {
        case .left:
            return .leading
        case .center:
            return .bottom
        case .right:
            return .trailing
        }
    }

    private var stackItemsInVisualOrder: [QuickAccessItem] {
        if context.position.isTopEdge {
            return stackItems
        }
        return Array(stackItems.reversed())
    }

    private var stackItems: [QuickAccessItem] {
        QuickAccessStackPresentationStyle().stackItems(in: context)
    }

    private var hiddenStackItemCount: Int {
        max(context.items.count - stackItems.count, 0)
    }

    private var hasOverflowCard: Bool {
        hiddenStackItemCount > 0
    }

    private var overflowSummary: QuickAccessOverflowSummary {
        QuickAccessOverflowSummary(
            hiddenCount: hiddenStackItemCount,
            stagedCount: countItems(in: .staged),
            processingCount: countItems(in: .processing),
            queuedCount: countItems(in: .queued),
            completedCount: countItems(in: .completed),
            failedCount: countItems(in: .failed)
        )
    }

    private var overflowDragBundle: QuickAccessStackExternalDragBundle? {
        let entries = context.items.compactMap { item -> QuickAccessStackExternalDragEntry? in
            guard let fileURL = item.preferredExternalDragURL else { return nil }
            return QuickAccessStackExternalDragEntry(
                id: item.id,
                fileURL: fileURL,
                thumbnail: item.thumbnail,
                removesAfterDrag: item.removesAfterExternalDrag
            )
        }
        guard let firstEntry = entries.first else { return nil }

        return QuickAccessStackExternalDragBundle(
            fileURLs: entries.map(\.fileURL),
            removableItemIDs: entries.filter(\.removesAfterDrag).map(\.id),
            thumbnail: firstEntry.thumbnail
        )
    }

    private func countItems(in state: QuickAccessJobState) -> Int {
        context.items.filter { $0.state == state }.count
    }
}

private struct QuickAccessStackExternalDragEntry {
    let id: UUID
    let fileURL: URL
    let thumbnail: NSImage
    let removesAfterDrag: Bool
}

private struct QuickAccessStackExternalDragBundle {
    let fileURLs: [URL]
    let removableItemIDs: [UUID]
    let thumbnail: NSImage
}

private struct QuickAccessOverflowSummary: Equatable {
    let hiddenCount: Int
    let stagedCount: Int
    let processingCount: Int
    let queuedCount: Int
    let completedCount: Int
    let failedCount: Int
}

private struct QuickAccessOverflowCardView: View {
    let summary: QuickAccessOverflowSummary
    let dragBundle: QuickAccessStackExternalDragBundle?
    let onRemove: (UUID) -> Void
    let reduceMotion: Bool
    @State private var isHovering = false
    @State private var isDraggingExternally = false

    var body: some View {
        ZStack {
            background
            readabilityOverlay

            VStack(spacing: 0) {
                topBadge
                Spacer(minLength: 0)
                summaryContent
            }
        }
        .frame(width: QuickAccessLayout.cardWidth, height: QuickAccessLayout.overflowCardHeight)
        .clipShape(cardShape)
        .overlay(cardShape.strokeBorder(.white.opacity(0.16), lineWidth: 1))
        .compositingGroup()
        .quickAccessCardShadow(isRaised: isHovering)
        .opacity(isDraggingExternally ? 0.62 : 1)
        .scaleEffect(isHovering && !reduceMotion ? 1.008 : 1)
        .contentShape(cardShape)
        .gesture(externalDragGesture)
        .help(dragHelpText)
        .quickAccessCursor(isDraggingExternally ? .closedHand : .pointingHand)
        .onHover { hovering in
            withAnimation(QuickAccessAnimations.hoverOverlay) {
                isHovering = hovering
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .black.opacity(0.80),
                    .black.opacity(0.50)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.white.opacity(Double(3 - index) * 0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
                    .frame(
                        width: QuickAccessLayout.cardWidth - CGFloat(index * 18) - 26,
                        height: 28
                    )
                    .offset(x: CGFloat(index * 7), y: CGFloat(index * 10) - 18)
                    .rotationEffect(.degrees(Double(index - 1) * 2.4))
            }
        }
        .frame(width: QuickAccessLayout.cardWidth, height: QuickAccessLayout.overflowCardHeight)
        .clipped()
        .overlay(Color.black.opacity(0.22))
    }

    private var readabilityOverlay: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.08),
                .clear,
                .black.opacity(0.70)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var topBadge: some View {
        HStack(alignment: .top) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 20)
                .droplitMaterialBackground(.regular, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white.opacity(0.20), lineWidth: 1)
                )

            Spacer()

            Text("+\(summary.hiddenCount)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .droplitMonospacedDigit()
                .frame(minWidth: 28)
                .frame(height: 20)
                .padding(.horizontal, 4)
                .droplitMaterialBackground(.regular, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 1))
        }
        .padding(.horizontal, 7)
        .padding(.top, 7)
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(summary.hiddenCount) hidden")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.82))
                .lineLimit(1)

            Text("Stacked items")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(summaryText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: QuickAccessLayout.cornerRadius, style: .continuous)
    }

    private var externalDragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !isDraggingExternally,
                      hypot(value.translation.width, value.translation.height) > 8 else {
                    return
                }
                beginExternalDragIfPossible()
            }
    }

    private func beginExternalDragIfPossible() {
        guard let dragBundle else { return }

        isDraggingExternally = true
        let didBegin = QuickAccessExternalDragSession.begin(
            fileURLs: dragBundle.fileURLs,
            thumbnail: dragBundle.thumbnail
        ) { success in
            isDraggingExternally = false
            if success {
                dragBundle.removableItemIDs.forEach(onRemove)
            }
        }

        if !didBegin {
            isDraggingExternally = false
        }
    }

    private var dragHelpText: String {
        guard let dragBundle else { return "\(summary.hiddenCount) hidden items" }
        return dragBundle.fileURLs.count == 1
            ? "Drag available file"
            : "Drag \(dragBundle.fileURLs.count) available files"
    }

    private var summaryText: String {
        let parts = [
            labeledCount(summary.stagedCount, "ready"),
            labeledCount(summary.processingCount, "processing"),
            labeledCount(summary.queuedCount, "queued"),
            labeledCount(summary.completedCount, "done"),
            labeledCount(summary.failedCount, "failed")
        ].compactMap { $0 }
        return parts.isEmpty ? "Queue active" : parts.joined(separator: " · ")
    }

    private func labeledCount(_ count: Int, _ label: String) -> String? {
        count > 0 ? "\(count) \(label)" : nil
    }
}
