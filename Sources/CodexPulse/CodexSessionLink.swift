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

/// Deep link opened by clicking a session title. Codex resumes the exact
/// thread (`codex://threads/…`); Claude Code resumes the exact session in
/// the Claude desktop app, which imports the CLI transcript
/// (`claude://resume?session=…`); OpenCode defines no session-resume link,
/// so its titles front the session's project (`opencode://open-project?directory=…`).
enum SessionDeepLink {
    static func url(tool: Tool, threadID: String, directory: String) -> URL? {
        switch tool {
        case .codex:
            CodexThreadLink.url(threadID: threadID)
        case .claude:
            claudeResumeURL(threadID: threadID)
        case .opencode:
            directoryURL(scheme: "opencode", host: "open-project", parameter: "directory", directory: directory)
        }
    }

    /// The desktop app only imports UUID session IDs and silently drops
    /// anything else, so a malformed ID renders a non-interactive title.
    private static func claudeResumeURL(threadID: String) -> URL? {
        let prefix = "claude:"
        let sessionID = threadID.hasPrefix(prefix)
            ? String(threadID.dropFirst(prefix.count))
            : threadID
        guard UUID(uuidString: sessionID) != nil else { return nil }
        var components = URLComponents()
        components.scheme = "claude"
        components.host = "resume"
        components.queryItems = [URLQueryItem(name: "session", value: sessionID)]
        return components.url
    }

    private static func directoryURL(
        scheme: String,
        host: String,
        parameter: String,
        directory: String
    ) -> URL? {
        guard !directory.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: parameter, value: directory)]
        return components.url
    }
}

@MainActor
final class CodexSessionLinkController {
    private var panels: [String: NSPanel] = [:]
    private var semanticAppearance: PanelSemanticAppearance = .dark
    private var textColor: WallpaperRGB?

    func setAppearance(
        _ semanticAppearance: PanelSemanticAppearance,
        textColor: WallpaperRGB? = nil
    ) {
        self.semanticAppearance = semanticAppearance
        self.textColor = textColor
        let appearance = NSAppearance(
            named: semanticAppearance == .dark ? .darkAqua : .aqua
        )
        for panel in panels.values {
            panel.appearance = appearance
            (panel.contentView as? CodexSessionLinkView)?.setAppearance(
                semanticAppearance,
                textColor: textColor
            )
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
            let url = SessionDeepLink.url(
                tool: link.tool,
                threadID: link.threadID,
                directory: link.directory
            )
            let panel = panels[link.id] ?? makePanel(
                url: url,
                title: link.title,
                language: language,
                textAlignment: textAlignment
            )
            panels[link.id] = panel
            (panel.contentView as? CodexSessionLinkView)?.update(
                url: url,
                title: link.title,
                language: language,
                textAlignment: textAlignment
            )
            // Sessions without a deep link stay click-through like the rest
            // of the panel content.
            panel.ignoresMouseEvents = url == nil
            panel.setFrame(link.frame.offsetBy(dx: taskPanelFrame.minX, dy: taskPanelFrame.minY), display: true)
            panel.orderFrontRegardless()
        }
    }

    private func makePanel(
        url: URL?,
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
            url: url,
            title: title,
            language: language,
            textAlignment: textAlignment,
            semanticAppearance: semanticAppearance,
            textColor: textColor
        )
        panel.appearance = NSAppearance(
            named: semanticAppearance == .dark ? .darkAqua : .aqua
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = url == nil
        panel.hidesOnDeactivate = false
        panel.level = DockPanelWindowLevel.sessionLink
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        return panel
    }
}

final class CodexSessionLinkView: NSView {
    /// Deep link opened on click; `nil` renders a non-interactive title.
    private var url: URL?
    private var title: String
    private var language: AppLanguage
    private var textAlignment: TaskActivityTextAlignment
    private var semanticAppearance: PanelSemanticAppearance
    private var textColor: WallpaperRGB?

    var renderedForegroundColor: NSColor {
        guard let textColor else { return semanticAppearance.foregroundColor }
        return NSColor(
            srgbRed: textColor.red,
            green: textColor.green,
            blue: textColor.blue,
            alpha: textColor.alpha
        )
    }

    init(
        url: URL?,
        title: String,
        language: AppLanguage,
        textAlignment: TaskActivityTextAlignment,
        semanticAppearance: PanelSemanticAppearance,
        textColor: WallpaperRGB? = nil
    ) {
        self.url = url
        self.title = title
        self.language = language
        self.textAlignment = textAlignment
        self.semanticAppearance = semanticAppearance
        self.textColor = textColor
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(url == nil ? .staticText : .link)
        updateAccessibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    func update(
        url: URL?,
        title: String,
        language: AppLanguage,
        textAlignment: TaskActivityTextAlignment
    ) {
        guard self.url != url
                || self.title != title
                || self.language != language
                || self.textAlignment != textAlignment else { return }
        self.url = url
        self.title = title
        self.language = language
        self.textAlignment = textAlignment
        setAccessibilityRole(url == nil ? .staticText : .link)
        window?.invalidateCursorRects(for: self)
        updateAccessibility()
        needsDisplay = true
    }

    func setAppearance(
        _ semanticAppearance: PanelSemanticAppearance,
        textColor: WallpaperRGB? = nil
    ) {
        guard self.semanticAppearance != semanticAppearance
                || self.textColor != textColor else { return }
        self.semanticAppearance = semanticAppearance
        self.textColor = textColor
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
        guard url != nil else { return }
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { url != nil }

    override func mouseDown(with event: NSEvent) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    private func updateAccessibility() {
        let label = url == nil ? title : language.openSession(title)
        setAccessibilityLabel(label)
        toolTip = label
    }
}
