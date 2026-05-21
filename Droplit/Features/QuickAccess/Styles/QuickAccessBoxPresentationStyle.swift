import SwiftUI

nonisolated struct QuickAccessBoxPresentationStyle: QuickAccessPresentationStyleProviding {
    let style: QuickAccessPresentationStyle = .box

    func metrics(for context: QuickAccessPresentationContext) -> QuickAccessPresentationMetrics {
        guard context.isDropPlaceholderVisible || !context.items.isEmpty else { return .empty }

        return QuickAccessPresentationMetrics(
            panelSize: QuickAccessBoxLayout.panelSize,
            activeContentHeight: QuickAccessBoxLayout.panelSize.height,
            visibleElementCount: 1,
            shadowMargin: QuickAccessBoxLayout.shadowMargin
        )
    }

    @MainActor
    func makeView(
        context: QuickAccessPresentationContext,
        actions: QuickAccessPresentationActions
    ) -> AnyView {
        AnyView(QuickAccessBoxView(context: context, actions: actions))
    }
}

nonisolated enum QuickAccessBoxLayout {
    static let boxSize = CGSize(width: 206, height: 206)
    static let shadowMargin: CGFloat = 22
    static let cornerRadius: CGFloat = 17
    static let chromeButtonSize: CGFloat = 24
    static let chromeHitSize: CGFloat = 46
    static let chromeCloseIconSize: CGFloat = 12
    static let chromeMoreIconSize: CGFloat = 12
    static let chromeInset: CGFloat = 14
    static let countPillHeight: CGFloat = 28
    static let countPillBottomInset: CGFloat = 17
    static let countFontSize: CGFloat = 13

    static var panelSize: CGSize {
        CGSize(
            width: boxSize.width + shadowMargin * 2,
            height: boxSize.height + shadowMargin * 2
        )
    }
}
