import AppKit
import Observation
import QuartzCore

enum DockPanelWindowLevel {
    static let content = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
    static let sessionLink = NSWindow.Level(rawValue: content.rawValue + 1)
    static let interaction = NSWindow.Level(rawValue: content.rawValue + 2)
}

enum DockPanelIdentity: CaseIterable, Equatable {
    case usageOverview
    case taskActivity
}

enum DockEdge: Equatable {
    case bottom
    case left
    case right
    case unknown
}

enum PanelSide: CaseIterable, Equatable {
    case left
    case right
}

enum PanelVerticalOrder: CaseIterable, Equatable {
    case usageAboveTask
    case taskAboveUsage
}

struct PanelArrangement: Equatable {
    var usageSide: PanelSide = .left
    var taskSide: PanelSide = .right
    var verticalOrder: PanelVerticalOrder = .usageAboveTask

    var isColocated: Bool { usageSide == taskSide }

    mutating func toggleSide(for panel: DockPanelIdentity) {
        switch panel {
        case .usageOverview: usageSide = usageSide == .left ? .right : .left
        case .taskActivity: taskSide = taskSide == .left ? .right : .left
        }
        if isColocated { verticalOrder = .usageAboveTask }
    }

    mutating func toggleVerticalOrder() {
        guard isColocated else { return }
        verticalOrder = verticalOrder == .usageAboveTask ? .taskAboveUsage : .usageAboveTask
    }

    func side(for panel: DockPanelIdentity) -> PanelSide {
        switch panel {
        case .usageOverview: usageSide
        case .taskActivity: taskSide
        }
    }

    func sideTogglePresentation(for panel: DockPanelIdentity) -> PanelMovementPresentation {
        let target: PanelSide = side(for: panel) == .left ? .right : .left
        let direction = target == .left ? "左侧" : "右侧"
        return PanelMovementPresentation(
            systemImageName: target == .left ? "arrow.left" : "arrow.right",
            label: panel == .usageOverview
                ? "将用量概览面板移到\(direction)"
                : "将任务活动面板移到\(direction)"
        )
    }

    func verticalSwapPresentation(for panel: DockPanelIdentity) -> PanelMovementPresentation? {
        guard isColocated else { return nil }
        return PanelMovementPresentation(
            systemImageName: "arrow.up.arrow.down",
            label: panel == .usageOverview ? "交换用量概览面板的上下位置" : "交换任务活动面板的上下位置"
        )
    }
}

struct DockPanelPreferences: Equatable {
    private enum Key {
        static let usageSide = "dockPanels.usageOverview.side"
        static let taskSide = "dockPanels.taskActivity.side"
        static let verticalOrder = "dockPanels.verticalOrder"
        static let usagePreferredWidth = "dockPanels.usageOverview.preferredWidth"
        static let taskPreferredWidth = "dockPanels.taskActivity.preferredWidth"
    }

    var arrangement: PanelArrangement
    var usageOverviewPreferredWidth: CGFloat
    var taskActivityPreferredWidth: CGFloat

    init(
        arrangement: PanelArrangement = PanelArrangement(),
        usageOverviewPreferredWidth: CGFloat = DockPanelWidthGeometry.defaultWidth,
        taskActivityPreferredWidth: CGFloat = DockPanelWidthGeometry.defaultWidth
    ) {
        self.arrangement = arrangement
        self.usageOverviewPreferredWidth = usageOverviewPreferredWidth
        self.taskActivityPreferredWidth = taskActivityPreferredWidth
    }

    init(defaults: UserDefaults) {
        arrangement = PanelArrangement(
            usageSide: Self.side(defaults.string(forKey: Key.usageSide)) ?? .left,
            taskSide: Self.side(defaults.string(forKey: Key.taskSide)) ?? .right,
            verticalOrder: Self.verticalOrder(defaults.string(forKey: Key.verticalOrder)) ?? .usageAboveTask
        )
        usageOverviewPreferredWidth = Self.width(
            defaults.object(forKey: Key.usagePreferredWidth),
            fallback: DockPanelWidthGeometry.defaultWidth
        )
        taskActivityPreferredWidth = Self.width(
            defaults.object(forKey: Key.taskPreferredWidth),
            fallback: DockPanelWidthGeometry.defaultWidth
        )
    }

    func save(to defaults: UserDefaults) {
        defaults.set(Self.string(for: arrangement.usageSide), forKey: Key.usageSide)
        defaults.set(Self.string(for: arrangement.taskSide), forKey: Key.taskSide)
        defaults.set(Self.string(for: arrangement.verticalOrder), forKey: Key.verticalOrder)
        defaults.set(Double(usageOverviewPreferredWidth), forKey: Key.usagePreferredWidth)
        defaults.set(Double(taskActivityPreferredWidth), forKey: Key.taskPreferredWidth)
    }

    private static func side(_ value: String?) -> PanelSide? {
        switch value {
        case "left": .left
        case "right": .right
        default: nil
        }
    }

    private static func verticalOrder(_ value: String?) -> PanelVerticalOrder? {
        switch value {
        case "usageAboveTask": .usageAboveTask
        case "taskAboveUsage": .taskAboveUsage
        default: nil
        }
    }

    private static func string(for side: PanelSide) -> String {
        switch side {
        case .left: "left"
        case .right: "right"
        }
    }

    private static func string(for order: PanelVerticalOrder) -> String {
        switch order {
        case .usageAboveTask: "usageAboveTask"
        case .taskAboveUsage: "taskAboveUsage"
        }
    }

    private static func width(_ value: Any?, fallback: CGFloat) -> CGFloat {
        guard let number = value as? NSNumber else { return fallback }
        let width = CGFloat(number.doubleValue)
        guard width.isFinite, width >= DockPanelWidthGeometry.minimumPreferredWidth else { return fallback }
        return width
    }
}

struct PanelMovementPresentation: Equatable {
    let systemImageName: String
    let label: String
}

@MainActor @Observable
final class DockPanelPresentationState {
    var usageSide: PanelSide = .left
}

enum DockPanelResizeAnchor {
    case fixedLeft
    case fixedRight
}

extension PanelSide {
    var resizeAnchor: DockPanelResizeAnchor {
        self == .left ? .fixedLeft : .fixedRight
    }
}

struct DockPanelPlacementGeometry {
    struct PanelSizes {
        let usagePreferredWidth: CGFloat
        let taskPreferredWidth: CGFloat
        let usageHeight: CGFloat
        let taskHeight: CGFloat
    }

    static func appKitRect(fromQuartz rect: CGRect, mainScreenMaxY: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: mainScreenMaxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func bottomEdge(
        dockFrame: CGRect?,
        screenFrame: CGRect,
        fallbackInset: CGFloat
    ) -> CGFloat {
        dockFrame?.minY ?? screenFrame.minY + fallbackInset
    }

    static func frames(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        dockFrame: CGRect?,
        dockEdge: DockEdge,
        arrangement: PanelArrangement,
        sizes: PanelSizes,
        inset: CGFloat,
        gap: CGFloat
    ) -> [DockPanelIdentity: CGRect] {
        switch dockEdge {
        case .bottom, .unknown:
            return bottomFrames(
                screenFrame: screenFrame,
                dockFrame: dockFrame,
                arrangement: arrangement,
                sizes: sizes,
                inset: inset,
                gap: gap
            )
        case .left, .right:
            return verticalDockFrames(
                screenFrame: screenFrame,
                visibleFrame: visibleFrame,
                dockEdge: dockEdge,
                arrangement: arrangement,
                sizes: sizes,
                inset: inset,
                gap: gap
            )
        }
    }

    private static func bottomFrames(
        screenFrame: CGRect,
        dockFrame: CGRect?,
        arrangement: PanelArrangement,
        sizes: PanelSizes,
        inset: CGFloat,
        gap: CGFloat
    ) -> [DockPanelIdentity: CGRect] {
        let center = screenFrame.midX
        let leftMaximum = dockFrame?.minX ?? center - gap / 2
        let rightMinimum = dockFrame?.maxX ?? center + gap / 2
        let slots: [PanelSide: ClosedRange<CGFloat>] = [
            .left: (screenFrame.minX + inset)...max(screenFrame.minX + inset + 1, leftMaximum - gap),
            .right: min(screenFrame.maxX - inset - 1, rightMinimum + gap)...(screenFrame.maxX - inset)
        ]
        let lowerY = bottomEdge(dockFrame: dockFrame, screenFrame: screenFrame, fallbackInset: inset)
        return makeFrames(
            screenFrame: screenFrame,
            arrangement: arrangement,
            sizes: sizes,
            slots: slots,
            splitY: [.left: lowerY, .right: lowerY],
            colocatedAnchor: { _ in .bottom },
            inset: inset,
            gap: gap
        )
    }

    private static func verticalDockFrames(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        dockEdge: DockEdge,
        arrangement: PanelArrangement,
        sizes: PanelSizes,
        inset: CGFloat,
        gap: CGFloat
    ) -> [DockPanelIdentity: CGRect] {
        let horizontalRange: ClosedRange<CGFloat>
        if dockEdge == .left {
            let minimum = min(screenFrame.maxX - inset - 1, visibleFrame.minX + gap)
            horizontalRange = minimum...(screenFrame.maxX - inset)
        } else {
            let maximum = max(screenFrame.minX + inset + 1, visibleFrame.maxX - gap)
            horizontalRange = (screenFrame.minX + inset)...maximum
        }
        return makeFrames(
            screenFrame: screenFrame,
            arrangement: arrangement,
            sizes: sizes,
            slots: [.left: horizontalRange, .right: horizontalRange],
            splitY: [
                .left: screenFrame.maxY - inset,
                .right: screenFrame.minY + inset
            ],
            colocatedAnchor: { $0 == .left ? .top : .bottom },
            inset: inset,
            gap: gap
        )
    }

    private enum VerticalAnchor { case top, bottom }

    private static func makeFrames(
        screenFrame: CGRect,
        arrangement: PanelArrangement,
        sizes: PanelSizes,
        slots: [PanelSide: ClosedRange<CGFloat>],
        splitY: [PanelSide: CGFloat],
        colocatedAnchor: (PanelSide) -> VerticalAnchor,
        inset: CGFloat,
        gap: CGFloat
    ) -> [DockPanelIdentity: CGRect] {
        var frames: [DockPanelIdentity: CGRect] = [:]
        for identity in DockPanelIdentity.allCases {
            let side = arrangement.side(for: identity)
            guard let slot = slots[side] else { continue }
            let preferredWidth = identity == .usageOverview ? sizes.usagePreferredWidth : sizes.taskPreferredWidth
            let height = identity == .usageOverview ? sizes.usageHeight : sizes.taskHeight
            let anchor = side.resizeAnchor
            let fixedEdge = anchor == .fixedLeft ? slot.lowerBound : slot.upperBound
            let rawY = splitY[side] ?? screenFrame.minY + inset
            let y = side == .left && rawY == screenFrame.maxY - inset ? rawY - height : rawY
            frames[identity] = DockPanelWidthGeometry.frame(
                preferredWidth: preferredWidth,
                availableWidth: slot.upperBound - slot.lowerBound,
                fixedEdge: fixedEdge,
                anchor: anchor,
                y: y,
                height: height
            )
        }

        guard arrangement.isColocated,
              var usage = frames[.usageOverview],
              var task = frames[.taskActivity] else {
            return frames
        }

        let totalHeight = usage.height + gap + task.height
        let availableHeight = max(1, screenFrame.height - 2 * inset)
        let groupHeight = min(totalHeight, availableHeight)
        let side = arrangement.usageSide
        let groupMinY = colocatedAnchor(side) == .top
            ? screenFrame.maxY - inset - groupHeight
            : screenFrame.minY + inset
        let lowerHeight = arrangement.verticalOrder == .usageAboveTask ? task.height : usage.height
        if arrangement.verticalOrder == .usageAboveTask {
            task.origin.y = groupMinY
            usage.origin.y = groupMinY + lowerHeight + gap
        } else {
            usage.origin.y = groupMinY
            task.origin.y = groupMinY + lowerHeight + gap
        }
        let translation = min(0, screenFrame.maxY - inset - max(usage.maxY, task.maxY))
            + max(0, screenFrame.minY + inset - min(usage.minY, task.minY))
        usage.origin.y += translation
        task.origin.y += translation
        frames[.usageOverview] = usage
        frames[.taskActivity] = task
        return frames
    }
}

struct DockPanelWidthGeometry {
    static let defaultWidth: CGFloat = 350
    static let minimumPreferredWidth: CGFloat = 180

    static func preferredWidth(
        startingWidth: CGFloat,
        horizontalDrag: CGFloat,
        anchor: DockPanelResizeAnchor
    ) -> CGFloat {
        let proposedWidth = switch anchor {
        case .fixedLeft: startingWidth + horizontalDrag
        case .fixedRight: startingWidth - horizontalDrag
        }
        return max(minimumPreferredWidth, proposedWidth)
    }

    static func actualWidth(preferredWidth: CGFloat, availableWidth: CGFloat) -> CGFloat {
        min(max(minimumPreferredWidth, preferredWidth), max(1, availableWidth))
    }

    static func frame(
        preferredWidth: CGFloat,
        availableWidth: CGFloat,
        fixedEdge: CGFloat,
        anchor: DockPanelResizeAnchor,
        y: CGFloat,
        height: CGFloat
    ) -> NSRect {
        let width = actualWidth(preferredWidth: preferredWidth, availableWidth: availableWidth)
        let x = anchor == .fixedLeft ? fixedEdge : fixedEdge - width
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

struct DockPanelOverlayMetrics: Equatable {
    let screenFrame: CGRect
    let dockFrame: CGRect?
    let dockEdge: DockEdge
}

struct DockPanelPointerDwell {
    private var candidate: DockPanelIdentity?
    private var lastLocation: CGPoint?
    private var stationarySince: Date?

    mutating func update(
        candidate newCandidate: DockPanelIdentity?,
        location: CGPoint,
        now: Date,
        delay: TimeInterval
    ) -> DockPanelIdentity? {
        guard let newCandidate else {
            reset()
            return nil
        }

        guard candidate == newCandidate, lastLocation == location else {
            candidate = newCandidate
            lastLocation = location
            stationarySince = now
            return nil
        }

        guard let stationarySince,
              now.timeIntervalSince(stationarySince) >= delay else { return nil }
        return newCandidate
    }

    mutating func reset() {
        candidate = nil
        lastLocation = nil
        stationarySince = nil
    }
}

struct DockPanelOverlayGeometry {
    static let resizeWidth: CGFloat = 34
    static let minimumResizeHeight: CGFloat = 80
    static let dockHeightClearance: CGFloat = 12
    static let outerCornerRadius: CGFloat = 16
    static let actionCornerRadius: CGFloat = 10
    static let controlGap: CGFloat = 6
    static let controlPadding: CGFloat = 6
    static var resizeHitWidth: CGFloat { resizeWidth + 2 * controlPadding }

    static func interactionHeight(
        parentFrame: CGRect,
        metrics: DockPanelOverlayMetrics
    ) -> CGFloat {
        let dockDrivenHeight = metrics.dockEdge == .bottom
            ? (metrics.dockFrame?.height ?? 0) + dockHeightClearance
            : 0
        return min(
            metrics.screenFrame.height,
            max(parentFrame.height, minimumResizeHeight, dockDrivenHeight)
        )
    }

    static func expandedFrame(
        parentFrame: CGRect,
        side: PanelSide,
        metrics: DockPanelOverlayMetrics
    ) -> CGRect {
        let height = interactionHeight(parentFrame: parentFrame, metrics: metrics)
        let y = min(max(parentFrame.minY, metrics.screenFrame.minY), metrics.screenFrame.maxY - height)
        let rawMinX = side == .left ? parentFrame.minX : parentFrame.minX - controlPadding
        let rawMaxX = side == .left ? parentFrame.maxX + controlPadding : parentFrame.maxX
        let minX = max(rawMinX, metrics.screenFrame.minX)
        let maxX = min(rawMaxX, metrics.screenFrame.maxX)
        return CGRect(x: minX, y: y, width: max(1, maxX - minX), height: height)
    }

    static func resizeOnlyFrame(
        parentFrame: CGRect,
        side: PanelSide,
        metrics: DockPanelOverlayMetrics
    ) -> CGRect {
        let height = interactionHeight(parentFrame: parentFrame, metrics: metrics)
        let y = min(max(parentFrame.minY, metrics.screenFrame.minY), metrics.screenFrame.maxY - height)
        let resizeEdge = side == .left ? parentFrame.maxX : parentFrame.minX
        let x = side == .left
            ? resizeEdge - resizeWidth - controlPadding
            : resizeEdge - controlPadding
        return CGRect(
            x: x,
            y: y,
            width: resizeHitWidth,
            height: height
        )
    }

    static func resizeRegionFrame(in bounds: CGRect, side: PanelSide) -> CGRect {
        CGRect(
            x: side == .left ? bounds.maxX - resizeHitWidth : bounds.minX,
            y: bounds.minY,
            width: resizeHitWidth,
            height: bounds.height
        )
    }

    static func actionSurfaceFrames(in bounds: CGRect, side: PanelSide, actionCount: Int) -> [CGRect] {
        let count = max(1, actionCount)
        let resize = resizeRegionFrame(in: bounds, side: side)
        let regionMinX = side == .left ? bounds.minX + controlPadding : resize.maxX
        let regionMaxX = side == .left ? resize.minX : bounds.maxX - controlPadding
        let availableWidth = max(0, regionMaxX - regionMinX - CGFloat(count - 1) * controlGap)
        let actionWidth = availableWidth / CGFloat(count)
        let actionHeight = max(0, bounds.height - 2 * controlPadding)
        var x = regionMinX
        return (0..<count).map { _ in
            defer { x += actionWidth + controlGap }
            return CGRect(
                x: x,
                y: bounds.minY + controlPadding,
                width: actionWidth,
                height: actionHeight
            )
        }
    }
}

@MainActor
private func configureContinuousCorners(_ glass: NSGlassEffectView, radius: CGFloat) {
    glass.cornerRadius = radius
    glass.wantsLayer = true
    glass.layer?.cornerRadius = radius
    glass.layer?.cornerCurve = .continuous
    glass.layer?.masksToBounds = true
}

@MainActor
final class DockPanelResizeController {
    typealias PanelFrameProvider = @MainActor (DockPanelIdentity) -> NSRect
    typealias SideProvider = @MainActor (DockPanelIdentity) -> PanelSide
    typealias PresentationProvider = @MainActor (DockPanelIdentity) -> PanelMovementPresentation
    typealias OptionalPresentationProvider = @MainActor (DockPanelIdentity) -> PanelMovementPresentation?
    typealias DragHandler = @MainActor (DockPanelIdentity, CGFloat) -> Void
    typealias ActionHandler = @MainActor (DockPanelIdentity) -> Void

    nonisolated static let hoverDelay: TimeInterval = 0.5
    nonisolated static let hideDelay: TimeInterval = 1
    private static let fadeDuration: TimeInterval = 0.2
    private static let pollingInterval: TimeInterval = 0.25

    private let panelFrame: PanelFrameProvider
    private let panelSide: SideProvider
    private let sideTogglePresentation: PresentationProvider
    private let verticalSwapPresentation: OptionalPresentationProvider
    private let onToggleSide: ActionHandler
    private let onToggleVerticalOrder: ActionHandler
    private let onDragBegan: DragHandler
    private let onDragChanged: DragHandler
    private let onDragEnded: DragHandler
    private var interactionPanels: [DockPanelIdentity: NSPanel] = [:]
    private var interactionViews: [DockPanelIdentity: DockPanelInteractionView] = [:]
    private var metrics: DockPanelOverlayMetrics?
    private var hoverTimer: Timer?
    private var pointerDwell = DockPanelPointerDwell()
    private var hideBeganAt: Date?
    private var hideGeneration = 0
    private var isFading = false
    private var visibleHandle: DockPanelIdentity?
    private var draggingHandle: DockPanelIdentity?
    private var resizeFocusedHandle: DockPanelIdentity?

    init(
        panelFrame: @escaping PanelFrameProvider,
        panelSide: @escaping SideProvider,
        sideTogglePresentation: @escaping PresentationProvider,
        verticalSwapPresentation: @escaping OptionalPresentationProvider,
        onToggleSide: @escaping ActionHandler,
        onToggleVerticalOrder: @escaping ActionHandler,
        onDragBegan: @escaping DragHandler,
        onDragChanged: @escaping DragHandler,
        onDragEnded: @escaping DragHandler
    ) {
        self.panelFrame = panelFrame
        self.panelSide = panelSide
        self.sideTogglePresentation = sideTogglePresentation
        self.verticalSwapPresentation = verticalSwapPresentation
        self.onToggleSide = onToggleSide
        self.onToggleVerticalOrder = onToggleVerticalOrder
        self.onDragBegan = onDragBegan
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded

        for identity in DockPanelIdentity.allCases {
            let view = makeInteractionView(for: identity)
            interactionViews[identity] = view
            interactionPanels[identity] = makeOverlayPanel(contentView: view)
        }
    }

    isolated deinit {
        hoverTimer?.invalidate()
    }

    func startMonitoring() {
        hoverTimer = Timer.scheduledTimer(withTimeInterval: Self.pollingInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollCursor() }
        }
    }

    func panelFramesDidChange(metrics: DockPanelOverlayMetrics) {
        self.metrics = metrics
        guard let visibleHandle else { return }
        updateOverlays(visibleHandle)
    }

    private func makeInteractionView(for identity: DockPanelIdentity) -> DockPanelInteractionView {
        DockPanelInteractionView(
            identity: identity,
            onResizeEntered: { [weak self] in
                self?.setResizeFocus(true, for: identity)
            },
            onResizeExited: { [weak self] in
                guard let self, draggingHandle != identity else { return }
                setResizeFocus(false, for: identity)
            },
            onDragBegan: { [weak self] mouseX in
                guard let self else { return }
                draggingHandle = identity
                setResizeFocus(true, for: identity)
                showHandle(identity)
                onDragBegan(identity, mouseX)
            },
            onDragChanged: { [weak self] mouseX in
                guard let self else { return }
                onDragChanged(identity, mouseX)
                positionOverlays(identity)
            },
            onDragEnded: { [weak self] mouseX in
                guard let self else { return }
                onDragEnded(identity, mouseX)
                draggingHandle = nil
                let remainsInResizeRegion = interactionPanels[identity]?.frame.contains(NSEvent.mouseLocation) == true
                setResizeFocus(remainsInResizeRegion, for: identity)
                pollCursor()
            },
            onToggleSide: { [weak self] in
                guard let self else { return }
                cancelPendingHide()
                onToggleSide(identity)
                updateOverlays(identity)
            },
            onToggleVerticalOrder: { [weak self] in
                guard let self else { return }
                cancelPendingHide()
                onToggleVerticalOrder(identity)
                updateOverlays(identity)
            }
        )
    }

    private func makeOverlayPanel(contentView: NSView) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: DockPanelOverlayGeometry.resizeWidth, height: 1)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = contentView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.level = DockPanelWindowLevel.interaction
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        return panel
    }

    private func pollCursor() {
        if let draggingHandle {
            showHandle(draggingHandle)
            return
        }

        let cursor = NSEvent.mouseLocation
        if let visibleHandle {
            if resizeFocusedHandle == visibleHandle,
               interactionPanels[visibleHandle]?.frame.contains(cursor) != true {
                setResizeFocus(false, for: visibleHandle)
            }
            let isInsideInteractionRange = panelFrame(visibleHandle).contains(cursor)
                || interactionPanels[visibleHandle]?.frame.contains(cursor) == true
            if isInsideInteractionRange {
                cancelPendingHide()
                pointerDwell.reset()
                return
            }

            if hideBeganAt == nil {
                hideBeganAt = Date()
                hideGeneration += 1
            } else if let hideBeganAt,
                      Date().timeIntervalSince(hideBeganAt) >= Self.hideDelay,
                      !isFading {
                fadeOutOverlays(visibleHandle, generation: hideGeneration)
            }
            return
        }

        let candidate = DockPanelIdentity.allCases.first(where: { panelFrame($0).contains(cursor) })
        guard let readyCandidate = pointerDwell.update(
            candidate: candidate,
            location: cursor,
            now: Date(),
            delay: Self.hoverDelay
        ) else { return }
        showHandle(readyCandidate)
        pointerDwell.reset()
    }

    private func showHandle(_ identity: DockPanelIdentity) {
        let isNewlyVisible = visibleHandle != identity
        if isNewlyVisible {
            hideHandleImmediately()
            visibleHandle = identity
        }
        cancelPendingHide()
        updateOverlays(identity)
        guard let panel = interactionPanels[identity] else { return }
        if isNewlyVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.fadeDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.orderFrontRegardless()
        }
    }

    private func cancelPendingHide() {
        let needsFadeReversal = hideBeganAt != nil || isFading
        hideBeganAt = nil
        hideGeneration += 1
        isFading = false
        guard needsFadeReversal,
              let visibleHandle,
              let panel = interactionPanels[visibleHandle] else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 1
        }
    }

    private func fadeOutOverlays(_ identity: DockPanelIdentity, generation: Int) {
        isFading = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.interactionPanels[identity]?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self,
                      self.hideGeneration == generation,
                      self.visibleHandle == identity,
                      self.hideBeganAt != nil else { return }
                self.interactionPanels[identity]?.orderOut(nil)
                self.interactionPanels[identity]?.alphaValue = 1
                self.visibleHandle = nil
                self.resizeFocusedHandle = nil
                self.hideBeganAt = nil
                self.isFading = false
            }
        }
    }

    private func hideHandleImmediately() {
        hideGeneration += 1
        hideBeganAt = nil
        isFading = false
        if let visibleHandle {
            interactionPanels[visibleHandle]?.orderOut(nil)
            interactionPanels[visibleHandle]?.alphaValue = 1
        }
        visibleHandle = nil
        resizeFocusedHandle = nil
    }

    private func updateOverlays(_ identity: DockPanelIdentity) {
        let verticalPresentation = verticalSwapPresentation(identity)
        interactionViews[identity]?.update(
            side: panelSide(identity),
            sideToggle: sideTogglePresentation(identity),
            verticalSwap: verticalPresentation,
            resizeFocused: resizeFocusedHandle == identity
        )
        positionOverlays(identity)
    }

    private func positionOverlays(_ identity: DockPanelIdentity) {
        guard let metrics,
              let interactionPanel = interactionPanels[identity],
              interactionViews[identity] != nil else { return }
        let parentFrame = panelFrame(identity)
        let side = panelSide(identity)
        let frame = resizeFocusedHandle == identity
            ? DockPanelOverlayGeometry.resizeOnlyFrame(parentFrame: parentFrame, side: side, metrics: metrics)
            : DockPanelOverlayGeometry.expandedFrame(
                parentFrame: parentFrame,
                side: side,
                metrics: metrics
            )
        interactionPanel.setFrame(frame, display: true)
    }

    private func setResizeFocus(_ focused: Bool, for identity: DockPanelIdentity) {
        guard visibleHandle == identity || draggingHandle == identity else { return }
        let wasFocused = resizeFocusedHandle == identity
        guard wasFocused != focused else { return }
        resizeFocusedHandle = focused ? identity : nil
        cancelPendingHide()
        updateOverlays(identity)
    }
}

@MainActor
private final class DockPanelInteractionView: NSView {
    private let backgroundGlass = NSGlassEffectView()
    private let actionsView = NSView()
    private let sideSurface = NSGlassEffectView()
    private let verticalSurface = NSGlassEffectView()
    private let sideButton = NSButton(image: NSImage(), target: nil, action: nil)
    private let verticalButton = NSButton(image: NSImage(), target: nil, action: nil)
    private let resizeView: DockPanelResizeRegionView
    private let onToggleSide: () -> Void
    private let onToggleVerticalOrder: () -> Void
    private var side: PanelSide = .left

    var visibleButtonCount: Int { verticalButton.isHidden ? 1 : 2 }

    init(
        identity: DockPanelIdentity,
        onResizeEntered: @escaping () -> Void,
        onResizeExited: @escaping () -> Void,
        onDragBegan: @escaping (CGFloat) -> Void,
        onDragChanged: @escaping (CGFloat) -> Void,
        onDragEnded: @escaping (CGFloat) -> Void,
        onToggleSide: @escaping () -> Void,
        onToggleVerticalOrder: @escaping () -> Void
    ) {
        self.onToggleSide = onToggleSide
        self.onToggleVerticalOrder = onToggleVerticalOrder
        resizeView = DockPanelResizeRegionView(
            identity: identity,
            onEntered: onResizeEntered,
            onExited: onResizeExited,
            onDragBegan: onDragBegan,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded
        )
        super.init(frame: .zero)

        backgroundGlass.style = .regular
        configureContinuousCorners(backgroundGlass, radius: DockPanelOverlayGeometry.outerCornerRadius)
        backgroundGlass.contentView = actionsView
        configure(sideSurface, button: sideButton, action: #selector(toggleSide))
        configure(verticalSurface, button: verticalButton, action: #selector(toggleVerticalOrder))
        actionsView.addSubview(sideSurface)
        actionsView.addSubview(verticalSurface)
        addSubview(backgroundGlass)
        addSubview(resizeView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        backgroundGlass.frame = bounds
        actionsView.frame = backgroundGlass.bounds
        resizeView.frame = DockPanelOverlayGeometry.resizeRegionFrame(in: bounds, side: side)
        let frames = DockPanelOverlayGeometry.actionSurfaceFrames(
            in: bounds,
            side: side,
            actionCount: visibleButtonCount
        )
        sideSurface.frame = frames[0]
        sideButton.frame = sideSurface.bounds
        if !verticalButton.isHidden, frames.count > 1 {
            verticalSurface.frame = frames[1]
            verticalButton.frame = verticalSurface.bounds
        }
    }

    func update(
        side: PanelSide,
        sideToggle: PanelMovementPresentation,
        verticalSwap: PanelMovementPresentation?,
        resizeFocused: Bool
    ) {
        self.side = side
        apply(sideToggle, to: sideButton)
        verticalButton.isHidden = verticalSwap == nil
        verticalSurface.isHidden = verticalSwap == nil
        if let verticalSwap { apply(verticalSwap, to: verticalButton) }
        backgroundGlass.isHidden = resizeFocused
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private func configure(_ surface: NSGlassEffectView, button: NSButton, action: Selector) {
        surface.style = .regular
        configureContinuousCorners(surface, radius: DockPanelOverlayGeometry.actionCornerRadius)
        let content = NSView()
        content.addSubview(button)
        surface.contentView = content
        button.target = self
        button.action = action
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.setButtonType(.momentaryPushIn)
        button.refusesFirstResponder = true
    }

    private func apply(_ presentation: PanelMovementPresentation, to button: NSButton) {
        button.image = NSImage(systemSymbolName: presentation.systemImageName, accessibilityDescription: presentation.label)
        button.toolTip = presentation.label
        button.setAccessibilityLabel(presentation.label)
    }

    @objc private func toggleSide() { onToggleSide() }
    @objc private func toggleVerticalOrder() { onToggleVerticalOrder() }
}

@MainActor
private final class DockPanelResizeRegionView: NSView {
    private let onEntered: () -> Void
    private let onExited: () -> Void
    private let onDragBegan: (CGFloat) -> Void
    private let onDragChanged: (CGFloat) -> Void
    private let onDragEnded: (CGFloat) -> Void
    private let glassSurface = NSGlassEffectView()
    private let resizeImageView: NSImageView
    private var resizeTrackingArea: NSTrackingArea?

    init(
        identity: DockPanelIdentity,
        onEntered: @escaping () -> Void,
        onExited: @escaping () -> Void,
        onDragBegan: @escaping (CGFloat) -> Void,
        onDragChanged: @escaping (CGFloat) -> Void,
        onDragEnded: @escaping (CGFloat) -> Void
    ) {
        self.onEntered = onEntered
        self.onExited = onExited
        self.onDragBegan = onDragBegan
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        resizeImageView = NSImageView()
        super.init(frame: .zero)

        glassSurface.style = .regular
        configureContinuousCorners(glassSurface, radius: DockPanelOverlayGeometry.actionCornerRadius)

        resizeImageView.image = NSImage(
            systemSymbolName: "arrow.left.and.right",
            accessibilityDescription: identity == .usageOverview
                ? "调整用量概览面板宽度"
                : "调整任务活动面板宽度"
        )
        resizeImageView.imageScaling = .scaleProportionallyDown
        resizeImageView.setAccessibilityElement(true)
        resizeImageView.setAccessibilityRole(.splitter)
        resizeImageView.setAccessibilityLabel(identity == .usageOverview
            ? "调整用量概览面板宽度"
            : "调整任务活动面板宽度")
        resizeImageView.toolTip = identity == .usageOverview
            ? "拖动以调整用量概览面板宽度"
            : "拖动以调整任务活动面板宽度"
        let content = NSView()
        content.addSubview(resizeImageView)
        glassSurface.contentView = content
        addSubview(glassSurface)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        glassSurface.frame = bounds.insetBy(
            dx: DockPanelOverlayGeometry.controlPadding,
            dy: DockPanelOverlayGeometry.controlPadding
        )
        resizeImageView.frame = NSRect(
            x: 2,
            y: glassSurface.bounds.midY - 9,
            width: glassSurface.bounds.width - 4,
            height: 18
        )
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let resizeTrackingArea {
            removeTrackingArea(resizeTrackingArea)
        }
        let resizeTrackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(resizeTrackingArea)
        self.resizeTrackingArea = resizeTrackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        onEntered()
    }

    override func mouseExited(with event: NSEvent) {
        onExited()
    }

    override func mouseDown(with event: NSEvent) {
        onDragBegan(NSEvent.mouseLocation.x)
    }

    override func mouseDragged(with event: NSEvent) {
        onDragChanged(NSEvent.mouseLocation.x)
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnded(NSEvent.mouseLocation.x)
    }
}
