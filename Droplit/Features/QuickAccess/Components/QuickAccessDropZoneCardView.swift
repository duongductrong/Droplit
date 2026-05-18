import SwiftUI

struct QuickAccessDropZoneCardView: View {
    @ObservedObject var manager: QuickAccessManager
    @State private var isTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            cardShape
                .fill(.regularMaterial)
                .overlay(backgroundTone)
                .overlay(border)

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.doc")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(.regularMaterial, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))

                    Spacer()

                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(.white.opacity(0.20), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 7)
                .padding(.top, 7)

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text(isTargeted ? "Release to optimize" : "Drop to optimize")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("Droplit keeps the card here while it works")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
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

    private var backgroundTone: some View {
        cardShape
            .fill(isTargeted ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
    }

    private var border: some View {
        cardShape
            .strokeBorder(
                isTargeted ? Color.primary.opacity(0.24) : Color.primary.opacity(0.12),
                lineWidth: isTargeted ? 1.5 : 1
            )
    }
}
