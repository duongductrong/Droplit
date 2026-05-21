import AppKit
import SwiftUI

private enum QuickAccessCardDragMode {
    case undetermined
    case swipeToDismiss
    case externalDrag
    case unavailable
}

struct QuickAccessCardView: View, Equatable {
    let item: QuickAccessItem
    let position: QuickAccessPosition
    let onRemove: (UUID) -> Void
    let onOpen: (UUID) -> Void
    let onReveal: (UUID) -> Void
    let onConvert: (UUID, QuickAccessConversionTarget) -> Void
    let reduceMotion: Bool
    @State private var isHovering = false
    @State private var isDismissing = false
    @State private var isDraggingToDismiss = false
    @State private var isDraggingExternally = false
    @State private var dragMode: QuickAccessCardDragMode = .undetermined
    @State private var swipeOffset: CGFloat = 0
    @State private var dismissTask: Task<Void, Never>?

    private let dragDirectionThreshold: CGFloat = 30
    private let swipeDismissThreshold: CGFloat = 74
    private let swipeVelocityThreshold: CGFloat = 320

    static func == (lhs: QuickAccessCardView, rhs: QuickAccessCardView) -> Bool {
        lhs.position == rhs.position
            && lhs.reduceMotion == rhs.reduceMotion
            && lhs.item.rendersSameQuickAccessCard(as: rhs.item)
    }

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
        .gesture(cardDragGesture)
        .onDisappear {
            isDraggingToDismiss = false
            isDraggingExternally = false
            dragMode = .undetermined
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
                case .staged:
                    stagedOverlay
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
        .quickAccessCardShadow(isRaised: isHovering)
        .scaleEffect(isHovering && !reduceMotion ? 1.008 : 1)
        .quickAccessCursor(isDraggingToDismiss || isDraggingExternally ? .closedHand : .pointingHand)
        .onHover { hovering in
            withAnimation(QuickAccessAnimations.hoverOverlay) {
                isHovering = hovering
            }
        }
        .onTapGesture(count: 2) {
            onOpen(item.id)
        }
        .contextMenu {
            Button(item.outputURL == nil ? "Open Original" : "Open Preview") {
                onOpen(item.id)
            }
            if item.outputURL != nil {
                Button("Reveal in Finder") {
                    onReveal(item.id)
                }
            }
            Button("Remove") {
                onRemove(item.id)
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
            onConvert(item.id, target)
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
                    .foregroundColor(conversionButtonForeground(isActive: isActive))
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

    private func conversionButtonBackground(isActive: Bool) -> Color {
        if isActive {
            return Self.accentColor
        }

        return DroplitCompatibility.controlFallbackColor.opacity(item.state == .processing ? 0.54 : 0.86)
    }

    private func conversionButtonBorder(isActive: Bool) -> Color {
        isActive ? Self.accentColor.opacity(0.88) : .white.opacity(item.state == .processing ? 0.10 : 0.20)
    }

    private static var accentColor: Color {
        Color(accentNSColor)
    }

    private static var accentNSColor: NSColor {
        if #available(macOS 10.14, *) {
            return .controlAccentColor
        }
        return .systemBlue
    }

    private var cardOpacity: Double {
        if isDraggingExternally {
            return 0.62
        }
        guard !reduceMotion else { return isDismissing ? 0 : 1 }
        let minimumOpacity = isDismissing ? 0 : 0.32
        return max(minimumOpacity, 1 - Double(abs(swipeOffset)) / 190)
    }

    private var cardDragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !isDismissing else { return }
                resolveDragModeIfNeeded(for: value.translation)

                if dragMode == .swipeToDismiss {
                    isDraggingToDismiss = true
                    swipeOffset = reduceMotion ? 0 : value.translation.width
                }
            }
            .onEnded { value in
                guard !isDismissing else { return }

                if dragMode == .swipeToDismiss {
                    finishSwipeDismiss(value)
                } else {
                    resetSwipeState()
                }
                dragMode = .undetermined
            }
    }

    private func resolveDragModeIfNeeded(for translation: CGSize) {
        guard dragMode == .undetermined,
              hypot(translation.width, translation.height) > dragDirectionThreshold else {
            return
        }

        if isDismissTranslation(translation) {
            dragMode = .swipeToDismiss
        } else if beginExternalDragIfPossible() {
            dragMode = .externalDrag
        } else {
            dragMode = .unavailable
        }
    }

    private func isDismissTranslation(_ translation: CGSize) -> Bool {
        let horizontalDominance = abs(translation.width) >= max(abs(translation.height) * 0.75, 12)
        return horizontalDominance && translation.width * position.dismissDirection > 0
    }

    private func finishSwipeDismiss(_ value: DragGesture.Value) {
        isDraggingToDismiss = false

        let translation = value.translation.width
        let shouldDismiss = isDismissTranslation(value.translation)
            && (abs(translation) > swipeDismissThreshold || abs(value.predictedEndTranslation.width) > swipeVelocityThreshold)

        if shouldDismiss {
            dismissCard(inDirection: translation == 0 ? position.dismissDirection : translation)
        } else {
            resetSwipeState()
        }
    }

    private func resetSwipeState() {
        isDraggingToDismiss = false
        if reduceMotion {
            swipeOffset = 0
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                swipeOffset = 0
            }
        }
    }

    private func beginExternalDragIfPossible() -> Bool {
        guard let dragURL = item.preferredExternalDragURL else { return false }

        isDraggingExternally = true
        let didBegin = QuickAccessExternalDragSession.begin(
            fileURL: dragURL,
            thumbnail: item.thumbnail
        ) { success in
            isDraggingExternally = false
            if success, item.removesAfterExternalDrag {
                onRemove(item.id)
            }
        }

        if !didBegin {
            isDraggingExternally = false
        }
        return didBegin
    }

    private func dismissCard(inDirection direction: CGFloat) {
        dismissTask?.cancel()
        isDismissing = true

        if reduceMotion {
            onRemove(item.id)
            return
        }

        let exitDirection: CGFloat = direction < 0 ? -1 : 1
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            swipeOffset = exitDirection * (QuickAccessLayout.cardWidth + QuickAccessLayout.containerPadding)
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 110_000_000)
            guard !Task.isCancelled else { return }
            onRemove(item.id)
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
            .overlay(Color.black.opacity(item.state.isWaitingOrProcessing ? 0.34 : 0.20))
    }

    private var readabilityOverlay: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .black.opacity(0.30), location: 0),
                    .init(color: .black.opacity(0.10), location: 0.22),
                    .init(color: .clear, location: 0.50)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Self.accentColor.opacity(0.18), location: 0),
                    .init(color: Self.accentColor.opacity(0.07), location: 0.26),
                    .init(color: .clear, location: 0.54)
                ]),
                startPoint: .topLeading,
                endPoint: .center
            )

            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.36),
                    .init(color: .black.opacity(0.66), location: 1)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }

    private var topControls: some View {
        HStack(alignment: .center) {
            Button {
                onRemove(item.id)
            } label: {
                Image(systemName: item.state == .processing ? "stop.fill" : "xmark")
                    .font(.system(size: QuickAccessLayout.closeButtonIconSize, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(
                        width: QuickAccessLayout.closeButtonVisualSize,
                        height: QuickAccessLayout.closeButtonVisualSize
                    )
                    .droplitMaterialBackground(.regular, in: Circle())
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
                .foregroundColor(.secondary)
                .frame(
                    width: QuickAccessLayout.kindBadgeWidth,
                    height: QuickAccessLayout.kindBadgeHeight
                )
                .droplitMaterialBackground(
                    .regular,
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
                .foregroundColor(.white.opacity(0.82))
                .lineLimit(1)
                .truncationMode(.middle)

            Text(item.activeOperationName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            ProgressBar(progress: displayProgress)
                .frame(height: 2.5)

            Text(processingTimeText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.86))
                .droplitMonospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
    }

    private var queuedOverlay: some View {
        waitingOverlay(title: "Queued", systemImage: "clock")
    }

    private var stagedOverlay: some View {
        waitingOverlay(title: "Ready", systemImage: "tray.full")
    }

    private func waitingOverlay(title: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.displayTitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.82))
                .lineLimit(1)
                .truncationMode(.middle)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                Text(item.originalSizeText)
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.86))
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
                .foregroundColor(.white)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(item.originalSizeText)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .semibold))
                Text(item.optimizedSizeText)
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.88))
            .droplitMonospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)

            Text(item.dimensionsText)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .droplitMonospacedDigit()
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
                .foregroundColor(.white)
                .lineLimit(1)

            Text(item.failureMessage ?? "Optimizer unavailable")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.74))
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
        if let progress {
            return totalWidth * CGFloat(min(max(progress, 0.05), 1))
        }
        return totalWidth * phase
    }
}

private extension QuickAccessJobState {
    var isWaitingOrProcessing: Bool {
        switch self {
        case .staged, .queued, .processing:
            return true
        case .completed, .failed:
            return false
        }
    }
}

private extension QuickAccessItem {
    func rendersSameQuickAccessCard(as other: QuickAccessItem) -> Bool {
        id == other.id
            && sourceURL == other.sourceURL
            && kind == other.kind
            && thumbnail === other.thumbnail
            && originalBytes == other.originalBytes
            && mediaDuration == other.mediaDuration
            && state == other.state
            && elapsed == other.elapsed
            && progress == other.progress
            && optimizedBytes == other.optimizedBytes
            && outputURL == other.outputURL
            && pixelSize == other.pixelSize
            && failureMessage == other.failureMessage
            && activeOperationName == other.activeOperationName
            && activeConversionTarget == other.activeConversionTarget
    }
}

struct QuickAccessCardShadowModifier: ViewModifier {
    let isRaised: Bool

    func body(content: Content) -> some View {
        content
            .shadow(
                color: .black.opacity(isRaised ? 0.11 : 0.08),
                radius: isRaised ? 34 : 29,
                x: 0,
                y: isRaised ? 15 : 12
            )
            .shadow(
                color: .black.opacity(isRaised ? 0.055 : 0.04),
                radius: isRaised ? 11 : 8,
                x: 0,
                y: isRaised ? 4 : 3
            )
    }
}

extension View {
    func quickAccessCardShadow(isRaised: Bool) -> some View {
        modifier(QuickAccessCardShadowModifier(isRaised: isRaised))
    }
}
