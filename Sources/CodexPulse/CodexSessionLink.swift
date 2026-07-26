import AppKit

enum CodexThreadLink {
    static func url(threadID: String) -> URL? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard !threadID.isEmpty,
              let encodedThreadID = threadID.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "codex"
        components.host = "threads"
        components.percentEncodedPath = "/\(encodedThreadID)"
        return components.url
    }
}

@MainActor
final class CodexSessionLinkController {
    private var panels: [String: NSPanel] = [:]
    private var semanticAppearance: PanelSemanticAppearance = .dark

    func setAppearance(_ semanticAppearance: PanelSemanticAppearance) {
        self.semanticAppearance = semanticAppearance
        let appearance = NSAppearance(
            named: semanticAppearance == .dark ? .darkAqua : .aqua
        )
        for panel in panels.values {
            panel.appearance = appearance
            (panel.contentView as? CodexSessionLinkView)?.setAppearance(semanticAppearance)
            panel.displayIfNeeded()
        }
    }

    func update(
        taskPanelFrame: CGRect,
        plan: TaskExecutionLayout.Plan,
        language: AppLanguage,
        textAlignment: TaskActivityTextAlignment
    ) {
        let links = TaskExecutionLayout.sessionLinks(
            for: plan,
            panelWidth: taskPanelFrame.width,
            textAlignment: textAlignment
        )
        let activeIDs = Set(links.map(\.id))

        let staleIDs = panels.keys.filter { !activeIDs.contains($0) }
        for id in staleIDs {
            panels.removeValue(forKey: id)?.orderOut(nil)
        }

        for link in links {
            let panel = panels[link.id] ?? makePanel(
                threadID: link.threadID,
                title: link.title,
                language: language,
                textAlignment: textAlignment
            )
            panels[link.id] = panel
            (panel.contentView as? CodexSessionLinkView)?.update(
                title: link.title,
                language: language,
                textAlignment: textAlignment
            )
            panel.setFrame(link.frame.offsetBy(dx: taskPanelFrame.minX, dy: taskPanelFrame.minY), display: true)
            panel.orderFrontRegardless()
        }
    }

    private func makePanel(
        threadID: String,
        title: String,
        language: AppLanguage,
        textAlignment: TaskActivityTextAlignment
    ) -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = CodexSessionLinkView(
            threadID: threadID,
            title: title,
            language: language,
            textAlignment: textAlignment,
            semanticAppearance: semanticAppearance
        )
        panel.appearance = NSAppearance(
            named: semanticAppearance == .dark ? .darkAqua : .aqua
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.level = DockPanelWindowLevel.sessionLink
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        return panel
    }
}

final class CodexSessionLinkView: NSView {
    private let threadID: String
    private var title: String
    private var language: AppLanguage
    private var textAlignment: TaskActivityTextAlignment
    private var semanticAppearance: PanelSemanticAppearance

    var renderedForegroundColor: NSColor {
        semanticAppearance.foregroundColor
    }

    init(
        threadID: String,
        title: String,
        language: AppLanguage,
        textAlignment: TaskActivityTextAlignment,
        semanticAppearance: PanelSemanticAppearance
    ) {
        self.threadID = threadID
        self.title = title
        self.language = language
        self.textAlignment = textAlignment
        self.semanticAppearance = semanticAppearance
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.link)
        updateAccessibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    func update(
        title: String,
        language: AppLanguage,
        textAlignment: TaskActivityTextAlignment
    ) {
        guard self.title != title
                || self.language != language
                || self.textAlignment != textAlignment else { return }
        self.title = title
        self.language = language
        self.textAlignment = textAlignment
        updateAccessibility()
        needsDisplay = true
    }

    func setAppearance(_ semanticAppearance: PanelSemanticAppearance) {
        guard self.semanticAppearance != semanticAppearance else { return }
        self.semanticAppearance = semanticAppearance
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = textAlignment == .left ? .left : .right
        let shadow = NSShadow()
        shadow.shadowColor = semanticAppearance.shadowColor.withAlphaComponent(0.62)
        shadow.shadowBlurRadius = 0.45
        shadow.shadowOffset = .zero
        (title as NSString).draw(
            in: bounds.insetBy(dx: 0, dy: 1),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 8, weight: .semibold),
                .foregroundColor: renderedForegroundColor,
                .paragraphStyle: paragraph,
                .shadow: shadow,
            ]
        )
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let url = CodexThreadLink.url(threadID: threadID) else { return }
        NSWorkspace.shared.open(url)
    }

    private func updateAccessibility() {
        let label = language.openSession(title)
        setAccessibilityLabel(label)
        toolTip = label
    }
}
