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
    private var appearance: NSAppearance?

    func setAppearance(_ appearance: NSAppearance?) {
        self.appearance = appearance
        for panel in panels.values {
            panel.appearance = appearance
            panel.contentView?.needsDisplay = true
        }
    }

    func update(taskPanelFrame: CGRect, plan: TaskExecutionLayout.Plan) {
        let links = TaskExecutionLayout.sessionLinks(for: plan, panelWidth: taskPanelFrame.width)
        let activeIDs = Set(links.map(\.id))

        let staleIDs = panels.keys.filter { !activeIDs.contains($0) }
        for id in staleIDs {
            panels.removeValue(forKey: id)?.orderOut(nil)
        }

        for link in links {
            let panel = panels[link.id] ?? makePanel(threadID: link.threadID, title: link.title)
            panels[link.id] = panel
            (panel.contentView as? CodexSessionLinkView)?.update(title: link.title)
            panel.setFrame(link.frame.offsetBy(dx: taskPanelFrame.minX, dy: taskPanelFrame.minY), display: true)
            panel.orderFrontRegardless()
        }
    }

    private func makePanel(threadID: String, title: String) -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = CodexSessionLinkView(threadID: threadID, title: title)
        panel.appearance = appearance
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

private final class CodexSessionLinkView: NSView {
    private let threadID: String
    private var title: String

    init(threadID: String, title: String) {
        self.threadID = threadID
        self.title = title
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    func update(title: String) {
        guard self.title != title else { return }
        self.title = title
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.62)
        shadow.shadowBlurRadius = 0.45
        shadow.shadowOffset = .zero
        (title as NSString).draw(
            in: bounds.insetBy(dx: 0, dy: 1),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 8, weight: .semibold),
                .foregroundColor: NSColor.white,
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
}
