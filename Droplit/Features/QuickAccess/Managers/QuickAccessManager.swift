import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class QuickAccessManager: ObservableObject {
    static let shared = QuickAccessManager()

    @Published private(set) var items: [QuickAccessItem] = []
    @Published private(set) var isDropPlaceholderVisible = false
    @Published private(set) var pendingDropSummary: QuickAccessPendingDropSummary?
    @Published private(set) var maximumConcurrentOptimizations: Int = 3
    @Published private(set) var holdTriggerDuration: TimeInterval = 1
    @Published var presentationStyle: QuickAccessPresentationStyle = .stack {
        didSet {
            guard presentationStyle != oldValue else { return }
            UserDefaults.standard.set(presentationStyle.rawValue, forKey: Keys.presentationStyle)
            if presentationStyle != .box, stagedCount > 0 {
                processAllStagedItems()
                return
            }
            refreshPanel()
        }
    }
    @Published var completedCardDisplayDuration: QuickAccessCompletedCardDisplayDuration = .fifteenSeconds {
        didSet {
            guard completedCardDisplayDuration != oldValue else { return }
            UserDefaults.standard.set(completedCardDisplayDuration.rawValue, forKey: Keys.completedCardDisplayDuration)
            rescheduleCompletedDismisses()
        }
    }
    @Published var autoCopyOptimizedOutputToClipboard = false {
        didSet {
            guard autoCopyOptimizedOutputToClipboard != oldValue else { return }
            UserDefaults.standard.set(autoCopyOptimizedOutputToClipboard, forKey: Keys.autoCopyOptimizedOutputToClipboard)
        }
    }
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
    @Published var conversionOutputMode: ConversionOutputMode = OptimizationOutputSettings.conversionOutputMode {
        didSet {
            guard conversionOutputMode != oldValue else { return }
            OptimizationOutputSettings.conversionOutputMode = conversionOutputMode
        }
    }

    var queuedCount: Int {
        items.filter { $0.state == .queued }.count
    }

    var stagedCount: Int {
        items.filter { $0.state == .staged }.count
    }

    var processingCount: Int {
        items.filter { $0.state == .processing }.count
    }

    private enum Keys {
        static let position = "quickAccess.position"
        static let presentationStyle = "quickAccess.presentationStyle"
        static let triggerInteraction = "quickAccess.triggerInteraction"
        static let holdTriggerDuration = "quickAccess.holdTriggerDuration"
        static let maximumConcurrentOptimizations = "quickAccess.maximumConcurrentOptimizations"
        static let completedCardDisplayDuration = "quickAccess.completedCardDisplayDuration"
        static let autoCopyOptimizedOutputToClipboard = "quickAccess.autoCopyOptimizedOutputToClipboard"
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
    private var keepsEmptyBoxOpen = false
    private var processTasks: [UUID: Task<Void, Never>] = [:]
    private var thumbnailTasks: [UUID: Task<Void, Never>] = [:]
    private var elapsedTasks: [UUID: Task<Void, Never>] = [:]
    private var completedDismissTasks: [UUID: Task<Void, Never>] = [:]
    private var lastDragEventTimestamp: TimeInterval = 0

    private let placeholderManualTimeout: UInt64 = 12_000_000_000
    private let placeholderPostDragTimeout: UInt64 = 2_000_000_000
    private let minimumDragEventInterval: TimeInterval = 1.0 / 60.0
    private let elapsedTickerInterval: UInt64 = 250_000_000

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.position),
           let saved = QuickAccessPosition(rawValue: raw) {
            position = saved
        }
        if let raw = UserDefaults.standard.string(forKey: Keys.presentationStyle),
           let saved = QuickAccessPresentationStyle(rawValue: raw) {
            presentationStyle = saved
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
        if let raw = UserDefaults.standard.string(forKey: Keys.completedCardDisplayDuration),
           let saved = QuickAccessCompletedCardDisplayDuration(rawValue: raw) {
            completedCardDisplayDuration = saved
        }
        autoCopyOptimizedOutputToClipboard = UserDefaults.standard.bool(
            forKey: Keys.autoCopyOptimizedOutputToClipboard
        )
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
        keepsEmptyBoxOpen = false
        resetDragPayloadState(markCurrentPasteboardConsumed: true)
        processTasks.values.forEach { $0.cancel() }
        thumbnailTasks.values.forEach { $0.cancel() }
        elapsedTasks.values.forEach { $0.cancel() }
        completedDismissTasks.values.forEach { $0.cancel() }
        processTasks.removeAll()
        thumbnailTasks.removeAll()
        elapsedTasks.removeAll()
        completedDismissTasks.removeAll()
        panelController.hide()
    }

    func showDropPlaceholder() {
        showDropPlaceholder(shouldTimeout: true)
    }

    func dismissQuickAccessSurface() {
        placeholderTimeoutTask?.cancel()
        placeholderTimeoutTask = nil
        keepsEmptyBoxOpen = false

        if isDropPlaceholderVisible {
            withAnimation(QuickAccessAnimations.cardRemove) {
                isDropPlaceholderVisible = false
            }
        }

        refreshPanel()
    }

    private func showDropPlaceholder(shouldTimeout: Bool) {
        placeholderTimeoutTask?.cancel()
        keepsEmptyBoxOpen = false
        withAnimation(QuickAccessAnimations.cardInsert) {
            isDropPlaceholderVisible = true
        }
        refreshPanel()
        if shouldTimeout {
            schedulePlaceholderTimeout(after: placeholderManualTimeout)
        }
    }

    func ingestDroppedURLs(_ urls: [URL]) {
        ingestDroppedURLs(urls, initialState: .queued, startsAutomatically: true)
    }

    func stageDroppedURLs(_ urls: [URL]) {
        ingestDroppedURLs(urls, initialState: .staged, startsAutomatically: false)
    }

    private func ingestDroppedURLs(
        _ urls: [URL],
        initialState: QuickAccessJobState,
        startsAutomatically: Bool
    ) {
        let supported = urls.filter { QuickAccessFileKind.detect(from: $0).isSupported }
        guard !supported.isEmpty else { return }

        isDragSessionActive = false
        keepsEmptyBoxOpen = false
        resetDragTriggerState()
        resetDragPayloadState(markCurrentPasteboardConsumed: true)
        placeholderTimeoutTask?.cancel()

        for url in supported {
            Task { [weak self] in
                await self?.addOptimizationJob(
                    for: url,
                    initialState: initialState,
                    startsAutomatically: startsAutomatically
                )
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
        thumbnailTasks[id]?.cancel()
        elapsedTasks[id]?.cancel()
        completedDismissTasks[id]?.cancel()
        processTasks[id] = nil
        thumbnailTasks[id] = nil
        elapsedTasks[id] = nil
        completedDismissTasks[id] = nil

        withAnimation(QuickAccessAnimations.cardRemove) {
            items.removeAll { $0.id == id }
        }
        refreshPanel()
        schedulePendingJobs()
    }

    func removeAllItems(keepsSurfaceVisible: Bool = false) {
        if !keepsSurfaceVisible {
            panelController.hideImmediately()
        }

        processTasks.values.forEach { $0.cancel() }
        thumbnailTasks.values.forEach { $0.cancel() }
        elapsedTasks.values.forEach { $0.cancel() }
        completedDismissTasks.values.forEach { $0.cancel() }
        processTasks.removeAll()
        thumbnailTasks.removeAll()
        elapsedTasks.removeAll()
        completedDismissTasks.removeAll()
        placeholderTimeoutTask?.cancel()
        placeholderTimeoutTask = nil
        keepsEmptyBoxOpen = keepsSurfaceVisible

        if keepsSurfaceVisible {
            withAnimation(QuickAccessAnimations.cardRemove) {
                items.removeAll()
                isDropPlaceholderVisible = true
            }
            refreshPanel()
        } else {
            items.removeAll()
            isDropPlaceholderVisible = false
        }
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

    func processAllStagedItems() {
        let stagedIDs = items
            .filter { $0.state == .staged }
            .map(\.id)
        guard !stagedIDs.isEmpty else { return }

        for id in stagedIDs {
            guard let index = items.firstIndex(where: { $0.id == id }) else { continue }
            items[index].state = .queued
            items[index].elapsed = 0
            items[index].progress = nil
            items[index].optimizedBytes = nil
            items[index].outputURL = nil
            items[index].failureMessage = nil
            items[index].activeOperationName = "Optimizing"
            items[index].activeConversionTarget = items[index].sourceConversionTarget
        }

        refreshPanel()
        schedulePendingJobs()
    }

    private func recordDrag(location: CGPoint, timestamp: TimeInterval) {
        if lastDragEventTimestamp > 0,
           timestamp - lastDragEventTimestamp < minimumDragEventInterval {
            return
        }
        lastDragEventTimestamp = timestamp

        let wasDragSessionActive = isDragSessionActive
        isDragSessionActive = true
        placeholderTimeoutTask?.cancel()
        let hasOptimizableDragPayload = refreshCurrentDragPayloadEligibility()

        if activateVisibleBoxDropTargetIfNeeded(hasOptimizableDragPayload: hasOptimizableDragPayload) {
            return
        }

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
        lastDragEventTimestamp = 0
    }

    private var holdTriggerDelayNanoseconds: UInt64 {
        UInt64(holdTriggerDuration * 1_000_000_000)
    }

    private func finishDragSession() {
        isDragSessionActive = false
        resetDragTriggerState()
        resetDragPayloadState(markCurrentPasteboardConsumed: true)
        guard isDropPlaceholderVisible else { return }
        guard !keepsEmptyBoxOpen else { return }
        schedulePlaceholderTimeout(after: placeholderPostDragTimeout)
    }

    private func refreshCurrentDragPayloadEligibility() -> Bool {
        let pasteboard = NSPasteboard(name: .drag)
        let changeCount = pasteboard.changeCount
        if currentDragPasteboardChangeCount != changeCount {
            currentDragPasteboardChangeCount = changeCount
            pendingDropSummary = changeCount == lastCompletedDragPasteboardChangeCount
                ? nil
                : QuickAccessPasteboardPayload.pendingDropSummary(from: pasteboard)
            isCurrentDragPayloadOptimizable = pendingDropSummary != nil
            if !isCurrentDragPayloadOptimizable {
                holdTriggerTask?.cancel()
                holdTriggerTask = nil
            }
        }

        return isCurrentDragPayloadOptimizable
    }

    private func activateVisibleBoxDropTargetIfNeeded(hasOptimizableDragPayload: Bool) -> Bool {
        guard hasOptimizableDragPayload,
              presentationStyle == .box,
              !items.isEmpty else {
            return false
        }

        shakeDetector.reset()
        holdTriggerTask?.cancel()
        holdTriggerTask = nil

        if !isDropPlaceholderVisible {
            showDropPlaceholder(shouldTimeout: false)
        }
        return true
    }

    private func resetDragPayloadState(markCurrentPasteboardConsumed: Bool) {
        if markCurrentPasteboardConsumed {
            lastCompletedDragPasteboardChangeCount = currentDragPasteboardChangeCount
                ?? NSPasteboard(name: .drag).changeCount
        }
        currentDragPasteboardChangeCount = nil
        isCurrentDragPayloadOptimizable = false
        pendingDropSummary = nil
    }

    private func addOptimizationJob(
        for url: URL,
        initialState: QuickAccessJobState,
        startsAutomatically: Bool
    ) async {
        let kind = QuickAccessFileKind.detect(from: url)
        let originalBytes = fileSize(at: url)
        let placeholderThumbnail = QuickAccessThumbnailGenerator.placeholderThumbnail(systemImage: kind.systemImage)
        let item = QuickAccessItem(
            sourceURL: url,
            kind: kind,
            thumbnail: placeholderThumbnail,
            originalBytes: originalBytes,
            mediaDuration: nil,
            pixelSize: nil,
            state: initialState
        )
        let itemID = item.id

        withAnimation(QuickAccessAnimations.cardInsert) {
            items.insert(item, at: 0)
            isDropPlaceholderVisible = false
        }

        refreshPanel()
        if startsAutomatically {
            schedulePendingJobs()
        }

        thumbnailTasks[itemID] = Task { [weak self] in
            let thumbnail = await QuickAccessThumbnailGenerator.generate(from: url, kind: kind)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.applyThumbnail(thumbnail, to: itemID)
            }
        }
    }

    private func applyThumbnail(_ thumbnail: QuickAccessThumbnailResult, to id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        thumbnailTasks[id] = nil
        items[index].thumbnail = thumbnail.image
        items[index].mediaDuration = thumbnail.duration
        items[index].pixelSize = thumbnail.pixelSize

        if items[index].state == .processing,
           let duration = thumbnail.duration,
           duration > 0 {
            items[index].progress = min(items[index].elapsed / duration, 0.94)
        }
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
                let mode = self?.conversionOutputMode ?? .duplicate
                let result = try await OptimizationService.convert(sourceURL: url, target: target, mode: mode)
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
        copyOptimizedOutputToClipboardIfNeeded(result.outputURL)
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
        guard let timeout = completedCardDisplayDuration.timeoutNanoseconds else {
            completedDismissTasks[id] = nil
            return
        }
        completedDismissTasks[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: timeout)
            guard !Task.isCancelled else { return }
            self?.dismissCompletedItem(id: id)
        }
    }

    private func rescheduleCompletedDismisses() {
        completedDismissTasks.values.forEach { $0.cancel() }
        completedDismissTasks.removeAll()

        for item in items where item.state == .completed {
            scheduleCompletedDismiss(for: item.id)
        }
    }

    private func copyOptimizedOutputToClipboardIfNeeded(_ outputURL: URL) {
        guard autoCopyOptimizedOutputToClipboard,
              FileManager.default.fileExists(atPath: outputURL.path) else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([outputURL as NSURL])
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
                try? await Task.sleep(nanoseconds: self?.elapsedTickerInterval ?? 250_000_000)
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
        guard isDropPlaceholderVisible, !isDragSessionActive, !keepsEmptyBoxOpen else { return }
        withAnimation(QuickAccessAnimations.cardRemove) {
            isDropPlaceholderVisible = false
        }
        refreshPanel()
    }

    private func refreshPanel() {
        let metrics = presentationMetrics
        if metrics.visibleElementCount == 0 {
            panelController.hide()
            return
        }

        if panelController.isVisible {
            panelController.updateInteractionMetrics(activeContentHeight: metrics.activeContentHeight)
            panelController.updateSize(metrics.panelSize, shadowMargin: metrics.shadowMargin)
        } else {
            panelController.show(
                QuickAccessPresentationView(manager: self),
                size: metrics.panelSize,
                position: position,
                activeContentHeight: metrics.activeContentHeight,
                shadowMargin: metrics.shadowMargin,
                handlesKeyboardShortcuts: presentationStyle == .box,
                onCancel: { [weak self] in
                    self?.handlePanelCancel()
                }
            )
        }
    }

    private func handlePanelCancel() {
        switch presentationStyle {
        case .box:
            removeAllItems()
        case .stack:
            dismissQuickAccessSurface()
        }
    }

    private func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    private static func clampConcurrency(_ value: Int) -> Int {
        min(max(value, allowedConcurrencyRange.lowerBound), allowedConcurrencyRange.upperBound)
    }

    private static func clampHoldTriggerDuration(_ value: TimeInterval) -> TimeInterval {
        min(max(value, allowedHoldTriggerDurationRange.lowerBound), allowedHoldTriggerDurationRange.upperBound)
    }
}
