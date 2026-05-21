import Foundation
import SwiftUI

nonisolated enum QuickAccessPresentationStyle: String, CaseIterable, Codable, Identifiable {
    case stack
    case box

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stack: "Stack"
        case .box: "Box"
        }
    }

    var description: String {
        switch self {
        case .stack:
            return "Vertical floating cards with a drop target and overflow summary"
        case .box:
            return "Compact square preview with layered media cards and count pill"
        }
    }

    var provider: QuickAccessPresentationStyleProviding {
        switch self {
        case .stack:
            return QuickAccessStackPresentationStyle()
        case .box:
            return QuickAccessBoxPresentationStyle()
        }
    }

    func metrics(for context: QuickAccessPresentationContext) -> QuickAccessPresentationMetrics {
        provider.metrics(for: context)
    }

    @MainActor
    func makeView(
        context: QuickAccessPresentationContext,
        actions: QuickAccessPresentationActions
    ) -> AnyView {
        provider.makeView(context: context, actions: actions)
    }
}

nonisolated protocol QuickAccessPresentationStyleProviding {
    var style: QuickAccessPresentationStyle { get }

    func metrics(for context: QuickAccessPresentationContext) -> QuickAccessPresentationMetrics

    @MainActor
    func makeView(
        context: QuickAccessPresentationContext,
        actions: QuickAccessPresentationActions
    ) -> AnyView
}

nonisolated struct QuickAccessPresentationContext {
    let items: [QuickAccessItem]
    let isDropPlaceholderVisible: Bool
    let pendingDropSummary: QuickAccessPendingDropSummary?
    let position: QuickAccessPosition
}

nonisolated struct QuickAccessPresentationMetrics {
    let panelSize: CGSize
    let activeContentHeight: CGFloat
    let visibleElementCount: Int
    let shadowMargin: CGFloat

    static let empty = QuickAccessPresentationMetrics(
        panelSize: .zero,
        activeContentHeight: 0,
        visibleElementCount: 0,
        shadowMargin: 0
    )
}

nonisolated struct QuickAccessPresentationActions {
    let ingestDroppedURLs: ([URL]) -> Void
    let stageDroppedURLs: ([URL]) -> Void
    let dismissSurface: () -> Void
    let removeItem: (UUID) -> Void
    let removeAllItems: () -> Void
    let clearItemsKeepingSurfaceVisible: () -> Void
    let openItem: (UUID) -> Void
    let revealOutput: (UUID) -> Void
    let convertItem: (UUID, QuickAccessConversionTarget) -> Void
    let processAllStagedItems: () -> Void
}

struct QuickAccessPresentationView: View {
    @ObservedObject var manager: QuickAccessManager

    var body: some View {
        manager.presentationStyle.makeView(
            context: manager.presentationContext,
            actions: manager.presentationActions
        )
    }
}

private func runQuickAccessPresentationAction(_ action: @escaping @MainActor () -> Void) {
    if Thread.isMainThread {
        MainActor.assumeIsolated {
            action()
        }
    } else {
        Task { @MainActor in
            action()
        }
    }
}

extension QuickAccessManager {
    var presentationContext: QuickAccessPresentationContext {
        QuickAccessPresentationContext(
            items: items,
            isDropPlaceholderVisible: isDropPlaceholderVisible,
            pendingDropSummary: pendingDropSummary,
            position: position
        )
    }

    var presentationActions: QuickAccessPresentationActions {
        QuickAccessPresentationActions(
            ingestDroppedURLs: { [weak self] urls in
                guard let self else { return }
                runQuickAccessPresentationAction {
                    self.ingestDroppedURLs(urls)
                }
            },
            stageDroppedURLs: { [weak self] urls in
                guard let self else { return }
                runQuickAccessPresentationAction {
                    self.stageDroppedURLs(urls)
                }
            },
            dismissSurface: { [weak self] in
                guard let self else { return }
                runQuickAccessPresentationAction {
                    self.dismissQuickAccessSurface()
                }
            },
            removeItem: { [weak self] id in
                guard let self else { return }
                runQuickAccessPresentationAction {
                    self.removeItem(id: id)
                }
            },
            removeAllItems: { [weak self] in
                guard let self else { return }
                runQuickAccessPresentationAction {
                    self.removeAllItems()
                }
            },
            clearItemsKeepingSurfaceVisible: { [weak self] in
                guard let self else { return }
                runQuickAccessPresentationAction {
                    self.removeAllItems(keepsSurfaceVisible: true)
                }
            },
            openItem: { [weak self] id in
                guard let self else { return }
                runQuickAccessPresentationAction {
                    self.openItem(for: id)
                }
            },
            revealOutput: { [weak self] id in
                guard let self else { return }
                runQuickAccessPresentationAction {
                    self.revealOutput(for: id)
                }
            },
            convertItem: { [weak self] id, target in
                guard let self else { return }
                runQuickAccessPresentationAction {
                    self.convertItem(id: id, to: target)
                }
            },
            processAllStagedItems: { [weak self] in
                guard let self else { return }
                runQuickAccessPresentationAction {
                    self.processAllStagedItems()
                }
            }
        )
    }

    var presentationMetrics: QuickAccessPresentationMetrics {
        presentationStyle.metrics(for: presentationContext)
    }
}
