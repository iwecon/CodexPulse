import AppKit
import Observation
import SwiftUI

@main
struct CodexPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = UsageModel()
    private var panelController: DockPanelController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        observeSystemActivity()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        LaunchAtLoginManager.enableIfNeeded()
        panelController = DockPanelController(model: model)
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        model.stop()
    }

    private func observeSystemActivity() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(sessionDidResignActive(_:)),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(sessionDidBecomeActive(_:)),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(screensDidSleep(_:)),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(screensDidWake(_:)),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    @objc private func sessionDidResignActive(_ notification: Notification) {
        model.setRefreshSuspended(true, for: .sessionInactive)
    }

    @objc private func sessionDidBecomeActive(_ notification: Notification) {
        model.setRefreshSuspended(false, for: .sessionInactive)
    }

    @objc private func screensDidSleep(_ notification: Notification) {
        model.setRefreshSuspended(true, for: .screensAsleep)
    }

    @objc private func screensDidWake(_ notification: Notification) {
        model.setRefreshSuspended(false, for: .screensAsleep)
    }
}

@MainActor @Observable
final class UsageModel {
    var snapshot = Snapshot()
    var tasks: [TaskExecution] = []
    private(set) var isTaskStatusAnimationPaused = false
    private let scanner = UsageScanner()
    private let taskMonitor = TaskMonitor()
    private var started = false
    private var refreshGate = RefreshActivityGate()
    private var usageLoopTask: Task<Void, Never>?
    private var taskLoopTask: Task<Void, Never>?

    func start() {
        guard !started else { return }
        started = true
        startLoopsIfAllowed()
    }

    func stop() {
        started = false
        stopLoops()
    }

    func setRefreshSuspended(
        _ suspended: Bool,
        for reason: RefreshSuspensionReason
    ) {
        let transition = refreshGate.setSuspended(suspended, for: reason)
        isTaskStatusAnimationPaused = !refreshGate.allowsRefresh
        switch transition {
        case .becameSuspended:
            stopLoops()
        case .becameActive:
            startLoopsIfAllowed()
        case .unchanged:
            break
        }
    }

    private func startLoopsIfAllowed() {
        guard started, refreshGate.allowsRefresh else { return }
        if usageLoopTask == nil {
            usageLoopTask = Task { [weak self] in
                await self?.runUsageLoop()
            }
        }
        if taskLoopTask == nil {
            taskLoopTask = Task { [weak self] in
                await self?.runTaskLoop()
            }
        }
    }

    private func stopLoops() {
        usageLoopTask?.cancel()
        usageLoopTask = nil
        taskLoopTask?.cancel()
        taskLoopTask = nil
    }

    private func runUsageLoop() async {
        await refresh()
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                return
            }
            await refresh()
        }
    }

    private func runTaskLoop() async {
        while !Task.isCancelled {
            guard refreshGate.allowsRefresh else { return }
            let newTasks = await taskMonitor.scan()
            guard !Task.isCancelled, refreshGate.allowsRefresh else { return }
            if newTasks != tasks { tasks = newTasks }
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
        }
    }

    func refresh() async {
        guard refreshGate.allowsRefresh else { return }
        let newSnapshot = await scanner.scan()
        guard !Task.isCancelled, refreshGate.allowsRefresh else { return }
        if !snapshot.hasSameContent(as: newSnapshot) { snapshot = newSnapshot }
    }

    nonisolated static func compact(_ number: Int) -> String {
        if number >= 1_000_000_000_000 { return String(format: "%.1fT", Double(number) / 1_000_000_000_000) }
        if number >= 1_000_000_000 { return String(format: "%.1fB", Double(number) / 1_000_000_000) }
        if number >= 1_000_000 { return String(format: "%.1fM", Double(number) / 1_000_000) }
        if number >= 1_000 { return String(format: "%.1fK", Double(number) / 1_000) }
        return "\(number)"
    }
}

@MainActor
final class DockPanelController {
    private struct ResizeDrag {
        let identity: DockPanelIdentity
        let startingMouseX: CGFloat
        let startingWidth: CGFloat
    }

    private let leftPanel: NSPanel
    private let rightPanel: NSPanel
    private let model: UsageModel
    private let presentationState: DockPanelPresentationState
    private let defaults: UserDefaults
    private var placementTimer: Timer?
    private var arrangement: PanelArrangement
    private var usageOverviewPreferredWidth: CGFloat
    private var taskActivityPreferredWidth: CGFloat
    private var resizeDrag: ResizeDrag?
    private let wallpaperAppearanceSampler = WallpaperAppearanceSampler()
    private var wallpaperAppearanceTask: Task<Void, Never>?
    private var wallpaperAppearanceGeneration = 0
    private var usageOverviewAppearance: PanelSemanticAppearance?
    private var taskActivityAppearance: PanelSemanticAppearance?
    private var effectiveAppearanceObservation: NSKeyValueObservation?
    private var observedSystemAppearance: PanelSemanticAppearance?
    private var appearanceChangeResampleTask: Task<Void, Never>?
    private lazy var sessionLinkController = CodexSessionLinkController()
    private lazy var resizeController = DockPanelResizeController(
        panelFrame: { [weak self] identity in
            guard let self else { return .zero }
            return panel(for: identity).frame
        },
        panelSide: { [weak self] identity in
            self?.arrangement.side(for: identity) ?? PanelArrangement().side(for: identity)
        },
        sideTogglePresentation: { [weak self] identity in
            self?.arrangement.sideTogglePresentation(for: identity)
                ?? PanelArrangement().sideTogglePresentation(for: identity)
        },
        verticalSwapPresentation: { [weak self] identity in
            self?.arrangement.verticalSwapPresentation(for: identity)
        },
        onToggleSide: { [weak self] identity in
            self?.togglePanelSide(identity)
        },
        onToggleVerticalOrder: { [weak self] identity in
            self?.toggleVerticalOrder(for: identity)
        },
        onDragBegan: { [weak self] identity, mouseX in
            self?.beginResize(identity, mouseX: mouseX)
        },
        onDragChanged: { [weak self] identity, mouseX in
            self?.continueResize(identity, mouseX: mouseX)
        },
        onDragEnded: { [weak self] identity, mouseX in
            self?.endResize(identity, mouseX: mouseX)
        }
    )

    init(model: UsageModel, defaults: UserDefaults = .standard) {
        let preferences = DockPanelPreferences(defaults: defaults)
        let taskPlan = TaskExecutionLayout.plan(
            for: model.tasks,
            panelWidth: preferences.taskActivityPreferredWidth
        )
        self.model = model
        self.defaults = defaults
        arrangement = preferences.arrangement
        usageOverviewPreferredWidth = preferences.usageOverviewPreferredWidth
        taskActivityPreferredWidth = preferences.taskActivityPreferredWidth
        let presentationState = DockPanelPresentationState()
        presentationState.usageSide = preferences.arrangement.usageSide
        self.presentationState = presentationState
        leftPanel = Self.panel(
            rootView: AnyView(RecentUsageView(model: model, presentation: presentationState)),
            size: NSSize(width: preferences.usageOverviewPreferredWidth, height: 56)
        )
        rightPanel = Self.panel(
            rootView: AnyView(TaskExecutionView(model: model)),
            size: NSSize(width: preferences.taskActivityPreferredWidth, height: taskPlan.panelHeight)
        )
        observedSystemAppearance = Self.currentSystemAppearance
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.positionPanels() }
        }
        effectiveAppearanceObservation = NSApplication.shared.observe(
            \.effectiveAppearance,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.effectiveAppearanceDidChange()
            }
        }
        placementTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.positionPanels() }
        }
        observeTaskChanges()
        positionPanels()
        leftPanel.orderFrontRegardless()
        rightPanel.orderFrontRegardless()
        resizeController.startMonitoring()
    }

    private static func panel(rootView: AnyView, size: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: rootView.allowsHitTesting(false))
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = DockPanelWindowLevel.content
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        return panel
    }

    private func positionPanels() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.frame
        let visible = screen.visibleFrame
        let edge = dockEdge(frame: frame, visible: visible)
        let inset: CGFloat = 2
        let gap: CGFloat = 10
        let dockFrame = edge == .bottom || edge == .unknown ? bottomDockFrame(on: screen) : nil
        let provisionalPlan = TaskExecutionLayout.plan(for: model.tasks, panelWidth: rightPanel.frame.width)
        let provisionalFrames = DockPanelPlacementGeometry.frames(
            screenFrame: frame,
            visibleFrame: visible,
            dockFrame: dockFrame,
            dockEdge: edge,
            arrangement: arrangement,
            sizes: .init(
                usagePreferredWidth: usageOverviewPreferredWidth,
                taskPreferredWidth: taskActivityPreferredWidth,
                usageHeight: leftPanel.frame.height,
                taskHeight: provisionalPlan.panelHeight
            ),
            inset: inset,
            gap: gap
        )
        let taskWidth = provisionalFrames[.taskActivity]?.width ?? rightPanel.frame.width
        let taskPlan = TaskExecutionLayout.plan(for: model.tasks, panelWidth: taskWidth)
        let frames = DockPanelPlacementGeometry.frames(
            screenFrame: frame,
            visibleFrame: visible,
            dockFrame: dockFrame,
            dockEdge: edge,
            arrangement: arrangement,
            sizes: .init(
                usagePreferredWidth: usageOverviewPreferredWidth,
                taskPreferredWidth: taskActivityPreferredWidth,
                usageHeight: leftPanel.frame.height,
                taskHeight: taskPlan.panelHeight
            ),
            inset: inset,
            gap: gap
        )
        if let usageFrame = frames[.usageOverview] {
            if leftPanel.frame != usageFrame { leftPanel.setFrame(usageFrame, display: true) }
        }
        if let taskFrame = frames[.taskActivity] {
            if rightPanel.frame != taskFrame { rightPanel.setFrame(taskFrame, display: true) }
        }
        sessionLinkController.update(taskPanelFrame: rightPanel.frame, plan: taskPlan)
        resizeController.panelFramesDidChange(metrics: DockPanelOverlayMetrics(
            screenFrame: frame,
            dockFrame: dockFrame,
            dockEdge: edge
        ))
        updateWallpaperAppearances(on: screen)
    }

    private func updateWallpaperAppearances(on screen: NSScreen) {
        wallpaperAppearanceGeneration += 1
        let generation = wallpaperAppearanceGeneration
        wallpaperAppearanceTask?.cancel()

        let workspace = NSWorkspace.shared
        guard let url = workspace.desktopImageURL(for: screen) else { return }
        let options = workspace.desktopImageOptions(for: screen)
        let scalingRawValue = (options?[.imageScaling] as? NSNumber)?.uintValue
        let scaling = scalingRawValue.flatMap(NSImageScaling.init(rawValue:))
            ?? .scaleProportionallyUpOrDown
        let allowClipping = (options?[.allowClipping] as? NSNumber)?.boolValue ?? false
        let fillColor = Self.wallpaperRGB(from: options?[.fillColor] as? NSColor)
        let screenOrigin = screen.frame.origin
        let request = WallpaperAppearanceRequest(
            url: url,
            screenSize: screen.frame.size,
            scalingMode: .desktopImageMode(scaling: scaling, allowClipping: allowClipping),
            fillColor: fillColor,
            panelRegions: [
                WallpaperPanelRegion(
                    identifier: 0,
                    frame: leftPanel.frame.offsetBy(dx: -screenOrigin.x, dy: -screenOrigin.y),
                    previousAppearance: usageOverviewAppearance
                ),
                WallpaperPanelRegion(
                    identifier: 1,
                    frame: rightPanel.frame.offsetBy(dx: -screenOrigin.x, dy: -screenOrigin.y),
                    previousAppearance: taskActivityAppearance
                )
            ]
        )
        wallpaperAppearanceTask = Task { [weak self, wallpaperAppearanceSampler] in
            let appearances = await wallpaperAppearanceSampler.appearances(for: request)
            guard !Task.isCancelled, let self,
                  wallpaperAppearanceGeneration == generation else {
                return
            }
            for result in appearances {
                let previousAppearance = result.identifier == 0
                    ? usageOverviewAppearance
                    : taskActivityAppearance
                guard previousAppearance != result.appearance else { continue }
                apply(result.appearance, toPanelWithIdentifier: result.identifier)
            }
        }
    }

    private func effectiveAppearanceDidChange() {
        let systemAppearance = Self.currentSystemAppearance
        guard observedSystemAppearance != systemAppearance else { return }
        observedSystemAppearance = systemAppearance

        wallpaperAppearanceGeneration += 1
        wallpaperAppearanceTask?.cancel()
        appearanceChangeResampleTask?.cancel()

        apply(systemAppearance, toPanelWithIdentifier: 0)
        apply(systemAppearance, toPanelWithIdentifier: 1)

        appearanceChangeResampleTask = Task { [weak self, wallpaperAppearanceSampler] in
            do {
                try await Task.sleep(for: .milliseconds(750))
            } catch {
                return
            }
            await wallpaperAppearanceSampler.invalidateCache()
            guard let self else { return }
            usageOverviewAppearance = nil
            taskActivityAppearance = nil
            positionPanels()
        }
    }

    private func apply(
        _ semanticAppearance: PanelSemanticAppearance,
        toPanelWithIdentifier identifier: Int
    ) {
        let appearance = NSAppearance(
            named: semanticAppearance == .dark ? .darkAqua : .aqua
        )
        if identifier == 0 {
            usageOverviewAppearance = semanticAppearance
            leftPanel.appearance = appearance
        } else {
            taskActivityAppearance = semanticAppearance
            rightPanel.appearance = appearance
            sessionLinkController.setAppearance(appearance)
        }
    }

    private static var currentSystemAppearance: PanelSemanticAppearance {
        NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .dark
            : .light
    }

    private static func wallpaperRGB(from color: NSColor?) -> WallpaperRGB? {
        guard let rgb = color?.usingColorSpace(.sRGB) else { return nil }
        return WallpaperRGB(
            red: Double(rgb.redComponent),
            green: Double(rgb.greenComponent),
            blue: Double(rgb.blueComponent)
        )
    }

    private func observeTaskChanges() {
        withObservationTracking {
            _ = model.tasks
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                positionPanels()
                observeTaskChanges()
            }
        }
    }

    private func panel(for identity: DockPanelIdentity) -> NSPanel {
        switch identity {
        case .usageOverview: leftPanel
        case .taskActivity: rightPanel
        }
    }

    private func beginResize(_ identity: DockPanelIdentity, mouseX: CGFloat) {
        resizeDrag = ResizeDrag(
            identity: identity,
            startingMouseX: mouseX,
            startingWidth: panel(for: identity).frame.width
        )
    }

    private func continueResize(_ identity: DockPanelIdentity, mouseX: CGFloat) {
        guard let resizeDrag, resizeDrag.identity == identity else { return }
        let anchor = arrangement.side(for: identity).resizeAnchor
        let width = DockPanelWidthGeometry.preferredWidth(
            startingWidth: resizeDrag.startingWidth,
            horizontalDrag: mouseX - resizeDrag.startingMouseX,
            anchor: anchor
        )
        switch identity {
        case .usageOverview: usageOverviewPreferredWidth = width
        case .taskActivity: taskActivityPreferredWidth = width
        }
        positionPanels()
    }

    private func endResize(_ identity: DockPanelIdentity, mouseX: CGFloat) {
        guard resizeDrag?.identity == identity else { return }
        continueResize(identity, mouseX: mouseX)
        resizeDrag = nil
        savePreferences()
    }

    private func togglePanelSide(_ identity: DockPanelIdentity) {
        arrangement.toggleSide(for: identity)
        presentationState.usageSide = arrangement.usageSide
        savePreferences()
        positionPanels()
    }

    private func toggleVerticalOrder(for identity: DockPanelIdentity) {
        guard arrangement.verticalSwapPresentation(for: identity) != nil else { return }
        arrangement.toggleVerticalOrder()
        savePreferences()
        positionPanels()
    }

    private func savePreferences() {
        DockPanelPreferences(
            arrangement: arrangement,
            usageOverviewPreferredWidth: usageOverviewPreferredWidth,
            taskActivityPreferredWidth: taskActivityPreferredWidth
        ).save(to: defaults)
    }

    private func bottomDockFrame(on screen: NSScreen) -> CGRect? {
        guard let dockPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier,
              let mainScreen = NSScreen.screens.first,
              let windowInfo = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        return windowInfo.compactMap { item -> CGRect? in
            guard (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == dockPID,
                  let dictionary = item[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary),
                  bounds.width > bounds.height * 2,
                  bounds.height < 200 else {
                return nil
            }
            let appKitBounds = DockPanelPlacementGeometry.appKitRect(
                fromQuartz: bounds,
                mainScreenMaxY: mainScreen.frame.maxY
            )
            guard appKitBounds.intersects(screen.frame) else { return nil }
            return appKitBounds
        }
        .max { $0.width < $1.width }
    }

    private func dockEdge(frame: NSRect, visible: NSRect) -> DockEdge {
        let left = visible.minX - frame.minX
        let right = frame.maxX - visible.maxX
        let bottom = visible.minY - frame.minY
        if left > max(right, bottom), left > 2 { return .left }
        if right > max(left, bottom), right > 2 { return .right }
        if bottom > 2 { return .bottom }
        return .unknown
    }
}

enum DockPanelContentLayout {
    static let horizontalInset: CGFloat = 6
    static let bottomInset: CGFloat = 4
}

private struct DockPanelTextOutline: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.shadow(
            color: colorScheme == .light
                ? Color.white.opacity(0.28)
                : Color.black.opacity(0.62),
            radius: colorScheme == .light ? 0.25 : 0.45
        )
    }
}

private extension Text {
    func dockPanelTextOutline() -> some View {
        modifier(DockPanelTextOutline())
    }
}

struct RecentUsageView: View {
    @Bindable var model: UsageModel
    let presentation: DockPanelPresentationState
    private var days: [DailyUsage] { model.snapshot.dailyUsage }
    private var maximum: Int { max(days.map(\.total).max() ?? 0, 1) }
    private var total: Int { days.reduce(0) { $0 + $1.total } }

    var body: some View {
        HStack(spacing: 6) {
            if presentation.usageSide == .left {
                trendView
                Divider().frame(height: 34)
                WeeklyLimitView(model: model, alignTrailing: false)
            } else {
                WeeklyLimitView(model: model, alignTrailing: true)
                Divider().frame(height: 34)
                trendView
            }
        }
        .padding(.horizontal, DockPanelContentLayout.horizontalInset)
        .padding(.bottom, DockPanelContentLayout.bottomInset)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: presentation.usageSide == .left ? .bottomLeading : .bottomTrailing
        )
    }

    private var trendView: some View {
        VStack(alignment: presentation.usageSide == .left ? .leading : .trailing, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("近 14 天")
                    .dockPanelTextOutline()
                    .font(.system(size: 10, weight: .semibold))
                Spacer(minLength: 2)
                Text(UsageModel.compact(total))
                    .dockPanelTextOutline()
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(day.total == 0 ? Color.secondary.opacity(0.16) : Color.accentColor.opacity(0.38 + 0.62 * Double(day.total) / Double(maximum)))
                        .frame(maxWidth: .infinity)
                        .frame(height: 3 + 18 * CGFloat(day.total) / CGFloat(maximum))
                        .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue("\(day.total) tokens")
                }
            }
            .frame(height: 21, alignment: .bottom)
            HStack {
                Text(days.first?.date.formatted(.dateTime.month().day()) ?? "—")
                    .dockPanelTextOutline()
                Spacer()
                HStack(spacing: 3) {
                    Text(days.last?.date.formatted(.dateTime.month().day()) ?? "—")
                        .dockPanelTextOutline()
                    Text(UsageModel.compact(days.last?.total ?? 0))
                        .dockPanelTextOutline()
                        .monospacedDigit()
                }
            }
            .font(.system(size: 8))
            .foregroundStyle(.secondary)
        }
        .frame(minWidth: 116)
    }
}

struct WeeklyLimitView: View {
    private struct AverageDailyAvailableText: View {
        let used: Double
        let resetsAt: Date

        var body: some View {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let value = WeeklyLimitPacing.averageDailyAvailablePercent(
                    usedPercent: used,
                    resetsAt: resetsAt,
                    now: context.date
                )
                Text(String(format: "日均可用 %.1f%%", value))
                    .dockPanelTextOutline()
                    .monospacedDigit()
                    .lineLimit(1)
                    .layoutPriority(1)
            }
        }
    }

    private struct CountdownText: View {
        let reset: Date

        var body: some View {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(WeeklyLimitCountdown.format(reset: reset, now: context.date))
                    .dockPanelTextOutline()
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
    }

    @Bindable var model: UsageModel
    let alignTrailing: Bool

    private var weekly: RateWindow? {
        model.snapshot.limits
            .filter { (5_000...20_000).contains($0.minutes) }
            .min { abs($0.minutes - 10_080) < abs($1.minutes - 10_080) }
    }

    var body: some View {
        if let weekly {
            let used = min(max(weekly.used, 0), 100)
            VStack(alignment: alignTrailing ? .trailing : .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("周限额")
                        .dockPanelTextOutline()
                        .fontWeight(.semibold)
                    Spacer(minLength: 2)
                    Text("已用 \(Int(used.rounded()))%")
                        .dockPanelTextOutline()
                    Text("剩余 \(Int((100 - used).rounded()))%")
                        .dockPanelTextOutline()
                }
                .font(.system(size: 9))
                .lineLimit(1)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.secondary.opacity(0.16))
                        Capsule()
                            .fill(used > 85 ? Color.orange : Color.accentColor)
                            .frame(width: proxy.size.width * used / 100)
                    }
                }
                .frame(height: 4)
                HStack(spacing: 4) {
                    Text("重置 \(weekly.resetsAt.formatted(.dateTime.month().day().hour().minute()))")
                        .dockPanelTextOutline()
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    AverageDailyAvailableText(used: used, resetsAt: weekly.resetsAt)
                }
                CountdownText(reset: weekly.resetsAt)
            }
            .font(.system(size: 8))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
        } else {
            VStack(alignment: alignTrailing ? .trailing : .leading, spacing: 2) {
                Text("周额度")
                    .dockPanelTextOutline()
                    .fontWeight(.semibold)
                Text("暂无数据")
                    .dockPanelTextOutline()
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 9))
            .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
        }
    }
}

enum WeeklyLimitCountdown {
    static func format(reset: Date, now: Date) -> String {
        let totalSeconds = max(0, Int(reset.timeIntervalSince(now)))
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        if days > 0 {
            return "倒计时 \(days)天 \(hours)小时 \(minutes)分钟"
        }
        if hours > 0 {
            return "倒计时 \(hours)小时 \(minutes)分钟"
        }
        if minutes > 0 {
            return "倒计时 \(minutes)分钟"
        }
        return "倒计时 \(totalSeconds)秒"
    }
}

enum WeeklyLimitPacing {
    private static let secondsPerDay: TimeInterval = 86_400

    static func averageDailyAvailablePercent(
        usedPercent: Double,
        resetsAt: Date,
        now: Date
    ) -> Double {
        let remainingPercent = 100 - min(max(usedPercent, 0), 100)
        let remainingDays = resetsAt.timeIntervalSince(now) / secondsPerDay
        guard remainingDays > 0 else { return 0 }
        return remainingPercent / remainingDays
    }
}

struct TaskExecutionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct TaskStatusIndicator: View {
        let isCompleted: Bool
        let isAnimationPaused: Bool
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            Group {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.green)
                } else {
                    loadingRing
                }
            }
            .frame(width: 9, height: 9)
        }

        private var loadingRing: some View {
            TimelineView(
                .animation(
                    minimumInterval: 1.0 / 12.0,
                    paused: reduceMotion || isAnimationPaused
                )
            ) { context in
                let cycle = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 0.9) / 0.9

                Circle()
                    .trim(from: 0, to: 0.8)
                    .stroke(
                        AngularGradient(
                            stops: [
                                .init(color: Color.accentColor.opacity(0.08), location: 0),
                                .init(color: Color.accentColor.opacity(0.4), location: 0.55),
                                .init(color: Color.accentColor, location: 1)
                            ],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(288)
                        ),
                        style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(cycle * 360 - 90))
                    .frame(width: 7, height: 7)
            }
        }
    }

    private struct TaskDurationText: View {
        let task: TaskExecution

        var body: some View {
            if let completedAt = task.completedAt {
                durationText(now: completedAt)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    durationText(now: context.date)
                }
            }
        }

        private func durationText(now: Date) -> some View {
            Text(Self.duration(for: task, now: now))
                .dockPanelTextOutline()
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .layoutPriority(3)
        }

        private static func duration(for task: TaskExecution, now: Date) -> String {
            let seconds = max(0, Int(now.timeIntervalSince(task.startedAt)))
            let hours = seconds / 3_600
            let minutes = (seconds % 3_600) / 60
            let remainder = seconds % 60
            return hours > 0
                ? String(format: "%d:%02d:%02d", hours, minutes, remainder)
                : String(format: "%02d:%02d", minutes, remainder)
        }
    }

    private struct TaskMessageText: View {
        let task: TaskExecution

        var body: some View {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(task.latestUserMessage.isEmpty ? "—" : task.latestUserMessage)
                    .dockPanelTextOutline()
                    .foregroundStyle(.secondary)
                    .opacity(task.shouldDimMessage(at: context.date) ? 0.45 : 1)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @Bindable var model: UsageModel

    var body: some View {
        GeometryReader { proxy in
            let plan = TaskExecutionLayout.plan(for: model.tasks, panelWidth: proxy.size.width)
            let visibleTaskIDs = Set(
                plan.projects.flatMap { project in
                    project.sessions.flatMap { session in
                        session.tasks.map(\.id)
                    }
                }
            )
            VStack(alignment: .leading, spacing: 0) {
                if plan.projects.isEmpty {
                    Text("近10分钟没有活动任务")
                        .dockPanelTextOutline()
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(height: TaskExecutionLayout.emptyStateHeight, alignment: .center)
                } else {
                    ForEach(plan.projects) { project in
                        Text(project.name)
                            .dockPanelTextOutline()
                            .font(.system(size: 8, weight: .bold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(height: TaskExecutionLayout.projectRowHeight)
                        ForEach(project.sessions) { session in
                            Text("# \(session.name)")
                                .dockPanelTextOutline()
                                .font(.system(size: 8, weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(.leading, 8)
                                .frame(height: TaskExecutionLayout.sessionRowHeight)
                                .hidden()
                            ForEach(session.tasks) { task in
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    TaskStatusIndicator(
                                        isCompleted: task.isCompleted,
                                        isAnimationPaused: model.isTaskStatusAnimationPaused
                                    )
                                    TaskMessageText(task: task)
                                    Spacer(minLength: 2)
                                    TaskDurationText(task: task)
                                }
                                .font(.system(size: 9))
                                .padding(.leading, 8)
                                .frame(
                                    height: TaskExecutionLayout.taskRowHeight(for: task, panelWidth: proxy.size.width),
                                    alignment: .top
                                )
                                .transition(
                                    .asymmetric(
                                        insertion: .offset(y: 4).combined(with: .opacity),
                                        removal: .opacity
                                    )
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DockPanelContentLayout.horizontalInset)
            .padding(.bottom, DockPanelContentLayout.bottomInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .clipped()
            .animation(
                reduceMotion ? nil : .smooth(duration: 0.22),
                value: visibleTaskIDs
            )
        }
    }
}
