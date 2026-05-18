import SwiftUI

struct QuickAccessDropZoneCardView: View {
    @ObservedObject var manager: QuickAccessManager
    @State private var isTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            cardBackground

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 10) {
                    dropGlyph

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isTargeted ? "Release to optimize" : "Drop to optimize")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text(isTargeted ? "Droplit starts working here" : "Pinned here while Droplit works")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .scaleEffect(isTargeted && !reduceMotion ? 1.012 : 1)
            .animation(QuickAccessAnimations.hoverOverlay, value: isTargeted)

            QuickAccessDropReceiverView(isTargeted: $isTargeted) { urls in
                manager.ingestDroppedURLs(urls)
            }
        }
        .frame(width: QuickAccessLayout.cardWidth, height: QuickAccessLayout.cardHeight)
        .clipShape(cardShape)
        .compositingGroup()
        .quickAccessCardShadow(isRaised: isTargeted)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: QuickAccessLayout.cornerRadius, style: .continuous)
    }

    private var cardBackground: some View {
        ZStack {
            cardShape
                .fill(.ultraThinMaterial)

            cardShape
                .fill(.white.opacity(isTargeted ? 0.11 : 0.06))
        }
        .overlay(border)
    }

    private var dropGlyph: some View {
        Image(systemName: isTargeted ? "tray.full.fill" : "tray.and.arrow.down.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isTargeted ? .primary : .secondary)
            .frame(width: 34, height: 28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(isTargeted ? 0.22 : 0.14), lineWidth: 1)
            )
    }

    private var border: some View {
        ZStack {
            cardShape
                .strokeBorder(.white.opacity(isTargeted ? 0.24 : 0.16), lineWidth: isTargeted ? 1.3 : 1)

            cardShape
                .strokeBorder(.white.opacity(isTargeted ? 0.10 : 0.05), lineWidth: 1)
                .padding(1)
        }
    }
}
