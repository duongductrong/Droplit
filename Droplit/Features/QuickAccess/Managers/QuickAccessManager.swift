import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class QuickAccessManager: ObservableObject {
    static let shared = QuickAccessManager()

    @Published private(set) var items: [QuickAccessItem] = []
    @Published private(set) var isDropPlaceholderVisible = false
    @Published private(set) var maximumConcurrentOptimizations: Int = 3
    @Published private(set) var holdTriggerDuration: TimeInterval = 1
    @Published var triggerInteraction: QuickAccessTriggerInteraction = .shake {
        didSet {
            guard triggerInteraction != oldValue else { return }
            UserDefaults.standard.set(triggerInteraction.rawValue, forKey: Keys.triggerInteraction)
            resetDragTriggerState()
        }
    }
    @Published var position: QuickAccessPosition = .bottomRight {
        didSet {
            UserDefaults.standard.set(position.rawValue, forKey: Keys.position)
            panelController.updatePosition(position)
        }
    }

    var visibleCardCount: Int {
        floatingItemCount + overflowCardCount + (isDropPlaceholderVisible ? 1 : 0)
    }

    var floatingItems: [QuickAccessItem] {
        Array(items.prefix(QuickAccessLayout.maximumFloatingItems))
    }

    var hiddenFloatingItemCount: Int {
        max(items.count - floatingItems.count, 0)
    }

    var hasOverflowCard: Bool {
        hiddenFloatingItemCount > 0
    }

    var queuedCount: Int {
        items.filter { $0.state == .queued }.count
    }

    var processingCount: Int {
        items.filter { $0.state == .processing }.count
    }

    var completedCount: Int {
        items.filter { $0.state == .completed }.count
    }

    var failedCount: Int {
        items.filter { $0.state == .failed }.count
    }

    private enum Keys {
        static let position = "quickAccess.position"
        static let triggerInteraction = "quickAccess.triggerInteraction"
        static let holdTriggerDuration = "quickAccess.holdTriggerDuration"
        static let maximumConcurrentOptimizations = "quickAccess.maximumConcurrentOptimizations"
    }

    private static let allowedConcurrencyRange = 1...12
    static let allowedHoldTriggerDurationRange: ClosedRange<TimeInterval> = 0.4...3

    private let panelController = QuickAccessPanelController()
    private let shakeDetector = QuickAccessShakeDetector()
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var localMouseUpMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var placeholderTimeoutTask: Task<Void, Never>?
    private var holdTriggerTask: Task<Void, Never>?
    private var isDragSessionActive = false
    private var lastCompletedDragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount
    private var currentDragPasteboardChangeCount: Int?
    private var isCurrentDragPayloadOptimizable = false
    private var processTasks: [UUID: Task<Void, Never>] = [:]
    private var elapsedTasks: [UUID: Task<Void, Never>] = [:]
    private var completedDismissTasks: [UUID: Task<Void, Never>] = [:]

    private let placeholderManualTimeout: UInt64 = 12_000_000_000
    private let placeholderPostDragTimeout: UInt64 = 2_000_000_000
    private let completedCardDismissTimeout: UInt64 = 15_000_000_000

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.position),
           let saved = QuickAccessPosition(rawValue: raw) {
            position = saved
        }
        if let raw = UserDefaults.standard.string(forKey: Keys.triggerInteraction),
           let saved = QuickAccessTriggerInteraction(rawValue: raw) {
            triggerInteraction = saved
        }
        let savedHoldDuration = UserDefaults.standard.double(forKey: Keys.holdTriggerDuration)
        if savedHoldDuration > 0 {
            holdTriggerDuration = Self.clampHoldTriggerDuration(savedHoldDuration)
        }
        let savedConcurrency = UserDefaults.standard.integer(forKey: Keys.maximumConcurrentOptimizations)
        if savedConcurrency > 0 {
            maximumConcurrentOptimizations = Self.clampConcurrency(savedConcurrency)
        }
    }

    func start() {
        guard localMonitor == nil, globalMonitor == nil else { return }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            let location = NSEvent.mouseLocation
            let timestamp = event.timestamp
            Task { @MainActor in
                self?.recordDrag(location: location, timestamp: timestamp)
            }
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            let location = NSEvent.mouseLocation
            let timestamp = event.timestamp
            Task { @MainActor in
                self?.recordDrag(location: location, timestamp: timestamp)
            }
        }

        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp]) { [weak self] event in
            Task { @MainActor in
                self?.finishDragSession()
            }
            return event
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp]) { [weak self] _ in
            Task { @MainActor in
                self?.finishDragSession()
            }
        }
    }

    func stop() {
        [localMonitor, globalMonitor, localMouseUpMonitor, globalMouseUpMonitor].forEach { monitor in
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        localMonitor = nil
        globalMonitor = nil
        localMouseUpMonitor = nil
        globalMouseUpMonitor = nil
        placeholderTimeoutTask?.cancel()
        placeholderTimeoutTask = nil
        holdTriggerTask?.cancel()
        holdTriggerTask = nil
        isDragSessionActive = false
        resetDragPayloadState(markCurrentPasteboardConsumed: true)
        processTasks.values.forEach { $0.cancel() }
        elapsedTasks.values.forEach { $0.cancel() }
        completedDismissTasks.values.forEach { $0.cancel() }
        processTasks.removeAll()
        elapsedTasks.removeAll()
        completedDismissTasks.removeAll()
        panelController.hide()
    }

    func showDropPlaceholder() {
        showDropPlaceholder(shouldTimeout: true)
    }

    private func showDropPlaceholder(shouldTimeout: Bool) {
        placeholderTimeoutTask?.cancel()
        withAnimation(QuickAccessAnimations.cardInsert) {
            isDropPlaceholderVisible = true
        }
        refreshPanel()
        if shouldTimeout {
            schedulePlaceholderTimeout(after: placeholderManualTimeout)
        }
    }

    func ingestDroppedURLs(_ urls: [URL]) {
        let supported = urls.filter { QuickAccessFileKind.detect(from: $0).isSupported }
        guard !supported.isEmpty else { return }

        isDragSessionActive = false
        resetDragTriggerState()
        resetDragPayloadState(markCurrentPasteboardConsumed: true)
        placeholderTimeoutTask?.cancel()

        for url in supported {
            Task { [weak self] in
                await self?.addOptimizationJob(for: url)
            }
        }
    }

    func setMaximumConcurrentOptimizations(_ value: Int) {
        let clamped = Self.clampConcurrency(value)
        guard maximumConcurrentOptimizations != clamped else { return }

        maximumConcurrentOptimizations = clamped
        UserDefaults.standard.set(clamped, forKey: Keys.maximumConcurrentOptimizations)
        schedulePendingJobs()
    }

    func setHoldTriggerDuration(_ value: TimeInterval) {
        let clamped = Self.clampHoldTriggerDuration(value)
        guard abs(holdTriggerDuration - clamped) > 0.001 else { return }

        holdTriggerDuration = clamped
        UserDefaults.standard.set(clamped, forKey: Keys.holdTriggerDuration)
        if isDragSessionActive, triggerInteraction == .hold {
            scheduleHoldTrigger(resetExisting: true)
        }
    }

    func removeItem(id: UUID) {
        processTasks[id]?.cancel()
        elapsedTasks[id]?.cancel()
        completedDismissTasks[id]?.cancel()
        processTasks[id] = nil
        elapsedTasks[id] = nil
        completedDismissTasks[id] = nil

        withAnimation(QuickAccessAnimations.cardRemove) {
            items.removeAll { $0.id == id }
        }
        refreshPanel()
        schedulePendingJobs()
    }

    func revealOutput(for id: UUID) {
        guard let item = items.first(where: { $0.id == id }),
              let outputURL = item.outputURL else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
    }

    func openItem(for id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }

        let preferredURL = item.outputURL ?? item.sourceURL
        let fallbackURL = item.sourceURL
        if FileManager.default.fileExists(atPath: preferredURL.path) {
            NSWorkspace.shared.open(preferredURL)
        } else if preferredURL != fallbackURL {
            NSWorkspace.shared.open(fallbackURL)
        }
    }

    func convertItem(id: UUID, to target: QuickAccessConversionTarget) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].conversionTargets.contains(target),
              items[index].state != .processing else {
            return
        }

        completedDismissTasks[id]?.cancel()
        completedDismissTasks[id] = nil
        elapsedTasks[id]?.cancel()
        elapsedTasks[id] = nil
        processTasks[id]?.cancel()
        processTasks[id] = nil

        items[index].state = .processing
        items[index].elapsed = 0
        items[index].progress = items[index].mediaDuration == nil ? nil : 0
        items[index].optimizedBytes = nil
        items[index].outputURL = nil
        items[index].failureMessage = nil
        items[index].activeOperationName = target.processingTitle
        items[index].activeConversionTarget = target

        startElapsedTicker(for: id)
        startConversion(for: id, url: items[index].sourceURL, target: target)
        refreshPanel()
    }

    private func recordDrag(location: CGPoint, timestamp: TimeInterval) {
        let wasDragSessionActive = isDragSessionActive
        isDragSessionActive = true
        placeholderTimeoutTask?.cancel()
        let hasOptimizableDragPayload = refreshCurrentDragPayloadEligibility()

        switch triggerInteraction {
        case .shake:
            holdTriggerTask?.cancel()
            holdTriggerTask = nil
            guard hasOptimizableDragPayload else {
                shakeDetector.reset()
                return
            }
            if shakeDetector.record(location: location, timestamp: timestamp) {
                showDropPlaceholder(shouldTimeout: false)
            }
        case .hold:
            shakeDetector.reset()
            guard hasOptimizableDragPayload else { return }
            if (!wasDragSessionActive || holdTriggerTask == nil), !isDropPlaceholderVisible {
                scheduleHoldTrigger(resetExisting: false)
            }
        }
    }

    private func scheduleHoldTrigger(resetExisting: Bool) {
        if resetExisting {
            holdTriggerTask?.cancel()
            holdTriggerTask = nil
        }
        guard holdTriggerTask == nil else { return }

        let delay = holdTriggerDelayNanoseconds
        holdTriggerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self?.showDropPlaceholderForHoldIfNeeded()
        }
    }

    private func showDropPlaceholderForHoldIfNeeded() {
        holdTriggerTask = nil
        guard isDragSessionActive,
              triggerInteraction == .hold,
              isCurrentDragPayloadOptimizable else {
            return
        }
        showDropPlaceholder(shouldTimeout: false)
    }

    private func resetDragTriggerState() {
        shakeDetector.reset()
        holdTriggerTask?.cancel()
        holdTriggerTask = nil
    }

    private var holdTriggerDelayNanoseconds: UInt64 {
        UInt64(holdTriggerDuration * 1_000_000_000)
    }

    private func finishDragSession() {
        isDragSessionActive = false
        resetDragTriggerState()
        resetDragPayloadState(markCurrentPasteboardConsumed: true)
        guard isDropPlaceholderVisible else { return }
        schedulePlaceholderTimeout(after: placeholderPostDragTimeout)
    }

    private func refreshCurrentDragPayloadEligibility() -> Bool {
        let pasteboard = NSPasteboard(name: .drag)
        let changeCount = pasteboard.changeCount
        if currentDragPasteboardChangeCount != changeCount {
            currentDragPasteboardChangeCount = changeCount
            isCurrentDragPayloadOptimizable = changeCount != lastCompletedDragPasteboardChangeCount
                && QuickAccessPasteboardPayload.hasOptimizablePayload(pasteboard)
            if !isCurrentDragPayloadOptimizable {
                holdTriggerTask?.cancel()
                holdTriggerTask = nil
            }
        }

        return isCurrentDragPayloadOptimizable
    }

    private func resetDragPayloadState(markCurrentPasteboardConsumed: Bool) {
        if markCurrentPasteboardConsumed {
            lastCompletedDragPasteboardChangeCount = currentDragPasteboardChangeCount
                ?? NSPasteboard(name: .drag).changeCount
        }
        currentDragPasteboardChangeCount = nil
        isCurrentDragPayloadOptimizable = false
    }

    private func addOptimizationJob(for url: URL) async {
        let kind = QuickAccessFileKind.detect(from: url)
        let originalBytes = fileSize(at: url)
        let thumbnail = await QuickAccessThumbnailGenerator.generate(from: url, kind: kind)
        var item = QuickAccessItem(
            sourceURL: url,
            kind: kind,
            thumbnail: thumbnail.image,
            originalBytes: originalBytes,
            mediaDuration: thumbnail.duration,
            pixelSize: thumbnail.pixelSize
        )
        item.progress = thumbnail.duration == nil ? nil : 0

        withAnimation(QuickAccessAnimations.cardInsert) {
            items.insert(item, at: 0)
            isDropPlaceholderVisible = false
        }

        refreshPanel()
        schedulePendingJobs()
    }

    private func schedulePendingJobs() {
        let openSlots = max(maximumConcurrentOptimizations - processTasks.count, 0)
        guard openSlots > 0 else { return }

        let pendingIDs = items
            .filter { $0.state == .queued }
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(openSlots)
            .map(\.id)

        for id in pendingIDs {
            guard let index = items.firstIndex(where: { $0.id == id }) else { continue }
            items[index].state = .processing
            items[index].elapsed = 0
            items[index].progress = items[index].mediaDuration == nil ? nil : 0
            items[index].activeOperationName = "Optimizing"
            items[index].activeConversionTarget = items[index].sourceConversionTarget
            startElapsedTicker(for: id)
            startOptimization(for: id, url: items[index].sourceURL, kind: items[index].kind)
        }
    }

    private func startOptimization(for id: UUID, url: URL, kind: QuickAccessFileKind) {
        processTasks[id] = Task { [weak self] in
            do {
                let result = try await OptimizationService.optimize(sourceURL: url, kind: kind)
                self?.completeItem(id: id, result: result)
            } catch {
                self?.failItem(id: id, error: error)
            }
        }
    }

    private func startConversion(for id: UUID, url: URL, target: QuickAccessConversionTarget) {
        processTasks[id] = Task { [weak self] in
            do {
                let result = try await OptimizationService.convert(sourceURL: url, target: target)
                self?.completeItem(id: id, result: result)
            } catch {
                self?.failItem(id: id, error: error)
            }
        }
    }

    private func completeItem(id: UUID, result: OptimizationResult) {
        elapsedTasks[id]?.cancel()
        elapsedTasks[id] = nil
        processTasks[id] = nil

        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = .completed
        items[index].progress = 1
        items[index].optimizedBytes = result.optimizedBytes
        items[index].outputURL = result.outputURL
        if let pixelSize = result.pixelSize {
            items[index].pixelSize = pixelSize
        }
        scheduleCompletedDismiss(for: id)
        schedulePendingJobs()
    }

    private func failItem(id: UUID, error: Error) {
        elapsedTasks[id]?.cancel()
        elapsedTasks[id] = nil
        processTasks[id] = nil

        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = .failed
        items[index].progress = nil
        items[index].activeConversionTarget = items[index].sourceConversionTarget
        items[index].failureMessage = error.localizedDescription
        schedulePendingJobs()
    }

    private func scheduleCompletedDismiss(for id: UUID) {
        completedDismissTasks[id]?.cancel()
        completedDismissTasks[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.completedCardDismissTimeout ?? 15_000_000_000)
            guard !Task.isCancelled else { return }
            self?.dismissCompletedItem(id: id)
        }
    }

    private func dismissCompletedItem(id: UUID) {
        guard let item = items.first(where: { $0.id == id }),
              item.state == .completed else {
            completedDismissTasks[id] = nil
            return
        }
        removeItem(id: id)
    }

    private func startElapsedTicker(for id: UUID) {
        elapsedTasks[id]?.cancel()
        let startedAt = Date()
        elapsedTasks[id] = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                self?.tickElapsed(id: id, startedAt: startedAt)
            }
        }
    }

    private func tickElapsed(id: UUID, startedAt: Date) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].state == .processing else {
            return
        }
        let elapsed = Date().timeIntervalSince(startedAt)
        items[index].elapsed = elapsed
        if let duration = items[index].mediaDuration, duration > 0 {
            items[index].progress = min(elapsed / duration, 0.94)
        }
    }

    private func schedulePlaceholderTimeout(after nanoseconds: UInt64) {
        placeholderTimeoutTask?.cancel()
        placeholderTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            self?.hidePlaceholderIfIdle()
        }
    }

    private func hidePlaceholderIfIdle() {
        guard isDropPlaceholderVisible, !isDragSessionActive else { return }
        withAnimation(QuickAccessAnimations.cardRemove) {
            isDropPlaceholderVisible = false
        }
        refreshPanel()
    }

    private func refreshPanel() {
        if visibleCardCount == 0 {
            panelController.hide()
            return
        }

        let size = QuickAccessLayout.panelSize(
            itemCardCount: floatingItemCount,
            conversionActionRowCount: floatingConversionActionRowCount,
            dropPlaceholderCount: isDropPlaceholderVisible ? 1 : 0,
            includesOverflowCard: hasOverflowCard
        )
        if panelController.isVisible {
            panelController.updateSize(size)
        } else {
            panelController.show(
                QuickAccessStackView(manager: self),
                size: size,
                position: position
            )
        }
    }

    private func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    private var floatingItemCount: Int {
        floatingItems.count
    }

    private var floatingConversionActionRowCount: Int {
        floatingItems.filter(\.hasConversionTargets).count
    }

    private var overflowCardCount: Int {
        hasOverflowCard ? 1 : 0
    }

    private static func clampConcurrency(_ value: Int) -> Int {
        min(max(value, allowedConcurrencyRange.lowerBound), allowedConcurrencyRange.upperBound)
    }

    private static func clampHoldTriggerDuration(_ value: TimeInterval) -> TimeInterval {
        min(max(value, allowedHoldTriggerDurationRange.lowerBound), allowedHoldTriggerDurationRange.upperBound)
    }
}
