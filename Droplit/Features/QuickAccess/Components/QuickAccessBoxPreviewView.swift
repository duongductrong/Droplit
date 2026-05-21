import AppKit
import SwiftUI

struct QuickAccessBoxPreviewView: View {
    let items: [QuickAccessItem]
    let isTargeted: Bool
    let reduceMotion: Bool
    let onExternalDragCompleted: () -> Void

    var body: some View {
        ZStack {
            ForEach(layersBackToFront) { layer in
                QuickAccessBoxPreviewLayerView(
                    layer: layer,
                    onExternalDragCompleted: onExternalDragCompleted
                )
                    .rotationEffect(.degrees(layer.rotation))
                    .offset(layer.offset)
            }
        }
        .frame(width: 126, height: 112)
        .scaleEffect(isTargeted && !reduceMotion ? 1.035 : 1)
    }

    private var layersBackToFront: [QuickAccessBoxPreviewLayer] {
        let visibleItems = Array(items.prefix(3))

        switch visibleItems.count {
        case 0:
            return []
        case 1:
            return [
                layer(
                    for: visibleItems[0],
                    size: CGSize(width: 96, height: 72),
                    rotation: -3,
                    offset: CGSize(width: 0, height: 0)
                )
            ]
        case 2:
            return [
                layer(
                    for: visibleItems[1],
                    size: CGSize(width: 86, height: 90),
                    rotation: -12,
                    offset: CGSize(width: -18, height: -9)
                ),
                layer(
                    for: visibleItems[0],
                    size: CGSize(width: 96, height: 72),
                    rotation: 6,
                    offset: CGSize(width: 14, height: 9)
                )
            ]
        default:
            return [
                layer(
                    for: visibleItems[2],
                    size: CGSize(width: 80, height: 90),
                    rotation: 14,
                    offset: CGSize(width: 18, height: -12)
                ),
                layer(
                    for: visibleItems[1],
                    size: CGSize(width: 88, height: 90),
                    rotation: -10,
                    offset: CGSize(width: -18, height: -7)
                ),
                layer(
                    for: visibleItems[0],
                    size: CGSize(width: 96, height: 70),
                    rotation: 5,
                    offset: CGSize(width: 10, height: 11)
                )
            ]
        }
    }

    private func layer(
        for item: QuickAccessItem,
        size: CGSize,
        rotation: Double,
        offset: CGSize
    ) -> QuickAccessBoxPreviewLayer {
        QuickAccessBoxPreviewLayer(
            item: item,
            size: size,
            rotation: rotation,
            offset: offset,
            cornerRadius: 8
        )
    }
}

private struct QuickAccessBoxPreviewLayer: Identifiable {
    let item: QuickAccessItem
    let size: CGSize
    let rotation: Double
    let offset: CGSize
    let cornerRadius: CGFloat

    var id: UUID { item.id }

    var helpText: String {
        item.usesOptimizedExternalDragURL ? "Drag optimized output" : "Drag original file"
    }
}

private struct QuickAccessBoxPreviewLayerView: View {
    let layer: QuickAccessBoxPreviewLayer
    let onExternalDragCompleted: () -> Void
    @State private var isDraggingExternally = false

    var body: some View {
        QuickAccessBoxPreviewItemCard(layer: layer)
            .opacity(isDraggingExternally ? 0.62 : 1)
            .contentShape(RoundedRectangle(cornerRadius: layer.cornerRadius, style: .continuous))
            .gesture(externalDragGesture)
            .help(layer.helpText)
            .quickAccessCursor(isDraggingExternally ? .closedHand : .pointingHand)
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
        guard let dragURL = layer.item.preferredExternalDragURL else { return }

        isDraggingExternally = true
        let didBegin = QuickAccessExternalDragSession.begin(
            fileURL: dragURL,
            thumbnail: layer.item.thumbnail
        ) { success in
            isDraggingExternally = false
            if success {
                onExternalDragCompleted()
            }
        }

        if !didBegin {
            isDraggingExternally = false
        }
    }
}

private struct QuickAccessBoxPreviewItemCard: View {
    let layer: QuickAccessBoxPreviewLayer

    var body: some View {
        Image(nsImage: layer.item.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: layer.size.width, height: layer.size.height)
            .clipShape(RoundedRectangle(cornerRadius: layer.cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: layer.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.17), radius: 11, x: 0, y: 6)
            .shadow(color: .black.opacity(0.10), radius: 3, x: 0, y: 1)
    }
}
