import SwiftUI

enum OnboardingReadyPreviewPhase {
    case idle
    case dragging
    case processing
}

struct OnboardingQuickAccessDemoCard: View {
    let isProcessing: Bool
    let isTargeted: Bool
    let progress: CGFloat
    var title = "Media package"
    var elapsedText = "0.642s"
    var kindSymbols = ["photo.fill", "video.fill"]

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                topControls
                Spacer(minLength: 0)
                if isProcessing {
                    processingContent.transition(.opacity)
                } else {
                    placeholderContent.transition(.opacity)
                }
            }
        }
        .frame(width: QuickAccessLayout.cardWidth, height: QuickAccessLayout.cardHeight)
        .clipShape(cardShape)
        .compositingGroup()
        .quickAccessCardShadow(isRaised: isProcessing || isTargeted)
        .animation(.easeInOut(duration: 0.22), value: isProcessing)
        .animation(QuickAccessAnimations.hoverOverlay, value: isTargeted)
    }

    private var background: some View {
        ZStack {
            cardShape.fill(.ultraThinMaterial)
            cardShape.fill(Color.primary.opacity(backgroundOpacity))
        }
        .overlay(cardShape.strokeBorder(Color.primary.opacity(borderOpacity), lineWidth: isTargeted ? 1.2 : 1))
    }

    private var topControls: some View {
        HStack {
            Circle()
                .fill(.regularMaterial)
                .frame(width: QuickAccessLayout.closeButtonVisualSize, height: QuickAccessLayout.closeButtonVisualSize)
                .overlay(
                    Image(systemName: isProcessing ? "stop.fill" : "xmark")
                        .font(.system(size: QuickAccessLayout.closeButtonIconSize, weight: .semibold))
                        .foregroundStyle(.secondary)
                )
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
            Spacer()
            HStack(spacing: 4) {
                ForEach(kindSymbols, id: \.self) { symbol in
                    Image(systemName: symbol)
                }
            }
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: QuickAccessLayout.kindBadgeWidth + 12, height: QuickAccessLayout.kindBadgeHeight)
            .background(.regularMaterial, in: kindBadgeShape)
            .overlay(kindBadgeShape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
        }
        .padding(.horizontal, QuickAccessLayout.topControlHorizontalPadding)
        .padding(.top, QuickAccessLayout.topControlTopPadding)
    }

    private var placeholderContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: isTargeted ? "tray.full.fill" : "tray.and.arrow.down.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isTargeted ? .primary : .secondary)
                .frame(width: 34, height: 28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
            VStack(alignment: .leading, spacing: 4) {
                Text(isTargeted ? "Release to optimize" : "Drop to optimize")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text("Images and videos")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var processingContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("Optimizing")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.16))
                    Capsule().fill(Color.primary.opacity(0.64)).frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 2.5)
            Text(elapsedText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
    }

    private var backgroundOpacity: Double {
        isProcessing ? 0.075 : (isTargeted ? 0.065 : 0.045)
    }

    private var borderOpacity: Double {
        isTargeted ? 0.18 : (isProcessing ? 0.15 : 0.10)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: QuickAccessLayout.cornerRadius, style: .continuous)
    }

    private var kindBadgeShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: QuickAccessLayout.kindBadgeCornerRadius, style: .continuous)
    }
}

struct OnboardingQuickAccessDemoStack: View {
    let progress: CGFloat

    private let visibleHeight: CGFloat = QuickAccessLayout.cardHeight + QuickAccessLayout.cardSpacing + 58

    var body: some View {
        VStack(spacing: QuickAccessLayout.cardSpacing) {
            ForEach(Array(Self.items.enumerated()), id: \.offset) { index, item in
                OnboardingQuickAccessDemoCard(
                    isProcessing: true,
                    isTargeted: false,
                    progress: max(progress - CGFloat(index) * 0.12, 0.20),
                    title: item.title,
                    elapsedText: item.elapsedText,
                    kindSymbols: item.kindSymbols
                )
                .opacity(1 - Double(index) * 0.08)
            }
        }
        .frame(
            width: QuickAccessLayout.cardWidth,
            height: visibleHeight,
            alignment: .top
        )
        .mask(stackMask)
        .clipped()
    }

    private var stackMask: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.white)
            LinearGradient(
                colors: [.white, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 18)
        }
    }

    private static let items = [
        ProcessingStackItem(title: "Image set", elapsedText: "0.642s", kindSymbols: ["photo.fill"]),
        ProcessingStackItem(title: "Video clip", elapsedText: "0.391s", kindSymbols: ["video.fill"]),
        ProcessingStackItem(title: "GIF loop", elapsedText: "0.218s", kindSymbols: ["sparkles"])
    ]
}

private struct ProcessingStackItem {
    let title: String
    let elapsedText: String
    let kindSymbols: [String]
}
