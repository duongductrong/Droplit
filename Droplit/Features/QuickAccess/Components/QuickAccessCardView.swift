import AppKit
import SwiftUI

struct QuickAccessCardView: View {
    let item: QuickAccessItem
    @ObservedObject var manager: QuickAccessManager
    @State private var isHovering = false
    @State private var isDismissing = false
    @State private var isDraggingToDismiss = false
    @State private var swipeOffset: CGFloat = 0
    @State private var dismissTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let swipeDismissThreshold: CGFloat = 74
    private let swipeVelocityThreshold: CGFloat = 320

    var body: some View {
        VStack(spacing: QuickAccessLayout.conversionActionSpacing) {
            mediaCard
            conversionActions
        }
        .frame(
            width: QuickAccessLayout.cardWidth,
            height: QuickAccessLayout.itemHeight(hasConversionActions: item.hasConversionTargets)
        )
        .opacity(cardOpacity)
        .offset(x: reduceMotion ? 0 : swipeOffset)
        .rotationEffect(.degrees(reduceMotion ? 0 : Double(swipeOffset) * 0.035))
        .gesture(swipeDismissGesture)
        .onDisappear {
            isDraggingToDismiss = false
            dismissTask?.cancel()
        }
    }

    private var mediaCard: some View {
        ZStack {
            backgroundImage
            readabilityOverlay

            VStack(spacing: 0) {
                topControls
                Spacer(minLength: 0)

                switch item.state {
                case .queued:
                    queuedOverlay
                case .processing:
                    processingOverlay
                case .completed:
                    completedOverlay
                case .failed:
                    failedOverlay
                }
            }
        }
        .frame(width: QuickAccessLayout.cardWidth, height: QuickAccessLayout.cardHeight)
        .clipShape(cardShape)
        .overlay(cardShape.strokeBorder(.white.opacity(0.16), lineWidth: 1))
        .compositingGroup()
        .shadow(color: .black.opacity(isHovering ? 0.11 : 0.075), radius: isHovering ? 30 : 26, x: 0, y: isHovering ? 13 : 10)
        .shadow(color: .black.opacity(isHovering ? 0.08 : 0.055), radius: isHovering ? 12 : 9, x: 0, y: isHovering ? 5 : 4)
        .shadow(color: .black.opacity(isHovering ? 0.05 : 0.035), radius: isHovering ? 2.5 : 2, x: 0, y: 1)
        .scaleEffect(isHovering && !reduceMotion ? 1.008 : 1)
        .quickAccessCursor(isDraggingToDismiss ? .closedHand : .pointingHand)
        .onHover { hovering in
            withAnimation(QuickAccessAnimations.hoverOverlay) {
                isHovering = hovering
            }
        }
        .onTapGesture(count: 2) {
            manager.openItem(for: item.id)
        }
        .contextMenu {
            Button(item.outputURL == nil ? "Open Original" : "Open Preview") {
                manager.openItem(for: item.id)
            }
            if item.outputURL != nil {
                Button("Reveal in Finder") {
                    manager.revealOutput(for: item.id)
                }
            }
            Button("Remove") {
                manager.removeItem(id: item.id)
            }
        }
    }

    @ViewBuilder
    private var conversionActions: some View {
        if item.hasConversionTargets {
            HStack(spacing: QuickAccessLayout.conversionActionButtonSpacing) {
                ForEach(item.conversionTargets) { target in
                    conversionButton(for: target)
                }
            }
            .frame(width: QuickAccessLayout.cardWidth, height: QuickAccessLayout.conversionActionRowHeight)
        }
    }

    private func conversionButton(for target: QuickAccessConversionTarget) -> some View {
        let isActive = item.activeConversionTarget == target

        return Button {
            manager.convertItem(id: item.id, to: target)
        } label: {
            ZStack {
                Capsule()
                    .fill(conversionButtonBackground(isActive: isActive))

                if isActive {
                    Capsule()
                        .fill(.black.opacity(0.18))
                }

                Text(target.displayName)
                    .font(.system(size: QuickAccessLayout.conversionActionFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(conversionButtonForeground(isActive: isActive))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: QuickAccessLayout.conversionActionVisualHeight)
            .overlay(
                ZStack {
                    Capsule()
                        .stroke(conversionButtonBorder(isActive: isActive), lineWidth: isActive ? 1.2 : 1)
                    if isActive {
                        Capsule()
                            .stroke(.white.opacity(0.24), lineWidth: 1)
                            .padding(1)
                    }
                }
            )
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(height: QuickAccessLayout.conversionActionRowHeight)
        .opacity(item.state == .processing && !isActive ? 0.42 : 1)
        .disabled(item.state == .processing)
        .contentShape(Rectangle())
        .help("Convert original to \(target.displayName)")
        .quickAccessCursor(.pointingHand)
    }

    private func conversionButtonForeground(isActive: Bool) -> Color {
        if isActive {
            return .white
        }
        return item.state == .processing ? .secondary : .primary
    }

    private func conversionButtonBackground(isActive: Bool) -> some ShapeStyle {
        isActive ? AnyShapeStyle(Self.accentColor) : AnyShapeStyle(item.state == .processing ? .thinMaterial : .regularMaterial)
    }

    private func conversionButtonBorder(isActive: Bool) -> Color {
        isActive ? Self.accentColor.opacity(0.88) : .white.opacity(item.state == .processing ? 0.10 : 0.20)
    }

    private static var accentColor: Color {
        Color(nsColor: accentNSColor)
    }

    private static var accentNSColor: NSColor {
        if #available(macOS 10.14, *) {
            return .controlAccentColor
        }
        return .systemBlue
    }

    private var cardOpacity: Double {
        guard !reduceMotion else { return isDismissing ? 0 : 1 }
        let minimumOpacity = isDismissing ? 0 : 0.32
        return max(minimumOpacity, 1 - Double(abs(swipeOffset)) / 190)
    }

    private var swipeDismissGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !isDismissing else { return }
                isDraggingToDismiss = true

                if reduceMotion {
                    swipeOffset = 0
                } else {
                    swipeOffset = value.translation.width
                }
            }
            .onEnded { value in
                guard !isDismissing else { return }
                isDraggingToDismiss = false

                let translation = value.translation.width
                let isHorizontal = abs(translation) > abs(value.translation.height)
                let shouldDismiss = isHorizontal
                    && (abs(translation) > swipeDismissThreshold || abs(value.predictedEndTranslation.width) > swipeVelocityThreshold)

                if shouldDismiss {
                    dismissCard(inDirection: translation == 0 ? manager.position.dismissDirection : translation)
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        swipeOffset = 0
                    }
                }
            }
    }

    private func dismissCard(inDirection direction: CGFloat) {
        dismissTask?.cancel()
        isDismissing = true

        if reduceMotion {
            manager.removeItem(id: item.id)
            return
        }

        let exitDirection: CGFloat = direction < 0 ? -1 : 1
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            swipeOffset = exitDirection * (QuickAccessLayout.cardWidth + QuickAccessLayout.containerPadding)
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 110_000_000)
            guard !Task.isCancelled else { return }
            manager.removeItem(id: item.id)
        }
    }

    private var backgroundImage: some View {
        Image(nsImage: item.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: QuickAccessLayout.cardWidth, height: QuickAccessLayout.cardHeight)
            .clipped()
            .saturation(0.72)
            .brightness(-0.04)
            .overlay(.black.opacity(item.state == .processing || item.state == .queued ? 0.34 : 0.20))
    }

    private var readabilityOverlay: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.10),
                .clear,
                .black.opacity(0.64)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var topControls: some View {
        HStack(alignment: .center) {
            Button {
                manager.removeItem(id: item.id)
            } label: {
                Image(systemName: item.state == .processing ? "stop.fill" : "xmark")
                    .font(.system(size: QuickAccessLayout.closeButtonIconSize, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(
                        width: QuickAccessLayout.closeButtonVisualSize,
                        height: QuickAccessLayout.closeButtonVisualSize
                    )
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))
                    .frame(
                        width: QuickAccessLayout.closeButtonHitSize,
                        height: QuickAccessLayout.closeButtonHitSize
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help(item.state == .processing ? "Stop" : "Remove")
            .quickAccessCursor(.pointingHand)

            Spacer()

            Image(systemName: item.kind.systemImage)
                .font(.system(size: QuickAccessLayout.kindBadgeIconSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(
                    width: QuickAccessLayout.kindBadgeWidth,
                    height: QuickAccessLayout.kindBadgeHeight
                )
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: QuickAccessLayout.kindBadgeCornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: QuickAccessLayout.kindBadgeCornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.20), lineWidth: 1)
                )
        }
        .padding(.horizontal, QuickAccessLayout.topControlHorizontalPadding)
        .padding(.top, QuickAccessLayout.topControlTopPadding)
    }

    private var processingOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.displayTitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .truncationMode(.middle)

            Text(item.activeOperationName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            ProgressBar(progress: displayProgress)
                .frame(height: 2.5)

            Text(processingTimeText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
    }

    private var queuedOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.displayTitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .truncationMode(.middle)

            Text("Queued")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .semibold))
                Text(item.originalSizeText)
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.86))
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
    }

    private var completedOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Done")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(item.originalSizeText)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .semibold))
                Text(item.optimizedSizeText)
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.88))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)

            Text(item.dimensionsText)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
    }

    private var failedOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Failed")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(item.failureMessage ?? "Optimizer unavailable")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: QuickAccessLayout.cornerRadius, style: .continuous)
    }

    private var processingTimeText: String {
        if let duration = item.mediaDuration, duration > 0 {
            return "\(item.elapsed.timecode3) of \(duration.timecode3)"
        }
        return item.elapsed.timecode3
    }

    private var displayProgress: Double? {
        if let progress = item.progress {
            return progress
        }
        guard let duration = item.mediaDuration, duration > 0 else { return nil }
        return min(item.elapsed / duration, 0.94)
    }
}

private struct ProgressBar: View {
    let progress: Double?
    @State private var phase: CGFloat = 0.2
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.24))
                Capsule()
                    .fill(.white.opacity(0.76))
                    .frame(width: filledWidth(in: proxy.size.width))
            }
        }
        .onAppear {
            guard progress == nil, !reduceMotion else { return }
            withAnimation(QuickAccessAnimations.progressPulse) {
                phase = 0.82
            }
        }
    }

    private func filledWidth(in totalWidth: CGFloat) -> CGFloat {
        let value = progress.map { min(max($0, 0.05), 1) } ?? phase
        return totalWidth * value
    }
}
