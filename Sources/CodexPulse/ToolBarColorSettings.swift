import AppKit
import Observation
import SwiftUI

extension WallpaperRGB {
    /// Parses a `#RRGGBB` string (leading `#` optional). Anything else — wrong
    /// length, non-hex digits — is rejected so corrupted defaults fall back to
    /// the built-in colors.
    init?(hexString: String) {
        var text = hexString.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6,
              text.allSatisfy(\.isHexDigit),
              let value = UInt32(text, radix: 16) else {
            return nil
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// `#RRGGBB` with each component clamped to `0...1` before rounding.
    var hexString: String {
        func component(_ value: Double) -> UInt32 {
            UInt32((min(max(value, 0), 1) * 255).rounded())
        }
        return String(format: "#%02X%02X%02X", component(red), component(green), component(blue))
    }
}

/// User-chosen Usage Overview Panel bar colors, one optional override per
/// tool. An override is a fixed color used in both panel appearances — like a
/// brand color — while tools without one keep the polarity-adaptive rendering.
struct ToolBarColorPreference: Equatable {
    static func defaultsKey(for tool: Tool) -> String {
        "usageBars.customColor.\(tool.settingsKey)"
    }

    var customColors: [Tool: WallpaperRGB]

    init(customColors: [Tool: WallpaperRGB] = [:]) {
        self.customColors = customColors
    }

    init(defaults: UserDefaults) {
        customColors = Tool.allCases.reduce(into: [:]) { colors, tool in
            guard let hex = defaults.string(forKey: Self.defaultsKey(for: tool)),
                  let rgb = WallpaperRGB(hexString: hex) else { return }
            colors[tool] = rgb
        }
    }

    func save(to defaults: UserDefaults) {
        for tool in Tool.allCases {
            let key = Self.defaultsKey(for: tool)
            if let rgb = customColors[tool] {
                defaults.set(rgb.hexString, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    /// The bar color actually rendered: the user's override when present,
    /// otherwise the built-in brand or polarity-adaptive color.
    func barColor(for tool: Tool, appearance: PanelSemanticAppearance) -> WallpaperRGB {
        customColors[tool] ?? AdaptiveTextColor.barColor(for: tool, appearance: appearance)
    }
}

@MainActor @Observable
final class ToolBarColorSettings {
    private let defaults: UserDefaults
    private(set) var preference: ToolBarColorPreference {
        didSet {
            guard oldValue != preference else { return }
            preference.save(to: defaults)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preference = ToolBarColorPreference(defaults: defaults)
    }

    var hasCustomColors: Bool { !preference.customColors.isEmpty }

    func customColor(for tool: Tool) -> WallpaperRGB? {
        preference.customColors[tool]
    }

    func setCustomColor(_ color: WallpaperRGB, for tool: Tool) {
        preference.customColors[tool] = color
    }

    func resetColor(for tool: Tool) {
        preference.customColors[tool] = nil
    }

    func resetAllColors() {
        preference.customColors = [:]
    }

    func barColor(for tool: Tool, appearance: PanelSemanticAppearance) -> WallpaperRGB {
        preference.barColor(for: tool, appearance: appearance)
    }
}

/// One color row per tool plus per-row and reset-all defaults. The pickers
/// preview the currently rendered color, so a tool without an override shows
/// its adaptive color for the Usage Overview Panel's present appearance.
struct BarColorSettingsView: View {
    let settings: ToolBarColorSettings
    let presentation: DockPanelPresentationState
    @Bindable var languageSettings: AppLanguageSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(languageSettings.language.barColorSettingsExplanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Tool.allCases) { tool in
                HStack(spacing: 8) {
                    ColorPicker(selection: colorBinding(for: tool), supportsOpacity: false) {
                        Text(tool.rawValue)
                    }
                    .accessibilityLabel(tool.rawValue)
                    Spacer(minLength: 12)
                    Button(languageSettings.language.resetColor) {
                        settings.resetColor(for: tool)
                    }
                    .disabled(settings.customColor(for: tool) == nil)
                }
            }
            Divider()
            HStack {
                Spacer()
                Button(languageSettings.language.resetAllColors) {
                    settings.resetAllColors()
                }
                .disabled(!settings.hasCustomColors)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func colorBinding(for tool: Tool) -> Binding<Color> {
        Binding(
            get: {
                Color(settings.barColor(for: tool, appearance: presentation.usageAppearance))
            },
            set: { newValue in
                guard let rgb = NSColor(newValue).usingColorSpace(.sRGB) else { return }
                settings.setCustomColor(
                    WallpaperRGB(
                        red: Double(rgb.redComponent),
                        green: Double(rgb.greenComponent),
                        blue: Double(rgb.blueComponent)
                    ),
                    for: tool
                )
            }
        )
    }
}

/// Default placement of the bar color settings window: anchored to the Usage
/// Overview Panel so the window opens next to the bars it recolors.
enum BarColorSettingsPlacement {
    /// Frame that sits just above the usage panel with the same screen-side
    /// alignment — leading edges match when the panel lives in the left half
    /// of the screen, trailing edges when it lives in the right half — then
    /// clamped into the visible frame.
    static func anchoredFrame(
        panelSize: CGSize,
        usagePanelFrame: CGRect,
        visibleFrame: CGRect,
        gap: CGFloat = 10
    ) -> CGRect {
        let alignsTrailing = usagePanelFrame.midX > visibleFrame.midX
        let x = alignsTrailing ? usagePanelFrame.maxX - panelSize.width : usagePanelFrame.minX
        let y = usagePanelFrame.maxY + gap
        return CGRect(
            x: min(max(x, visibleFrame.minX), max(visibleFrame.minX, visibleFrame.maxX - panelSize.width)),
            y: min(max(y, visibleFrame.minY), max(visibleFrame.minY, visibleFrame.maxY - panelSize.height)),
            width: panelSize.width,
            height: panelSize.height
        )
    }
}

/// Floating utility window hosting `BarColorSettingsView`, opened from the
/// Usage Overview Panel's control group. Unlike the click-through content
/// panels it activates the app and becomes key so color wells can drive the
/// shared `NSColorPanel`.
@MainActor
final class BarColorSettingsWindowController: NSObject, NSWindowDelegate {
    private let settings: ToolBarColorSettings
    private let presentation: DockPanelPresentationState
    private let languageSettings: AppLanguageSettings
    private let usagePanelFrame: () -> CGRect?
    private var panel: NSPanel?

    init(
        settings: ToolBarColorSettings,
        presentation: DockPanelPresentationState,
        languageSettings: AppLanguageSettings,
        usagePanelFrame: @escaping () -> CGRect? = { nil }
    ) {
        self.settings = settings
        self.presentation = presentation
        self.languageSettings = languageSettings
        self.usagePanelFrame = usagePanelFrame
    }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.title = languageSettings.language.barColorSettingsTitle
        if !panel.isVisible { position(panel) }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func position(_ panel: NSPanel) {
        guard let usageFrame = usagePanelFrame(),
              let screen = NSScreen.screens.first(where: { $0.frame.intersects(usageFrame) })
                  ?? NSScreen.main else {
            panel.center()
            return
        }
        panel.setFrame(
            BarColorSettingsPlacement.anchoredFrame(
                panelSize: panel.frame.size,
                usagePanelFrame: usageFrame,
                visibleFrame: screen.visibleFrame
            ),
            display: false
        )
    }

    private func makePanel() -> NSPanel {
        let hostingView = NSHostingView(rootView: BarColorSettingsView(
            settings: settings,
            presentation: presentation,
            languageSettings: languageSettings
        ))
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.setContentSize(hostingView.fittingSize)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        return panel
    }

    func windowWillClose(_ notification: Notification) {
        guard NSColorPanel.sharedColorPanelExists else { return }
        NSColorPanel.shared.orderOut(nil)
    }
}
