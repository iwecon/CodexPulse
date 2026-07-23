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
    private let languageSettings: AppLanguageSettings
    private let defaults: UserDefaults
    private var placementTimer: Timer?
    private var arrangement: PanelArrangement
    private var usageOverviewPreferredWidth: CGFloat
    private var taskActivityPreferredWidth: CGFloat
    private var resizeDrag: ResizeDrag?
    private let wallpaperAppearanceSampler = WallpaperAppearanceSampler()
    private var wallpaperAppearanceTask: Task<Void, Never>?
    private var wallpaperAppearanceGeneration = 0
    private var wallpaperRefreshTracker = WallpaperRefreshTracker()
    private var usageOverviewAppearance: PanelSemanticAppearance?
    private var taskActivityAppearance: PanelSemanticAppearance?
    private var effectiveAppearanceObservation: NSKeyValueObservation?
    private var observedSystemAppearance: PanelSemanticAppearance?
    private var appearanceChangeResampleTask: Task<Void, Never>?
    private var notificationObservers: [NSObjectProtocol] = []
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
            self?.arrangement.sideTogglePresentation(
                for: identity,
                language: self?.languageSettings.language ?? .simplifiedChineseMainland
            ) ?? PanelArrangement().sideTogglePresentation(for: identity)
        },
        verticalSwapPresentation: { [weak self] identity in
            guard let self else { return nil }
            return arrangement.verticalSwapPresentation(for: identity, language: languageSettings.language)
        },
        language: { [weak self] in
            self?.languageSettings.language ?? .simplifiedChineseMainland
        },
        onSelectLanguage: { [weak self] language in
            self?.selectLanguage(language)
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
        let languageSettings = AppLanguageSettings(defaults: defaults)
        self.languageSettings = languageSettings
        arrangement = preferences.arrangement
        usageOverviewPreferredWidth = preferences.usageOverviewPreferredWidth
        taskActivityPreferredWidth = preferences.taskActivityPreferredWidth
        let presentationState = DockPanelPresentationState()
        presentationState.usageSide = preferences.arrangement.usageSide
        presentationState.taskSide = preferences.arrangement.taskSide
        self.presentationState = presentationState
        leftPanel = Self.panel(
            rootView: AnyView(RecentUsageView(
                model: model,
                presentation: presentationState,
                languageSettings: languageSettings
            )),
            size: NSSize(width: preferences.usageOverviewPreferredWidth, height: 56)
        )
        rightPanel = Self.panel(
            rootView: AnyView(TaskExecutionView(
                model: model,
                presentation: presentationState,
                languageSettings: languageSettings
            )),
            size: NSSize(width: preferences.taskActivityPreferredWidth, height: taskPlan.panelHeight)
        )
        observedSystemAppearance = Self.currentSystemAppearance
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.positionPanels() }
        })
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.activeSpaceDidChangeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
            NSWorkspace.screensDidWakeNotification
        ] {
            notificationObservers.append(workspaceCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.positionPanels() }
            })
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

    private func positionPanels(forceWallpaperRefresh: Bool = false) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            removeWallpaperRefreshState()
            return
        }
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
        sessionLinkController.update(
            taskPanelFrame: rightPanel.frame,
            plan: taskPlan,
            language: languageSettings.language
        )
        resizeController.panelFramesDidChange(metrics: DockPanelOverlayMetrics(
            screenFrame: frame,
            dockFrame: dockFrame,
            dockEdge: edge
        ))
        updateWallpaperAppearances(on: screen, force: forceWallpaperRefresh)
    }

    private func updateWallpaperAppearances(on screen: NSScreen, force: Bool) {
        let workspace = NSWorkspace.shared
        guard let url = workspace.desktopImageURL(for: screen) else {
            removeWallpaperRefreshState()
            return
        }
        let options = workspace.desktopImageOptions(for: screen)
        let scalingRawValue = (options?[.imageScaling] as? NSNumber)?.uintValue
        let scaling = scalingRawValue.flatMap(NSImageScaling.init(rawValue:))
            ?? .scaleProportionallyUpOrDown
        let allowClipping = (options?[.allowClipping] as? NSNumber)?.boolValue ?? false
        let fillColor = Self.wallpaperRGB(from: options?[.fillColor] as? NSColor)
        let screenOrigin = screen.frame.origin
        let panelRegions = [
            WallpaperRefreshState.PanelRegion(
                identifier: 0,
                frame: leftPanel.frame.offsetBy(dx: -screenOrigin.x, dy: -screenOrigin.y)
            ),
            WallpaperRefreshState.PanelRegion(
                identifier: 1,
                frame: rightPanel.frame.offsetBy(dx: -screenOrigin.x, dy: -screenOrigin.y)
            )
        ]
        let resourceValues = try? url.resourceValues(forKeys: [
            .contentModificationDateKey,
            .fileSizeKey
        ])
        let refreshState = WallpaperRefreshState(
            signature: WallpaperStateSignature(
                image: .init(
                    url: url,
                    modificationDate: resourceValues?.contentModificationDate,
                    fileSize: resourceValues?.fileSize
                ),
                imageScalingRawValue: scaling.rawValue,
                allowClipping: allowClipping,
                fillColor: fillColor
            ),
            screenIdentifier: (screen.deviceDescription[.init("NSScreenNumber")] as? NSNumber)?.uint32Value,
            screenSize: screen.frame.size,
            panelRegions: panelRegions
        )
        let transition = wallpaperRefreshTracker.transition(to: refreshState)
        guard force || transition != .unchanged else { return }

        wallpaperAppearanceGeneration += 1
        let generation = wallpaperAppearanceGeneration
        wallpaperAppearanceTask?.cancel()

        let request = WallpaperAppearanceRequest(
            url: url,
            screenSize: screen.frame.size,
            scalingMode: .desktopImageMode(scaling: scaling, allowClipping: allowClipping),
            fillColor: fillColor,
            panelRegions: [
                WallpaperPanelRegion(
                    identifier: 0,
                    frame: panelRegions[0].frame,
                    previousAppearance: usageOverviewAppearance
                ),
                WallpaperPanelRegion(
                    identifier: 1,
                    frame: panelRegions[1].frame,
                    previousAppearance: taskActivityAppearance
                )
            ]
        )
        wallpaperAppearanceTask = Task { [weak self, wallpaperAppearanceSampler] in
            if case .resample(invalidateDecodedWallpaper: true) = transition {
                await wallpaperAppearanceSampler.invalidateCache()
            }
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

    private func removeWallpaperRefreshState() {
        guard wallpaperRefreshTracker.transition(to: nil) == .removed else { return }
        wallpaperAppearanceGeneration += 1
        wallpaperAppearanceTask?.cancel()
        wallpaperAppearanceTask = nil
        let fallbackAppearance = Self.currentSystemAppearance
        apply(fallbackAppearance, toPanelWithIdentifier: 0)
        apply(fallbackAppearance, toPanelWithIdentifier: 1)
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
            positionPanels(forceWallpaperRefresh: true)
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
        presentationState.taskSide = arrangement.taskSide
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

    private func selectLanguage(_ language: AppLanguage) {
        guard languageSettings.language != language else { return }
        languageSettings.language = language
        positionPanels()
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

private struct DockPanelTextShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, .dark)
            .shadow(color: Color.black.opacity(0.62), radius: 0.45)
    }
}

private extension Text {
    func dockPanelTextShadow() -> some View {
        modifier(DockPanelTextShadow())
    }
}

struct RecentUsageView: View {
    @Bindable var model: UsageModel
    let presentation: DockPanelPresentationState
    @Bindable var languageSettings: AppLanguageSettings
    private var days: [DailyUsage] { model.snapshot.dailyUsage }
    private var maximum: Int { max(days.map(\.total).max() ?? 0, 1) }
    private var total: Int { days.reduce(0) { $0 + $1.total } }

    var body: some View {
        HStack(spacing: 6) {
            if presentation.usageSide == .left {
                trendView
                Divider().frame(height: 34)
                WeeklyLimitView(model: model, alignTrailing: false, languageSettings: languageSettings)
            } else {
                WeeklyLimitView(model: model, alignTrailing: true, languageSettings: languageSettings)
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
                Text(languageSettings.language.recentFourteenDays)
                    .dockPanelTextShadow()
                    .font(.system(size: 10, weight: .semibold))
                Spacer(minLength: 2)
                Text(UsageModel.compact(total))
                    .dockPanelTextShadow()
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(day.total == 0 ? Color.secondary.opacity(0.16) : Color.accentColor.opacity(0.38 + 0.62 * Double(day.total) / Double(maximum)))
                        .frame(maxWidth: .infinity)
                        .frame(height: 3 + 18 * CGFloat(day.total) / CGFloat(maximum))
                        .accessibilityLabel(languageSettings.language.accessibilityDate(day.date))
                        .accessibilityValue(languageSettings.language.tokenCount(day.total))
                }
            }
            .frame(height: 21, alignment: .bottom)
            HStack {
                Text(days.first.map { languageSettings.language.shortDate($0.date) } ?? "—")
                    .dockPanelTextShadow()
                Spacer()
                HStack(spacing: 3) {
                    Text(days.last.map { languageSettings.language.shortDate($0.date) } ?? "—")
                        .dockPanelTextShadow()
                    Text(UsageModel.compact(days.last?.total ?? 0))
                        .dockPanelTextShadow()
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
        let language: AppLanguage

        var body: some View {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let value = WeeklyLimitPacing.averageDailyAvailablePercent(
                    usedPercent: used,
                    resetsAt: resetsAt,
                    now: context.date
                )
                Text(language.averageDailyAvailable(value))
                    .dockPanelTextShadow()
                    .monospacedDigit()
                    .lineLimit(1)
                    .layoutPriority(1)
            }
        }
    }

    private struct CountdownText: View {
        let reset: Date
        let language: AppLanguage

        var body: some View {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(WeeklyLimitCountdown.format(reset: reset, now: context.date, language: language))
                    .dockPanelTextShadow()
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
    }

    @Bindable var model: UsageModel
    let alignTrailing: Bool
    @Bindable var languageSettings: AppLanguageSettings

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
                    Text(languageSettings.language.weeklyLimit)
                        .dockPanelTextShadow()
                        .fontWeight(.semibold)
                    Spacer(minLength: 2)
                    Text(languageSettings.language.usedPercent(Int(used.rounded())))
                        .dockPanelTextShadow()
                    Text(languageSettings.language.remainingPercent(Int((100 - used).rounded())))
                        .dockPanelTextShadow()
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
                    Text(languageSettings.language.resetText(weekly.resetsAt))
                        .dockPanelTextShadow()
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    AverageDailyAvailableText(
                        used: used,
                        resetsAt: weekly.resetsAt,
                        language: languageSettings.language
                    )
                }
                CountdownText(reset: weekly.resetsAt, language: languageSettings.language)
            }
            .font(.system(size: 8))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
        } else {
            VStack(alignment: alignTrailing ? .trailing : .leading, spacing: 2) {
                Text(languageSettings.language.weeklyQuota)
                    .dockPanelTextShadow()
                    .fontWeight(.semibold)
                Text(languageSettings.language.noData)
                    .dockPanelTextShadow()
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 9))
            .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
        }
    }
}

enum WeeklyLimitCountdown {
    static func format(
        reset: Date,
        now: Date,
        language: AppLanguage = .simplifiedChineseMainland
    ) -> String {
        let totalSeconds = max(0, Int(reset.timeIntervalSince(now)))
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        return language.countdown(days: days, hours: hours, minutes: minutes)
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
    @Bindable var model: UsageModel
    let presentation: DockPanelPresentationState
    @Bindable var languageSettings: AppLanguageSettings

    private struct TaskStatusIndicator: View {
        let isCompleted: Bool
        let isAnimationPaused: Bool
        let language: AppLanguage
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
            .accessibilityLabel(isCompleted ? language.completedTask : language.runningTask)
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
                .dockPanelTextShadow()
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
                    .dockPanelTextShadow()
                    .foregroundStyle(.secondary)
                    .opacity(task.shouldDimMessage(at: context.date) ? 0.45 : 1)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

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
                    Text(languageSettings.language.noRecentTasks)
                        .dockPanelTextShadow()
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: TaskExecutionLayout.emptyStateHeight,
                            maxHeight: TaskExecutionLayout.emptyStateHeight,
                            alignment: presentation.taskSide == .left ? .leading : .trailing
                        )
                } else {
                    ForEach(plan.projects) { project in
                        Text(project.name)
                            .dockPanelTextShadow()
                            .font(.system(size: 8, weight: .bold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(height: TaskExecutionLayout.projectRowHeight)
                        ForEach(project.sessions) { session in
                            Text("# \(session.name)")
                                .dockPanelTextShadow()
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
                                        isAnimationPaused: model.isTaskStatusAnimationPaused,
                                        language: languageSettings.language
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
