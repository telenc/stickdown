import AppKit
import SwiftUI
import Combine

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
    private var cancellables = Set<AnyCancellable>()
    private let collapsedHeight: CGFloat = 32

    /// Source de vérité : la géométrie DÉPLIÉE complète. Le repli n'est qu'un affichage.
    private var expandedFrame = NSRect(x: 0, y: 0, width: 360, height: 420)
    private var applyingFrame = false   // évite que nos propres setFrame ne corrompent expandedFrame

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

        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.minSize = NSSize(width: 220, height: 160)

        vm.$pinned
            .sink { [weak self] pinned in self?.applyPinned(pinned) }
            .store(in: &cancellables)
        vm.$opacity
            .sink { [weak self] value in self?.panel.alphaValue = CGFloat(value) }
            .store(in: &cancellables)

        let root = PostItView(
            vm: vm,
            onClose: { [weak self] in self?.close() },
            onOpenNote: { [weak self] name in self?.onOpenNote?(name) }
        )
        let hosting = NSHostingView(rootView: root)
        hosting.wantsLayer = true
        // Empêche SwiftUI de redimensionner la fenêtre selon son contenu : c'est NOUS qui gérons la taille.
        hosting.sizingOptions = []
        panel.contentView = hosting

        loadExpandedFrame()

        vm.$collapsed
            .sink { [weak self] collapsed in self?.applyCollapsed(collapsed) }
            .store(in: &cancellables)
    }

    // MARK: Repli (transformation visuelle)

    private func collapsedRect(from e: NSRect) -> NSRect {
        // Même haut, même largeur, hauteur réduite à la barre de titre.
        NSRect(x: e.minX, y: e.maxY - collapsedHeight, width: e.width, height: collapsedHeight)
    }

    private func applyCollapsed(_ collapsed: Bool) {
        applyingFrame = true
        if collapsed {
            panel.minSize = NSSize(width: 220, height: collapsedHeight)
            panel.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: collapsedHeight)
            panel.setFrame(collapsedRect(from: expandedFrame), display: true)
        } else {
            panel.minSize = NSSize(width: 220, height: 160)
            panel.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            panel.setFrame(expandedFrame, display: true)
        }
        applyingFrame = false
    }

    private func applyPinned(_ pinned: Bool) {
        panel.isFloatingPanel = pinned
        panel.level = pinned ? .floating : .normal
        panel.collectionBehavior = pinned
            ? [.canJoinAllSpaces, .fullScreenAuxiliary]
            : [.fullScreenAuxiliary]
    }

    func show() {
        ensureOnScreen()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Rapatrie la note sur un écran visible si sa géométrie sauvegardée pointe
    /// vers un écran débranché (sinon elle reste invisible, « cachée » hors champ).
    func ensureOnScreen() {
        let onAScreen = NSScreen.screens.contains { screen in
            // On exige un recouvrement réel, pas juste un pixel partagé au bord.
            let visible = screen.visibleFrame.intersection(expandedFrame)
            return visible.width >= 60 && visible.height >= 40
        }
        guard !onAScreen, let target = NSScreen.main ?? NSScreen.screens.first else { return }

        let v = target.visibleFrame
        var f = expandedFrame
        f.size.width = min(f.width, v.width)
        f.size.height = min(f.height, v.height)
        f.origin.x = min(max(v.minX, f.minX), v.maxX - f.width)
        f.origin.y = min(max(v.minY, f.minY), v.maxY - f.height)
        // Si totalement hors écran, on centre.
        if !v.intersects(f) {
            f.origin.x = v.midX - f.width / 2
            f.origin.y = v.midY - f.height / 2
        }
        expandedFrame = f
        saveFrame()

        applyingFrame = true
        panel.setFrame(vm.collapsed ? collapsedRect(from: expandedFrame) : expandedFrame, display: true)
        applyingFrame = false
        panel.orderFront(nil)
    }

    func close() {
        panel.close()
    }

    // MARK: Persistance de la géométrie

    private func loadExpandedFrame() {
        if let s = UserDefaults.standard.string(forKey: frameKey) {
            expandedFrame = NSRectFromString(s)
            if expandedFrame.height < 160 { expandedFrame.size.height = 420 }  // répare une géométrie corrompue
        } else if let screen = NSScreen.main {
            let v = screen.visibleFrame
            let off = CGFloat(UserDefaults.standard.integer(forKey: "cascade") % 6) * 28
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "cascade") + 1, forKey: "cascade")
            expandedFrame = NSRect(x: v.maxX - 380 - off, y: v.maxY - 460 - off, width: 360, height: 420)
        }
        applyingFrame = true
        panel.setFrame(vm.collapsed ? collapsedRect(from: expandedFrame) : expandedFrame, display: false)
        applyingFrame = false
    }

    private func saveFrame() {
        UserDefaults.standard.set(NSStringFromRect(expandedFrame), forKey: frameKey)
    }

    /// Met à jour la géométrie dépliée d'après la position/taille actuelle de la fenêtre.
    private func syncExpandedFrame() {
        guard !applyingFrame else { return }
        let f = panel.frame
        if vm.collapsed {
            // En replié, on ne suit que la position/largeur (le haut reste ancré).
            expandedFrame.origin.x = f.origin.x
            expandedFrame.size.width = f.size.width
            expandedFrame.origin.y = f.maxY - expandedFrame.size.height
        } else {
            expandedFrame = f
        }
        saveFrame()
    }

    func windowDidMove(_ notification: Notification) { syncExpandedFrame() }
    func windowDidResize(_ notification: Notification) { syncExpandedFrame() }

    func windowWillClose(_ notification: Notification) {
        syncExpandedFrame()
        onClose?(url)
    }
}
