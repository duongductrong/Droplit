import Foundation
import SwiftUI

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
    let dismissSurface: () -> Void
    let removeItem: (UUID) -> Void
    let removeAllItems: () -> Void
    let openItem: (UUID) -> Void
    let revealOutput: (UUID) -> Void
    let convertItem: (UUID, QuickAccessConversionTarget) -> Void
}

struct QuickAccessPresentationView: View {
    @ObservedObject var manager: QuickAccessManager

    var body: some View {
        QuickAccessStackView(
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
            items: showPanelForWorkspaceJobs ? items : items.filter { $0.source == .quickAccess },
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
            }
        )
    }

    var presentationMetrics: QuickAccessPresentationMetrics {
        QuickAccessStackPresentationStyle().metrics(for: presentationContext)
    }
}
