import SwiftUI

struct QuickAccessStackView: View {
    @ObservedObject var manager: QuickAccessManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: QuickAccessLayout.cardSpacing) {
            Spacer(minLength: 0)

            if manager.hasOverflowCard {
                QuickAccessOverflowCardView(manager: manager)
                    .transition(cardTransition)
            }

            ForEach(manager.floatingItems) { item in
                QuickAccessCardView(item: item, manager: manager)
                    .id(item.id)
                    .transition(cardTransition)
            }

            if manager.isDropPlaceholderVisible {
                QuickAccessDropZoneCardView(manager: manager)
                    .transition(cardTransition)
            }
        }
        .padding(QuickAccessLayout.containerPadding)
        .frame(
            width: panelSize.width,
            height: panelSize.height
        )
    }

    private var panelSize: CGSize {
        QuickAccessLayout.panelSize(
            itemCardCount: manager.floatingItems.count,
            conversionActionRowCount: manager.floatingItems.filter(\.hasConversionTargets).count,
            dropPlaceholderCount: manager.isDropPlaceholderVisible ? 1 : 0,
            includesOverflowCard: manager.hasOverflowCard
        )
    }

    private var cardTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: manager.position.isLeftSide ? .leading : .trailing)
                .combined(with: .opacity),
            removal: .move(edge: manager.position.isLeftSide ? .leading : .trailing)
                .combined(with: .opacity)
        )
    }
}

private struct QuickAccessOverflowCardView: View {
    @ObservedObject var manager: QuickAccessManager
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .shadow(color: .black.opacity(isHovering ? 0.11 : 0.075), radius: isHovering ? 30 : 26, x: 0, y: isHovering ? 13 : 10)
        .shadow(color: .black.opacity(isHovering ? 0.08 : 0.055), radius: isHovering ? 12 : 9, x: 0, y: isHovering ? 5 : 4)
        .shadow(color: .black.opacity(isHovering ? 0.05 : 0.035), radius: isHovering ? 2.5 : 2, x: 0, y: 1)
        .scaleEffect(isHovering && !reduceMotion ? 1.008 : 1)
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
        .overlay(.black.opacity(0.22))
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
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white.opacity(0.20), lineWidth: 1)
                )

            Spacer()

            Text("+\(manager.hiddenFloatingItemCount)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .frame(minWidth: 28)
                .frame(height: 20)
                .padding(.horizontal, 4)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 1))
        }
        .padding(.horizontal, 7)
        .padding(.top, 7)
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(manager.hiddenFloatingItemCount) hidden")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)

            Text("Stacked items")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(summaryText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
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

    private var summaryText: String {
        let parts = [
            labeledCount(manager.processingCount, "processing"),
            labeledCount(manager.queuedCount, "queued"),
            labeledCount(manager.completedCount, "done"),
            labeledCount(manager.failedCount, "failed")
        ].compactMap { $0 }
        return parts.isEmpty ? "Queue active" : parts.joined(separator: " · ")
    }

    private func labeledCount(_ count: Int, _ label: String) -> String? {
        count > 0 ? "\(count) \(label)" : nil
    }
}
