import AppKit
import Testing
@testable import CodexPulse

@Test func quartzDockFrameConvertsToAppKitCoordinates() {
    let quartzFrame = CGRect(x: 500, y: 930, width: 500, height: 66)

    let appKitFrame = DockPanelPlacementGeometry.appKitRect(
        fromQuartz: quartzFrame,
        mainScreenMaxY: 1_000
    )

    #expect(appKitFrame == CGRect(x: 500, y: 4, width: 500, height: 66))
}

@Test func dockPanelBottomEdgeUsesDockAndRetainsFallback() {
    let screenFrame = CGRect(x: 0, y: 0, width: 1_500, height: 1_000)
    let dockFrame = CGRect(x: 500, y: 4, width: 500, height: 66)

    #expect(DockPanelPlacementGeometry.bottomEdge(
        dockFrame: dockFrame,
        screenFrame: screenFrame,
        fallbackInset: 2
    ) == 4)
    #expect(DockPanelPlacementGeometry.bottomEdge(
        dockFrame: nil,
        screenFrame: screenFrame,
        fallbackInset: 2
    ) == 2)
}

@Test func dockPanelPreferredWidthHonorsDirectionAndMinimum() {
    #expect(DockPanelWidthGeometry.preferredWidth(
        startingWidth: 350,
        horizontalDrag: 40,
        anchor: .fixedLeft
    ) == 390)
    #expect(DockPanelWidthGeometry.preferredWidth(
        startingWidth: 350,
        horizontalDrag: -40,
        anchor: .fixedRight
    ) == 390)
    #expect(DockPanelWidthGeometry.preferredWidth(
        startingWidth: 200,
        horizontalDrag: -100,
        anchor: .fixedLeft
    ) == DockPanelWidthGeometry.minimumPreferredWidth)
}

@Test func dockPanelPreferencesRoundTripPositionAndWidths() throws {
    let suiteName = "CodexPulseTests.DockPanelPreferences.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let expected = DockPanelPreferences(
        arrangement: PanelArrangement(
            usageSide: .right,
            taskSide: .right,
            verticalOrder: .taskAboveUsage
        ),
        usageOverviewPreferredWidth: 412,
        taskActivityPreferredWidth: 528
    )

    expected.save(to: defaults)

    #expect(DockPanelPreferences(defaults: defaults) == expected)
}

@Test func dockPanelPreferencesIgnoreInvalidPersistedValues() throws {
    let suiteName = "CodexPulseTests.DockPanelPreferences.Invalid.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("middle", forKey: "dockPanels.usageOverview.side")
    defaults.set("sideways", forKey: "dockPanels.verticalOrder")
    defaults.set(100, forKey: "dockPanels.usageOverview.preferredWidth")
    defaults.set(Double.infinity, forKey: "dockPanels.taskActivity.preferredWidth")

    let preferences = DockPanelPreferences(defaults: defaults)

    #expect(preferences.arrangement == PanelArrangement())
    #expect(preferences.usageOverviewPreferredWidth == DockPanelWidthGeometry.defaultWidth)
    #expect(preferences.taskActivityPreferredWidth == DockPanelWidthGeometry.defaultWidth)
}

@Test func dockPanelActualWidthRecoversPreferredWidthWhenSpaceReturns() {
    #expect(DockPanelWidthGeometry.actualWidth(preferredWidth: 420, availableWidth: 260) == 260)
    #expect(DockPanelWidthGeometry.actualWidth(preferredWidth: 420, availableWidth: 600) == 420)
    #expect(DockPanelWidthGeometry.actualWidth(preferredWidth: 420, availableWidth: 120) == 120)
}

@Test func dockPanelFramesKeepTheirPhysicalResizeEdgesFixed() {
    let usageFrame = DockPanelWidthGeometry.frame(
        preferredWidth: 420,
        availableWidth: 600,
        fixedEdge: 12,
        anchor: .fixedLeft,
        y: 2,
        height: 56
    )
    let taskFrame = DockPanelWidthGeometry.frame(
        preferredWidth: 420,
        availableWidth: 600,
        fixedEdge: 990,
        anchor: .fixedRight,
        y: 2,
        height: 120
    )

    #expect(usageFrame.minX == 12)
    #expect(usageFrame.maxX == 432)
    #expect(taskFrame.minX == 570)
    #expect(taskFrame.maxX == 990)
}

@Test func panelSideToggleRoundTripsAndVerticalResetAreExhaustive() {
    for usageSide in PanelSide.allCases {
        for taskSide in PanelSide.allCases {
            for order in PanelVerticalOrder.allCases {
                for panel in DockPanelIdentity.allCases {
                    var arrangement = PanelArrangement(
                        usageSide: usageSide,
                        taskSide: taskSide,
                        verticalOrder: order
                    )
                    arrangement.toggleSide(for: panel)

                    #expect(arrangement.side(for: panel) != (panel == .usageOverview ? usageSide : taskSide))
                    #expect(arrangement.verticalOrder == (arrangement.isColocated ? .usageAboveTask : order))

                    arrangement.toggleSide(for: panel)
                    #expect(arrangement.usageSide == usageSide)
                    #expect(arrangement.taskSide == taskSide)
                }
            }
        }
    }
}

@Test func horizontalSideToggleAndVerticalSwapRemainIndependent() {
    var arrangement = PanelArrangement()
    #expect(arrangement.sideTogglePresentation(for: .usageOverview).systemImageName == "arrow.right")
    #expect(arrangement.sideTogglePresentation(for: .taskActivity).systemImageName == "arrow.left")
    #expect(arrangement.verticalSwapPresentation(for: .usageOverview) == nil)

    arrangement.toggleSide(for: .usageOverview)
    #expect(arrangement == PanelArrangement(usageSide: .right, taskSide: .right, verticalOrder: .usageAboveTask))
    #expect(arrangement.sideTogglePresentation(for: .usageOverview).systemImageName == "arrow.left")
    #expect(arrangement.verticalSwapPresentation(for: .usageOverview)?.systemImageName == "arrow.up.arrow.down")

    arrangement.toggleVerticalOrder()
    #expect(arrangement.verticalOrder == .taskAboveUsage)
    #expect(arrangement.usageSide == .right)
    #expect(arrangement.taskSide == .right)

    arrangement.toggleSide(for: .usageOverview)
    #expect(arrangement.usageSide == .left)
    #expect(arrangement.taskSide == .right)
    #expect(arrangement.verticalOrder == .taskAboveUsage)
    #expect(arrangement.sideTogglePresentation(for: .usageOverview).systemImageName == "arrow.right")
    #expect(arrangement.verticalSwapPresentation(for: .usageOverview) == nil)

    arrangement.toggleVerticalOrder()
    #expect(arrangement.verticalOrder == .taskAboveUsage)
}

@Test func interactionGeometryMirrorsAroundResizeEdgeAndUsesDockHeight() {
    let screen = CGRect(x: -500, y: 0, width: 2_000, height: 1_000)
    let parent = CGRect(x: 2, y: 4, width: 420, height: 56)
    let metrics = DockPanelOverlayMetrics(
        screenFrame: screen,
        dockFrame: CGRect(x: 500, y: 4, width: 500, height: 90),
        dockEdge: .bottom
    )

    let left = DockPanelOverlayGeometry.expandedFrame(
        parentFrame: parent,
        side: .left,
        metrics: metrics
    )
    let right = DockPanelOverlayGeometry.expandedFrame(
        parentFrame: parent,
        side: .right,
        metrics: metrics
    )
    #expect(left.maxX - DockPanelOverlayGeometry.controlPadding == parent.maxX)
    #expect(right.minX + DockPanelOverlayGeometry.controlPadding == parent.minX)
    #expect(left.minY == parent.minY)
    #expect(left.height == 102)
    #expect(left.width == right.width)
    #expect(left.width == parent.width + DockPanelOverlayGeometry.controlPadding)
    #expect(left.minX == parent.minX)
    #expect(right.maxX == parent.maxX)
    #expect(screen.contains(CGPoint(x: left.midX, y: left.maxY)))

    let leftResize = DockPanelOverlayGeometry.resizeRegionFrame(
        in: CGRect(origin: .zero, size: left.size),
        side: .left
    )
    let rightResize = DockPanelOverlayGeometry.resizeRegionFrame(
        in: CGRect(origin: .zero, size: right.size),
        side: .right
    )
    #expect(leftResize.maxX == left.width)
    #expect(rightResize.minX == 0)
    #expect(leftResize.width == DockPanelOverlayGeometry.resizeHitWidth)
    #expect(rightResize.width == DockPanelOverlayGeometry.resizeHitWidth)
    #expect(left.minX + leftResize.maxX - DockPanelOverlayGeometry.controlPadding == parent.maxX)
    #expect(right.minX + rightResize.minX + DockPanelOverlayGeometry.controlPadding == parent.minX)
}

@Test func pointerDwellRequiresHalfSecondWithoutMovement() {
    let start = Date(timeIntervalSince1970: 1_780_000_000)
    var dwell = DockPanelPointerDwell()

    #expect(dwell.update(
        candidate: .usageOverview,
        location: CGPoint(x: 10, y: 10),
        now: start,
        delay: 0.5
    ) == nil)
    #expect(dwell.update(
        candidate: .usageOverview,
        location: CGPoint(x: 11, y: 10),
        now: start.addingTimeInterval(0.4),
        delay: 0.5
    ) == nil)
    #expect(dwell.update(
        candidate: .usageOverview,
        location: CGPoint(x: 11, y: 10),
        now: start.addingTimeInterval(0.8),
        delay: 0.5
    ) == nil)
    #expect(dwell.update(
        candidate: .usageOverview,
        location: CGPoint(x: 11, y: 10),
        now: start.addingTimeInterval(0.9),
        delay: 0.5
    ) == .usageOverview)
    #expect(DockPanelResizeController.hoverDelay == 0.5)
    #expect(DockPanelResizeController.hideDelay == 1)
}

@Test func dockPanelsStayBelowApplicationWindowsWithControlsAboveContent() {
    #expect(DockPanelWindowLevel.content.rawValue < DockPanelWindowLevel.sessionLink.rawValue)
    #expect(DockPanelWindowLevel.interaction.rawValue > DockPanelWindowLevel.sessionLink.rawValue)
    #expect(DockPanelWindowLevel.interaction.rawValue < NSWindow.Level.normal.rawValue)
}

@Test func interactionGeometryClampsVerticallyAndResizeOnlyStaysAnchored() {
    let screen = CGRect(x: -200, y: 40, width: 300, height: 100)
    let parent = CGRect(x: -180, y: 100, width: 180, height: 56)
    let metrics = DockPanelOverlayMetrics(screenFrame: screen, dockFrame: nil, dockEdge: .unknown)
    let expanded = DockPanelOverlayGeometry.expandedFrame(
        parentFrame: parent,
        side: .left,
        metrics: metrics
    )
    let resizeOnly = DockPanelOverlayGeometry.resizeOnlyFrame(
        parentFrame: parent,
        side: .left,
        metrics: metrics
    )
    let rightResizeOnly = DockPanelOverlayGeometry.resizeOnlyFrame(
        parentFrame: parent,
        side: .right,
        metrics: metrics
    )

    #expect(expanded.minY == screen.maxY - DockPanelOverlayGeometry.minimumResizeHeight)
    #expect(expanded.maxY == screen.maxY)
    #expect(resizeOnly.minY == expanded.minY)
    #expect(resizeOnly.height == expanded.height)
    #expect(resizeOnly.width == DockPanelOverlayGeometry.resizeHitWidth)
    #expect(resizeOnly.maxX - DockPanelOverlayGeometry.controlPadding == parent.maxX)
    #expect(rightResizeOnly.minX + DockPanelOverlayGeometry.controlPadding == parent.minX)
}

@Test func interactionActionsFillPaddedAreaAndMirrorForBothCounts() {
    for side in PanelSide.allCases {
        for count in 1...2 {
            let bounds = CGRect(
                x: 0,
                y: 0,
                width: 430,
                height: 100
            )
            let resize = DockPanelOverlayGeometry.resizeRegionFrame(in: bounds, side: side)
            let actions = DockPanelOverlayGeometry.actionSurfaceFrames(
                in: bounds,
                side: side,
                actionCount: count
            )

            #expect(actions.count == count)
            #expect(actions.allSatisfy { $0.height == bounds.height - 2 * DockPanelOverlayGeometry.controlPadding })
            #expect(actions.allSatisfy { $0.minY == DockPanelOverlayGeometry.controlPadding })
            #expect(actions.allSatisfy { !$0.intersects(resize) })
            let actionRegionMinX = side == .left ? bounds.minX : resize.maxX
            let actionRegionMaxX = side == .left ? resize.minX : bounds.maxX
            #expect(actions.first?.minX == actionRegionMinX + (side == .left ? DockPanelOverlayGeometry.controlPadding : 0))
            #expect(actions.last?.maxX == actionRegionMaxX - (side == .right ? DockPanelOverlayGeometry.controlPadding : 0))
            #expect(DockPanelOverlayGeometry.actionSurfacesContain(
                CGPoint(x: actions[0].midX, y: actions[0].midY),
                in: bounds,
                side: side,
                actionCount: count
            ))
            #expect(!DockPanelOverlayGeometry.actionSurfacesContain(
                CGPoint(x: resize.midX, y: resize.midY),
                in: bounds,
                side: side,
                actionCount: count
            ))
            if count == 2 {
                #expect(actions[1].minX - actions[0].maxX == DockPanelOverlayGeometry.controlGap)
                #expect(actions[0].width == actions[1].width)
                #expect(!DockPanelOverlayGeometry.actionSurfacesContain(
                    CGPoint(x: actions[0].maxX + DockPanelOverlayGeometry.controlGap / 2, y: actions[0].midY),
                    in: bounds,
                    side: side,
                    actionCount: count
                ))
            }
        }
    }

    #expect(DockPanelOverlayGeometry.outerCornerRadius == 16)
    #expect(DockPanelOverlayGeometry.actionCornerRadius == 10)
    #expect(DockPanelOverlayGeometry.controlPadding == 6)
    #expect(DockPanelOverlayGeometry.resizeWidth == 34)
    #expect(DockPanelOverlayGeometry.resizeHitWidth == 46)
}

@Test func resizeFocusPresentationFadesActionsAndContractsBackgroundByItsPadding() {
    let bounds = CGRect(x: 0, y: 0, width: 430, height: 100)
    let normal = DockPanelInteractionPresentation.resolve(
        in: bounds,
        resizeFocused: false
    )
    let focused = DockPanelInteractionPresentation.resolve(
        in: bounds,
        resizeFocused: true
    )

    #expect(normal.backgroundFrame == bounds)
    #expect(normal.backgroundCornerRadius == 16)
    #expect(normal.backgroundAlpha == 1)
    #expect(normal.actionsAlpha == 1)
    #expect(normal.actionsScale == 1)
    #expect(focused.backgroundFrame == bounds.insetBy(dx: 6, dy: 6))
    #expect(focused.backgroundCornerRadius == 10)
    #expect(focused.backgroundAlpha == 0)
    #expect(focused.actionsAlpha == 0)
    #expect(focused.actionsScale == 0.98)

    #expect(DockPanelOverlayGeometry.resizeFocusAnimationDuration == 0.34)
}

@Test func expandedInteractionGeometryClampsToScreenHorizontally() {
    let screen = CGRect(x: 0, y: 0, width: 500, height: 300)
    let metrics = DockPanelOverlayMetrics(screenFrame: screen, dockFrame: nil, dockEdge: .bottom)
    let leftParent = CGRect(x: 100, y: 0, width: 398, height: 56)
    let rightParent = CGRect(x: 2, y: 0, width: 398, height: 56)

    let left = DockPanelOverlayGeometry.expandedFrame(
        parentFrame: leftParent,
        side: .left,
        metrics: metrics
    )
    let right = DockPanelOverlayGeometry.expandedFrame(
        parentFrame: rightParent,
        side: .right,
        metrics: metrics
    )

    #expect(left.minX == leftParent.minX)
    #expect(left.maxX == screen.maxX)
    #expect(right.minX == screen.minX)
    #expect(right.maxX == rightParent.maxX)
}

@Test func panelPlacementSupportsEveryDockEdgeArrangementAndStackOrder() throws {
    let screen = CGRect(x: -200, y: 40, width: 1_400, height: 900)
    let sizes = DockPanelPlacementGeometry.PanelSizes(
        usagePreferredWidth: 390,
        taskPreferredWidth: 430,
        usageHeight: 56,
        taskHeight: 120
    )

    for dockEdge in [DockEdge.bottom, .left, .right, .unknown] {
        let visible: CGRect
        let dockFrame: CGRect?
        switch dockEdge {
        case .bottom:
            visible = CGRect(x: -200, y: 100, width: 1_400, height: 840)
            dockFrame = CGRect(x: 300, y: 42, width: 500, height: 58)
        case .left:
            visible = CGRect(x: -140, y: 40, width: 1_340, height: 900)
            dockFrame = nil
        case .right:
            visible = CGRect(x: -200, y: 40, width: 1_340, height: 900)
            dockFrame = nil
        case .unknown:
            visible = screen
            dockFrame = nil
        }

        for usageSide in PanelSide.allCases {
            for taskSide in PanelSide.allCases {
                for order in PanelVerticalOrder.allCases {
                    let arrangement = PanelArrangement(
                        usageSide: usageSide,
                        taskSide: taskSide,
                        verticalOrder: order
                    )
                    let frames = DockPanelPlacementGeometry.frames(
                        screenFrame: screen,
                        visibleFrame: visible,
                        dockFrame: dockFrame,
                        dockEdge: dockEdge,
                        arrangement: arrangement,
                        sizes: sizes,
                        inset: 2,
                        gap: 10
                    )
                    let usage = try #require(frames[.usageOverview])
                    let task = try #require(frames[.taskActivity])

                    #expect(screen.insetBy(dx: 2, dy: 2).contains(usage))
                    #expect(screen.insetBy(dx: 2, dy: 2).contains(task))
                    #expect(!usage.intersects(task))
                    let horizontalRange: ClosedRange<CGFloat> = switch dockEdge {
                    case .bottom, .unknown:
                        arrangement.side(for: .usageOverview) == .left
                            ? (screen.minX + 2)...(dockFrame?.minX ?? screen.midX)
                            : (dockFrame?.maxX ?? screen.midX)...(screen.maxX - 2)
                    case .left:
                        (visible.minX + 10)...(screen.maxX - 2)
                    case .right:
                        (screen.minX + 2)...(visible.maxX - 10)
                    }
                    if arrangement.side(for: .usageOverview) == .left {
                        #expect(usage.minX == horizontalRange.lowerBound)
                    } else {
                        #expect(usage.maxX == horizontalRange.upperBound)
                    }
                    if arrangement.isColocated {
                        if order == .usageAboveTask {
                            #expect(usage.minY >= task.maxY + 10)
                        } else {
                            #expect(task.minY >= usage.maxY + 10)
                        }
                    }
                }
            }
        }
    }
}

@Test func bottomDockSlotsDoNotOverlapDock() throws {
    let screen = CGRect(x: 0, y: 0, width: 1_500, height: 1_000)
    let dock = CGRect(x: 500, y: 4, width: 500, height: 66)
    let frames = DockPanelPlacementGeometry.frames(
        screenFrame: screen,
        visibleFrame: CGRect(x: 0, y: 70, width: 1_500, height: 930),
        dockFrame: dock,
        dockEdge: .bottom,
        arrangement: PanelArrangement(),
        sizes: .init(usagePreferredWidth: 420, taskPreferredWidth: 420, usageHeight: 56, taskHeight: 120),
        inset: 2,
        gap: 10
    )

    let usage = try #require(frames[.usageOverview])
    let task = try #require(frames[.taskActivity])
    #expect(usage.maxX <= dock.minX - 10)
    #expect(task.minX >= dock.maxX + 10)
    #expect(usage.minX == screen.minX + 2)
    #expect(task.maxX == screen.maxX - 2)
}

@Test func verticalDockPlacementKeepsPanelsBesideDockWithSideBasedResizeEdges() throws {
    let screen = CGRect(x: -200, y: 40, width: 1_400, height: 900)
    let sizes = DockPanelPlacementGeometry.PanelSizes(
        usagePreferredWidth: 300,
        taskPreferredWidth: 300,
        usageHeight: 56,
        taskHeight: 120
    )
    let leftVisible = CGRect(x: -140, y: 40, width: 1_340, height: 900)
    let leftFrames = DockPanelPlacementGeometry.frames(
        screenFrame: screen,
        visibleFrame: leftVisible,
        dockFrame: nil,
        dockEdge: .left,
        arrangement: PanelArrangement(),
        sizes: sizes,
        inset: 2,
        gap: 10
    )
    #expect(try #require(leftFrames[.usageOverview]).minX == leftVisible.minX + 10)
    #expect(try #require(leftFrames[.taskActivity]).maxX == screen.maxX - 2)

    let rightVisible = CGRect(x: -200, y: 40, width: 1_340, height: 900)
    let rightFrames = DockPanelPlacementGeometry.frames(
        screenFrame: screen,
        visibleFrame: rightVisible,
        dockFrame: nil,
        dockEdge: .right,
        arrangement: PanelArrangement(),
        sizes: sizes,
        inset: 2,
        gap: 10
    )
    #expect(try #require(rightFrames[.usageOverview]).minX == screen.minX + 2)
    #expect(try #require(rightFrames[.taskActivity]).maxX == rightVisible.maxX - 10)
}
