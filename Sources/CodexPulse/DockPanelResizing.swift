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

enum TaskActivityTextAlignment: String, CaseIterable, Equatable {
    case auto
    case left
    case right

    mutating func advance() {
        switch self {
        case .auto: self = .left
        case .left: self = .right
        case .right: self = .auto
        }
    }

    func resolved(for panelSide: PanelSide) -> TaskActivityTextAlignment {
        switch self {
        case .auto: panelSide == .left ? .left : .right
        case .left, .right: self
        }
    }

    func controlPresentation(language: AppLanguage) -> PanelMovementPresentation {
        let target: TaskActivityTextAlignment
        switch self {
        case .auto: target = .left
        case .left: target = .right
        case .right: target = .auto
        }
        let systemImageName = switch self {
        case .auto: "text.justify"
        case .left: "text.alignleft"
        case .right: "text.alignright"
        }
        return PanelMovementPresentation(
            systemImageName: systemImageName,
            label: language.alignTaskActivityText(to: target)
        )
    }
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

    func sideTogglePresentation(
        for panel: DockPanelIdentity,
        language: AppLanguage = .simplifiedChineseMainland
    ) -> PanelMovementPresentation {
        let target: PanelSide = side(for: panel) == .left ? .right : .left
        return PanelMovementPresentation(
            systemImageName: target == .left ? "arrow.left" : "arrow.right",
            label: language.movePanel(panel, to: target)
        )
    }

    func verticalSwapPresentation(
        for panel: DockPanelIdentity,
        language: AppLanguage = .simplifiedChineseMainland
    ) -> PanelMovementPresentation? {
        guard isColocated else { return nil }
        return PanelMovementPresentation(
            systemImageName: "arrow.up.arrow.down",
            label: language.swapPanelOrder(panel)
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
        static let taskTextAlignment = "dockPanels.taskActivity.textAlignment"
    }

    var arrangement: PanelArrangement
    var usageOverviewPreferredWidth: CGFloat
    var taskActivityPreferredWidth: CGFloat
    var taskActivityTextAlignment: TaskActivityTextAlignment

    init(
        arrangement: PanelArrangement = PanelArrangement(),
        usageOverviewPreferredWidth: CGFloat = DockPanelWidthGeometry.defaultWidth,
        taskActivityPreferredWidth: CGFloat = DockPanelWidthGeometry.defaultWidth,
        taskActivityTextAlignment: TaskActivityTextAlignment = .auto
    ) {
        self.arrangement = arrangement
        self.usageOverviewPreferredWidth = usageOverviewPreferredWidth
        self.taskActivityPreferredWidth = taskActivityPreferredWidth
        self.taskActivityTextAlignment = taskActivityTextAlignment
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
        taskActivityTextAlignment = defaults.string(forKey: Key.taskTextAlignment)
            .flatMap(TaskActivityTextAlignment.init(rawValue:))
            ?? .auto
    }

    func save(to defaults: UserDefaults) {
        defaults.set(Self.string(for: arrangement.usageSide), forKey: Key.usageSide)
        defaults.set(Self.string(for: arrangement.taskSide), forKey: Key.taskSide)
        defaults.set(Self.string(for: arrangement.verticalOrder), forKey: Key.verticalOrder)
        defaults.set(Double(usageOverviewPreferredWidth), forKey: Key.usagePreferredWidth)
        defaults.set(Double(taskActivityPreferredWidth), forKey: Key.taskPreferredWidth)
        defaults.set(taskActivityTextAlignment.rawValue, forKey: Key.taskTextAlignment)
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
    var taskSide: PanelSide = .right
    var taskActivityTextAlignment: TaskActivityTextAlignment = .auto
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
    static let resizeFocusAnimationDuration: TimeInterval = 0.34
    static let resizeFocusedActionScale: CGFloat = 0.98
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

    static func actionSurfacesContain(
        _ point: CGPoint,
        in bounds: CGRect,
        side: PanelSide,
        actionCount: Int
    ) -> Bool {
        actionSurfaceFrames(in: bounds, side: side, actionCount: actionCount)
            .contains { $0.contains(point) }
    }
}

struct DockPanelInteractionPresentation: Equatable {
    let backgroundFrame: CGRect
    let backgroundCornerRadius: CGFloat
    let backgroundAlpha: CGFloat
    let actionsAlpha: CGFloat
    let actionsScale: CGFloat

    static func resolve(
        in bounds: CGRect,
        resizeFocused: Bool
    ) -> Self {
        guard resizeFocused else {
            return Self(
                backgroundFrame: bounds,
                backgroundCornerRadius: DockPanelOverlayGeometry.outerCornerRadius,
                backgroundAlpha: 1,
                actionsAlpha: 1,
                actionsScale: 1
            )
        }

        return Self(
            backgroundFrame: bounds.insetBy(
                dx: DockPanelOverlayGeometry.controlPadding,
                dy: DockPanelOverlayGeometry.controlPadding
            ),
            backgroundCornerRadius: DockPanelOverlayGeometry.actionCornerRadius,
            backgroundAlpha: 0,
            actionsAlpha: 0,
            actionsScale: DockPanelOverlayGeometry.resizeFocusedActionScale
        )
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
    typealias LanguageProvider = @MainActor () -> AppLanguage
    typealias LanguageHandler = @MainActor (AppLanguage) -> Void

    nonisolated static let hoverDelay: TimeInterval = 0.5
    nonisolated static let hideDelay: TimeInterval = 1
    private static let fadeDuration: TimeInterval = 0.2
    private static let pollingInterval: TimeInterval = 0.25

    private let panelFrame: PanelFrameProvider
    private let panelSide: SideProvider
    private let sideTogglePresentation: PresentationProvider
    private let verticalSwapPresentation: OptionalPresentationProvider
    private let taskTextAlignmentPresentation: OptionalPresentationProvider
    private let language: LanguageProvider
    private let onSelectLanguage: LanguageHandler
    private let onToggleSide: ActionHandler
    private let onToggleVerticalOrder: ActionHandler
    private let onToggleTaskTextAlignment: ActionHandler
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
    private var resizeFocusTransitioningHandle: DockPanelIdentity?
    private var resizeFocusTransitionGeneration = 0

    init(
        panelFrame: @escaping PanelFrameProvider,
        panelSide: @escaping SideProvider,
        sideTogglePresentation: @escaping PresentationProvider,
        verticalSwapPresentation: @escaping OptionalPresentationProvider,
        taskTextAlignmentPresentation: @escaping OptionalPresentationProvider,
        language: @escaping LanguageProvider,
        onSelectLanguage: @escaping LanguageHandler,
        onToggleSide: @escaping ActionHandler,
        onToggleVerticalOrder: @escaping ActionHandler,
        onToggleTaskTextAlignment: @escaping ActionHandler,
        onDragBegan: @escaping DragHandler,
        onDragChanged: @escaping DragHandler,
        onDragEnded: @escaping DragHandler
    ) {
        self.panelFrame = panelFrame
        self.panelSide = panelSide
        self.sideTogglePresentation = sideTogglePresentation
        self.verticalSwapPresentation = verticalSwapPresentation
        self.taskTextAlignmentPresentation = taskTextAlignmentPresentation
        self.language = language
        self.onSelectLanguage = onSelectLanguage
        self.onToggleSide = onToggleSide
        self.onToggleVerticalOrder = onToggleVerticalOrder
        self.onToggleTaskTextAlignment = onToggleTaskTextAlignment
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
                restoreActionsIfPointerIsOverThem(for: identity)
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
                restoreActionsIfPointerIsOverThem(for: identity)
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
            },
            onToggleTaskTextAlignment: { [weak self] in
                guard let self else { return }
                cancelPendingHide()
                onToggleTaskTextAlignment(identity)
                updateOverlays(identity)
            },
            language: language(),
            onSelectLanguage: { [weak self] selectedLanguage in
                guard let self else { return }
                cancelPendingHide()
                onSelectLanguage(selectedLanguage)
                for panelIdentity in DockPanelIdentity.allCases {
                    updateOverlays(panelIdentity)
                }
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
            if resizeFocusedHandle == visibleHandle {
                restoreActionsIfPointerIsOverThem(for: visibleHandle, cursor: cursor)
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

    private func restoreActionsIfPointerIsOverThem(
        for identity: DockPanelIdentity,
        cursor: CGPoint = NSEvent.mouseLocation
    ) {
        guard resizeFocusedHandle == identity,
              let metrics,
              let interactionView = interactionViews[identity] else { return }
        let side = panelSide(identity)
        let frame = DockPanelOverlayGeometry.expandedFrame(
            parentFrame: panelFrame(identity),
            side: side,
            metrics: metrics
        )
        let localPoint = CGPoint(x: cursor.x - frame.minX, y: cursor.y - frame.minY)
        let bounds = CGRect(origin: .zero, size: frame.size)
        guard DockPanelOverlayGeometry.actionSurfacesContain(
            localPoint,
            in: bounds,
            side: side,
            actionCount: interactionView.visibleButtonCount
        ) else { return }
        setResizeFocus(false, for: identity)
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
                self.interactionViews[identity]?.dismissLanguagePicker()
                self.visibleHandle = nil
                self.resizeFocusedHandle = nil
                self.hideBeganAt = nil
                self.isFading = false
            }
        }
    }

    private func hideHandleImmediately() {
        hideGeneration += 1
        resizeFocusTransitionGeneration += 1
        hideBeganAt = nil
        isFading = false
        resizeFocusTransitioningHandle = nil
        if let visibleHandle {
            interactionPanels[visibleHandle]?.orderOut(nil)
            interactionPanels[visibleHandle]?.alphaValue = 1
            interactionViews[visibleHandle]?.dismissLanguagePicker()
        }
        visibleHandle = nil
        resizeFocusedHandle = nil
    }

    private func updateOverlays(_ identity: DockPanelIdentity, animated: Bool = false) {
        let verticalPresentation = verticalSwapPresentation(identity)
        let updateView = { [self] (completion: (@MainActor @Sendable () -> Void)?) in
            interactionViews[identity]?.update(
                side: panelSide(identity),
                sideToggle: sideTogglePresentation(identity),
                verticalSwap: verticalPresentation,
                taskTextAlignment: taskTextAlignmentPresentation(identity),
                language: language(),
                resizeFocused: resizeFocusedHandle == identity,
                animated: animated,
                completion: completion
            )
        }

        guard animated else {
            if resizeFocusTransitioningHandle != identity {
                updateView(nil)
            }
            positionOverlays(identity)
            return
        }

        resizeFocusTransitionGeneration += 1
        let generation = resizeFocusTransitionGeneration
        if resizeFocusedHandle == identity {
            resizeFocusTransitioningHandle = identity
            updateView { [weak self] in
                guard let self,
                      resizeFocusTransitionGeneration == generation,
                      resizeFocusedHandle == identity else { return }
                resizeFocusTransitioningHandle = nil
                positionOverlays(identity)
            }
        } else {
            resizeFocusTransitioningHandle = nil
            positionOverlays(identity)
            updateView(nil)
        }
    }

    private func positionOverlays(_ identity: DockPanelIdentity) {
        guard let metrics,
              let interactionPanel = interactionPanels[identity],
              interactionViews[identity] != nil else { return }
        let parentFrame = panelFrame(identity)
        let side = panelSide(identity)
        let frame = resizeFocusedHandle == identity && resizeFocusTransitioningHandle != identity
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
        updateOverlays(identity, animated: true)
    }
}

@MainActor
private final class DockPanelInteractionView: NSView {
    private let identity: DockPanelIdentity
    private let backgroundGlass = NSGlassEffectView()
    private let actionsView = NSView()
    private let languageSurface = NSGlassEffectView()
    private let languagePickerSurface = NSGlassEffectView()
    private let sideSurface = NSGlassEffectView()
    private let verticalSurface = NSGlassEffectView()
    private let taskTextAlignmentSurface = NSGlassEffectView()
    private let languageButton = NSButton(image: NSImage(), target: nil, action: nil)
    private let sideButton = NSButton(image: NSImage(), target: nil, action: nil)
    private let verticalButton = NSButton(image: NSImage(), target: nil, action: nil)
    private let taskTextAlignmentButton = NSButton(image: NSImage(), target: nil, action: nil)
    private let languagePicker: DockPanelLanguagePickerView
    private let resizeView: DockPanelResizeRegionView
    private let onToggleSide: () -> Void
    private let onToggleVerticalOrder: () -> Void
    private let onToggleTaskTextAlignment: () -> Void
    private var side: PanelSide = .left
    private var resizeFocused = false
    private var isLanguagePickerVisible = false
    private var presentationGeneration = 0

    var visibleButtonCount: Int {
        if isLanguagePickerVisible { return 1 }
        return 2 + (verticalButton.isHidden ? 0 : 1)
    }

    init(
        identity: DockPanelIdentity,
        onResizeEntered: @escaping () -> Void,
        onResizeExited: @escaping () -> Void,
        onDragBegan: @escaping (CGFloat) -> Void,
        onDragChanged: @escaping (CGFloat) -> Void,
        onDragEnded: @escaping (CGFloat) -> Void,
        onToggleSide: @escaping () -> Void,
        onToggleVerticalOrder: @escaping () -> Void,
        onToggleTaskTextAlignment: @escaping () -> Void,
        language: AppLanguage,
        onSelectLanguage: @escaping (AppLanguage) -> Void
    ) {
        self.identity = identity
        self.onToggleSide = onToggleSide
        self.onToggleVerticalOrder = onToggleVerticalOrder
        self.onToggleTaskTextAlignment = onToggleTaskTextAlignment
        languagePicker = DockPanelLanguagePickerView(
            language: language,
            onSelect: onSelectLanguage
        )
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
        actionsView.wantsLayer = true
        configure(languageSurface, button: languageButton, action: #selector(showLanguagePicker))
        configure(sideSurface, button: sideButton, action: #selector(toggleSide))
        configure(verticalSurface, button: verticalButton, action: #selector(toggleVerticalOrder))
        configure(
            taskTextAlignmentSurface,
            button: taskTextAlignmentButton,
            action: #selector(toggleTaskTextAlignment)
        )
        languagePickerSurface.style = .regular
        configureContinuousCorners(languagePickerSurface, radius: DockPanelOverlayGeometry.actionCornerRadius)
        let pickerContent = NSView()
        pickerContent.addSubview(languagePicker)
        languagePickerSurface.contentView = pickerContent
        actionsView.addSubview(languageSurface)
        actionsView.addSubview(languagePickerSurface)
        actionsView.addSubview(sideSurface)
        actionsView.addSubview(verticalSurface)
        actionsView.addSubview(taskTextAlignmentSurface)
        addSubview(backgroundGlass)
        addSubview(actionsView)
        addSubview(resizeView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        let presentation = DockPanelInteractionPresentation.resolve(
            in: bounds,
            resizeFocused: resizeFocused
        )
        backgroundGlass.frame = presentation.backgroundFrame
        actionsView.frame = bounds
        resizeView.frame = DockPanelOverlayGeometry.resizeRegionFrame(in: bounds, side: side)
        let frames = DockPanelOverlayGeometry.actionSurfaceFrames(
            in: bounds,
            side: side,
            actionCount: visibleButtonCount
        )
        if isLanguagePickerVisible {
            languagePickerSurface.frame = frames[0]
            languagePicker.frame = languagePickerSurface.bounds
            return
        }
        var index = 0
        if identity == .usageOverview {
            languageSurface.frame = frames[index]
            languageButton.frame = languageSurface.bounds
            index += 1
        } else {
            taskTextAlignmentSurface.frame = frames[index]
            taskTextAlignmentButton.frame = taskTextAlignmentSurface.bounds
            index += 1
        }
        sideSurface.frame = frames[index]
        sideButton.frame = sideSurface.bounds
        index += 1
        if !verticalButton.isHidden, frames.count > index {
            verticalSurface.frame = frames[index]
            verticalButton.frame = verticalSurface.bounds
        }
    }

    func update(
        side: PanelSide,
        sideToggle: PanelMovementPresentation,
        verticalSwap: PanelMovementPresentation?,
        taskTextAlignment: PanelMovementPresentation?,
        language: AppLanguage,
        resizeFocused: Bool,
        animated: Bool,
        completion: (@MainActor @Sendable () -> Void)?
    ) {
        self.side = side
        languagePicker.update(language: language)
        languageButton.image = NSImage(
            systemSymbolName: "globe",
            accessibilityDescription: language.changeLanguage
        )
        languageButton.toolTip = language.changeLanguage
        languageButton.setAccessibilityLabel(language.changeLanguage)
        languageSurface.isHidden = identity != .usageOverview || isLanguagePickerVisible
        languagePickerSurface.isHidden = identity != .usageOverview || !isLanguagePickerVisible
        taskTextAlignmentSurface.isHidden = taskTextAlignment == nil || isLanguagePickerVisible
        taskTextAlignmentButton.isHidden = taskTextAlignment == nil || isLanguagePickerVisible
        if let taskTextAlignment { apply(taskTextAlignment, to: taskTextAlignmentButton) }
        sideSurface.isHidden = isLanguagePickerVisible
        sideButton.isHidden = isLanguagePickerVisible
        apply(sideToggle, to: sideButton)
        verticalButton.isHidden = verticalSwap == nil || isLanguagePickerVisible
        verticalSurface.isHidden = verticalSwap == nil || isLanguagePickerVisible
        if let verticalSwap { apply(verticalSwap, to: verticalButton) }
        resizeView.update(language: language)
        needsLayout = true
        layoutSubtreeIfNeeded()
        self.resizeFocused = resizeFocused
        presentationGeneration += 1
        let generation = presentationGeneration
        if !resizeFocused {
            backgroundGlass.isHidden = false
        }
        applyPresentation(animated: animated, generation: generation, completion: completion)
    }

    private func applyPresentation(
        animated: Bool,
        generation: Int,
        completion: (@MainActor @Sendable () -> Void)?
    ) {
        let presentation = DockPanelInteractionPresentation.resolve(
            in: bounds,
            resizeFocused: resizeFocused
        )
        let changes = {
            self.backgroundGlass.animator().frame = presentation.backgroundFrame
            self.backgroundGlass.animator().alphaValue = presentation.backgroundAlpha
            self.actionsView.animator().alphaValue = presentation.actionsAlpha
        }

        animateActionsScale(to: presentation.actionsScale, animated: animated)
        animateBackgroundCornerRadius(to: presentation.backgroundCornerRadius, animated: animated)

        guard animated else {
            backgroundGlass.frame = presentation.backgroundFrame
            backgroundGlass.alphaValue = presentation.backgroundAlpha
            actionsView.alphaValue = presentation.actionsAlpha
            backgroundGlass.isHidden = resizeFocused
            completion?()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = DockPanelOverlayGeometry.resizeFocusAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            changes()
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self,
                      self.presentationGeneration == generation else { return }
                if self.resizeFocused {
                    self.backgroundGlass.isHidden = true
                }
                completion?()
            }
        }
    }

    private func animateActionsScale(to scale: CGFloat, animated: Bool) {
        guard let layer = actionsView.layer else { return }
        let target = CATransform3DMakeScale(scale, scale, 1)
        guard animated else {
            layer.removeAnimation(forKey: "resizeFocusScale")
            layer.transform = target
            return
        }

        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = layer.presentation()?.transform ?? layer.transform
        animation.toValue = target
        animation.duration = DockPanelOverlayGeometry.resizeFocusAnimationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.transform = target
        layer.add(animation, forKey: "resizeFocusScale")
    }

    private func animateBackgroundCornerRadius(to radius: CGFloat, animated: Bool) {
        guard let layer = backgroundGlass.layer else { return }
        let currentRadius = layer.presentation()?.cornerRadius ?? layer.cornerRadius
        backgroundGlass.cornerRadius = radius
        layer.cornerRadius = radius
        guard animated else {
            layer.removeAnimation(forKey: "resizeFocusCornerRadius")
            return
        }

        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.fromValue = currentRadius
        animation.toValue = radius
        animation.duration = DockPanelOverlayGeometry.resizeFocusAnimationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "resizeFocusCornerRadius")
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
    @objc private func toggleTaskTextAlignment() { onToggleTaskTextAlignment() }

    @objc private func showLanguagePicker() {
        guard identity == .usageOverview else { return }
        isLanguagePickerVisible = true
        languageSurface.isHidden = true
        sideSurface.isHidden = true
        verticalSurface.isHidden = true
        languagePickerSurface.isHidden = false
        needsLayout = true
    }

    func dismissLanguagePicker() {
        guard isLanguagePickerVisible else { return }
        isLanguagePickerVisible = false
        languagePickerSurface.isHidden = true
        languageSurface.isHidden = identity != .usageOverview
        sideSurface.isHidden = false
        needsLayout = true
    }
}

@MainActor
private final class DockPanelLanguagePickerView: NSView {
    private var language: AppLanguage
    private let onSelect: (AppLanguage) -> Void
    private var accumulatedScroll: CGFloat = 0
    private var accumulatedDrag: CGFloat = 0
    private var lastDragY: CGFloat?
    private var didChangeSelectionWhileDragging = false

    init(language: AppLanguage, onSelect: @escaping (AppLanguage) -> Void) {
        self.language = language
        self.onSelect = onSelect
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.incrementor)
        updateAccessibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var isFlipped: Bool { true }

    func update(language: AppLanguage) {
        guard self.language != language else {
            updateAccessibility()
            return
        }
        self.language = language
        accumulatedScroll = 0
        updateAccessibility()
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        guard delta != 0 else { return }
        if event.hasPreciseScrollingDeltas {
            accumulatedScroll += delta
            guard abs(accumulatedScroll) >= 12 else { return }
            select(offset: accumulatedScroll > 0 ? -1 : 1)
            accumulatedScroll = 0
        } else {
            select(offset: delta > 0 ? -1 : 1)
        }
    }

    override func mouseDown(with event: NSEvent) {
        accumulatedDrag = 0
        lastDragY = convert(event.locationInWindow, from: nil).y
        didChangeSelectionWhileDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        let y = convert(event.locationInWindow, from: nil).y
        guard let lastDragY else {
            self.lastDragY = y
            return
        }
        accumulatedDrag += y - lastDragY
        self.lastDragY = y

        while abs(accumulatedDrag) >= DockPanelLanguagePickerGeometry.dragStep {
            let offset = accumulatedDrag < 0 ? 1 : -1
            select(offset: offset)
            accumulatedDrag += accumulatedDrag < 0
                ? DockPanelLanguagePickerGeometry.dragStep
                : -DockPanelLanguagePickerGeometry.dragStep
            didChangeSelectionWhileDragging = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            accumulatedDrag = 0
            lastDragY = nil
            didChangeSelectionWhileDragging = false
        }
        guard !didChangeSelectionWhileDragging else { return }
        let y = convert(event.locationInWindow, from: nil).y
        select(offset: DockPanelLanguagePickerGeometry.selectionOffset(forClickY: y, in: bounds))
    }

    override func accessibilityPerformIncrement() -> Bool {
        select(offset: 1)
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        select(offset: -1)
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let languages = AppLanguage.allCases
        guard let selectedIndex = languages.firstIndex(of: language) else { return }
        for offset in -1...1 {
            let index = (selectedIndex + offset + languages.count) % languages.count
            let row = DockPanelLanguagePickerGeometry.rowFrame(offset: offset, in: bounds)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byTruncatingTail
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.62)
            shadow.shadowBlurRadius = 0.45
            shadow.shadowOffset = .zero
            (languages[index].displayName as NSString).draw(
                in: row,
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: offset == 0 ? 10 : 8, weight: offset == 0 ? .semibold : .regular),
                    .foregroundColor: NSColor.white.withAlphaComponent(offset == 0 ? 1 : 0.46),
                    .paragraphStyle: paragraph,
                    .shadow: shadow,
                ]
            )
        }
    }

    private func select(offset: Int) {
        let languages = AppLanguage.allCases
        guard let current = languages.firstIndex(of: language) else { return }
        language = languages[(current + offset + languages.count) % languages.count]
        updateAccessibility()
        needsDisplay = true
        onSelect(language)
    }

    private func updateAccessibility() {
        setAccessibilityLabel(language.languagePickerLabel)
        setAccessibilityValue(language.displayName)
        toolTip = language.languagePickerLabel
    }
}

struct DockPanelLanguagePickerGeometry {
    static let topPadding: CGFloat = 4
    static let itemHeight: CGFloat = 14
    static let itemSpacing: CGFloat = 16
    static let dragStep: CGFloat = 14

    static func rowFrame(offset: Int, in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.minX + 4,
            y: bounds.midY + topPadding + CGFloat(offset) * itemSpacing - itemHeight / 2,
            width: max(0, bounds.width - 8),
            height: itemHeight
        )
    }

    static func selectionOffset(forClickY y: CGFloat, in bounds: CGRect) -> Int {
        let centerY = bounds.midY + topPadding
        if y < centerY - itemSpacing / 2 { return -1 }
        if y > centerY + itemSpacing / 2 { return 1 }
        return 0
    }
}

@MainActor
private final class DockPanelResizeRegionView: NSView {
    private let identity: DockPanelIdentity
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
        self.identity = identity
        self.onEntered = onEntered
        self.onExited = onExited
        self.onDragBegan = onDragBegan
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        resizeImageView = NSImageView()
        super.init(frame: .zero)

        glassSurface.style = .regular
        configureContinuousCorners(glassSurface, radius: DockPanelOverlayGeometry.actionCornerRadius)

        resizeImageView.imageScaling = .scaleProportionallyDown
        resizeImageView.setAccessibilityElement(true)
        resizeImageView.setAccessibilityRole(.splitter)
        update(language: .simplifiedChineseMainland)
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

    func update(language: AppLanguage) {
        let label = language.resizeLabel(identity, tooltip: false)
        resizeImageView.image = NSImage(
            systemSymbolName: "arrow.left.and.right",
            accessibilityDescription: label
        )
        resizeImageView.setAccessibilityLabel(label)
        resizeImageView.toolTip = language.resizeLabel(identity, tooltip: true)
    }

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
