import AppKit
import SwiftUI

/// Panneau flottant (le "post-it").
final class PostItPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class PostItWindowController: NSObject, NSWindowDelegate {
    let url: URL
    let vm: PostItViewModel
    let panel: PostItPanel

    var onClose: ((URL) -> Void)?
    var onOpenNote: ((String) -> Void)?

    private var frameKey: String { "frame::\(url.path)" }

    init(url: URL) {
        self.url = url
        self.vm = PostItViewModel(url: url)
        self.panel = PostItPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 380),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.minSize = NSSize(width: 220, height: 160)

        let root = PostItView(
            vm: vm,
            onClose: { [weak self] in self?.close() },
            onOpenNote: { [weak self] name in self?.onOpenNote?(name) }
        )
        let hosting = NSHostingView(rootView: root)
        hosting.wantsLayer = true
        panel.contentView = hosting

        restoreFrame()
    }

    func show() {
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel.close()
    }

    // MARK: Persistance de la géométrie

    private func restoreFrame() {
        if let s = UserDefaults.standard.string(forKey: frameKey) {
            panel.setFrame(NSRectFromString(s), display: false)
        } else {
            // Cascade depuis le coin haut-droit de l'écran principal.
            if let screen = NSScreen.main {
                let v = screen.visibleFrame
                let off = CGFloat(UserDefaults.standard.integer(forKey: "cascade") % 6) * 28
                UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "cascade") + 1, forKey: "cascade")
                panel.setFrameOrigin(NSPoint(x: v.maxX - 360 - off, y: v.maxY - 420 - off))
            }
        }
    }

    private func saveFrame() {
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: frameKey)
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { saveFrame() }

    func windowWillClose(_ notification: Notification) {
        saveFrame()
        onClose?(url)
    }
}
