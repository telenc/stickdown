import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var controllers: [URL: PostItWindowController] = [:]
    private let openNotesKey = "openNotes"

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Stickdown")
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        installMainMenu()

        if !Vault.isConfigured { promptForVault() }
        reopenSavedNotes()
    }

    /// Menu principal (invisible pour une app accessory) qui active les raccourcis
    /// d'édition standards (⌘C/⌘V/⌘X/⌘A/⌘Z) dans les champs de texte.
    private func installMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quitter Stickdown",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let editMenu = NSMenu(title: "Édition")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Annuler", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Rétablir", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Couper", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copier", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Coller", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Tout sélectionner",
                         action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let viewItem = NSMenuItem()
        main.addItem(viewItem)
        let viewMenu = NSMenu(title: "Affichage")
        viewItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "Agrandir le texte", action: Selector(("zoomIn:")), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Réduire le texte", action: Selector(("zoomOut:")), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Taille réelle", action: Selector(("actualSize:")), keyEquivalent: "0")

        NSApp.mainMenu = main
    }

    // MARK: Ouverture de notes

    func openNote(name: String) {
        guard let url = Vault.resolve(noteName: name) ?? Vault.createNote(named: name) else {
            NSSound.beep()
            return
        }
        openNote(url: url)
    }

    func openNote(url: URL) {
        if let existing = controllers[url] {
            existing.show()
            return
        }
        let controller = PostItWindowController(url: url)
        controller.onClose = { [weak self] u in
            self?.controllers[u] = nil
            self?.persistOpenNotes()
        }
        controller.onOpenNote = { [weak self] name in
            self?.openNote(name: name)
        }
        controllers[url] = controller
        controller.show()
        persistOpenNotes()
    }

    private func persistOpenNotes() {
        UserDefaults.standard.set(controllers.keys.map { $0.path }, forKey: openNotesKey)
    }

    private func reopenSavedNotes() {
        let paths = UserDefaults.standard.stringArray(forKey: openNotesKey) ?? []
        for p in paths where FileManager.default.fileExists(atPath: p) {
            openNote(url: URL(fileURLWithPath: p))
        }
    }

    // MARK: Coffre

    @discardableResult
    private func promptForVault() -> Bool {
        let panel = NSOpenPanel()
        panel.message = "Choisis ton coffre Obsidian (ou un dossier de fichiers .md)"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choisir ce dossier"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            Vault.rootURL = url
            return true
        }
        return false
    }

    // MARK: Menu (construit à la volée)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if Vault.isConfigured {
            let header = NSMenuItem(title: "Ouvrir une note", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for url in Vault.markdownFiles() {
                let item = NSMenuItem(title: url.deletingPathExtension().lastPathComponent,
                                      action: #selector(openFromMenu(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = url
                if controllers[url] != nil { item.state = .on }
                menu.addItem(item)
            }
            menu.addItem(.separator())

            let newNote = NSMenuItem(title: "Nouvelle note…", action: #selector(newNote), keyEquivalent: "n")
            newNote.target = self
            menu.addItem(newNote)
        } else {
            let none = NSMenuItem(title: "Aucun coffre configuré", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        }

        let chooseVault = NSMenuItem(title: "Choisir le coffre…", action: #selector(chooseVault), keyEquivalent: "")
        chooseVault.target = self
        menu.addItem(chooseVault)

        if Vault.isConfigured, let root = Vault.rootURL {
            let info = NSMenuItem(title: "Coffre : \(root.lastPathComponent)", action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
        }

        menu.addItem(.separator())

        let launch = NSMenuItem(title: "Lancer au démarrage", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        launch.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(launch)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quitter Stickdown", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func openFromMenu(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        if let existing = controllers[url] { existing.close() } else { openNote(url: url) }
    }

    @objc private func newNote() {
        let alert = NSAlert()
        alert.messageText = "Nouvelle note"
        alert.informativeText = "Nom de la note :"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "Ma note"
        alert.accessoryView = field
        alert.addButton(withTitle: "Créer")
        alert.addButton(withTitle: "Annuler")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let name = field.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { openNote(name: name) }
        }
    }

    @objc private func chooseVault() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = Vault.rootURL
        panel.prompt = "Choisir"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url { Vault.rootURL = url }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
        }
    }
}
