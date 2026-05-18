import SwiftUI

struct OnboardingReadyQuickAccessPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: OnboardingReadyPreviewPhase = .idle
    @State private var progress: CGFloat = 0.18

    var body: some View {
        ZStack {
            fileBundle
                .offset(bundleOffset)
                .scaleEffect(phase == .dragging ? 0.9 : 1)
                .opacity(phase == .processing ? 0 : 1)

            activeCardPreview
                .offset(y: 14)

            Image(systemName: "cursorarrow")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
                .offset(cursorOffset)
                .opacity(phase == .processing ? 0 : 1)
        }
        .frame(width: 420, height: 236)
        .task(id: reduceMotion) { await runPreviewLoop() }
        .accessibilityElement(children: .combine).accessibilityLabel("Drop media into Quick Access to start processing")
    }

    private var bundleOffset: CGSize {
        switch phase {
        case .idle:
            return CGSize(width: -118, height: -82)
        case .dragging:
            return CGSize(width: -10, height: -30)
        case .processing:
            return CGSize(width: -10, height: -30)
        }
    }

    private var cursorOffset: CGSize {
        switch phase {
        case .idle:
            return CGSize(width: -38, height: -66)
        case .dragging:
            return CGSize(width: 68, height: -12)
        case .processing:
            return CGSize(width: 68, height: -12)
        }
    }

    private var fileBundle: some View {
        HStack(spacing: 8) {
            OnboardingReadyFileChip(title: "Image", systemImage: "photo.fill")
            OnboardingReadyFileChip(title: "Video", systemImage: "video.fill")
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.055), radius: 18, y: 8)
    }

    @ViewBuilder
    private var activeCardPreview: some View {
        if phase == .processing {
            OnboardingQuickAccessDemoStack(progress: progress)
                .transition(.opacity)
        } else {
            OnboardingQuickAccessDemoCard(
                isProcessing: false,
                isTargeted: phase == .dragging,
                progress: progress
            )
            .transition(.opacity)
        }
    }

    private func runPreviewLoop() async {
        if reduceMotion {
            setPreview(.processing, progress: 0.62)
            return
        }

        while !Task.isCancelled {
            setPreview(.idle, progress: 0.18, animation: .easeOut(duration: 0.18))
            try? await Task.sleep(nanoseconds: 780_000_000)
            setPreview(.dragging, progress: 0.18, animation: .spring(response: 0.62, dampingFraction: 0.86))
            try? await Task.sleep(nanoseconds: 680_000_000)
            setPreview(.processing, progress: 0.62, animation: .easeInOut(duration: 0.24))
            try? await Task.sleep(nanoseconds: 1_650_000_000)
        }
    }

    private func setPreview(_ newPhase: OnboardingReadyPreviewPhase, progress newProgress: CGFloat, animation: Animation? = nil) {
        withAnimation(animation) {
            phase = newPhase
            progress = newProgress
        }
    }
}

private struct OnboardingReadyFileChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
    }
}
