import SwiftUI

/// État d'un post-it : texte, métadonnées (titre/couleur), sauvegarde et sync disque.
@MainActor
final class PostItViewModel: ObservableObject {
    let url: URL

    @Published var rawText: String = ""
    @Published var title: String = ""
    @Published var colorName: String?

    /// Vrai quand l'éditeur a le focus (empêche d'écraser une saisie en cours).
    var isEditorFocused = false

    private var watcher: FileWatcher?
    private var saveWorkItem: DispatchWorkItem?
    private var isSaving = false

    init(url: URL) {
        self.url = url
        loadFromDisk()
        watcher = FileWatcher(url: url) { [weak self] in
            self?.reloadIfChanged()
        }
    }

    // MARK: Chargement

    func loadFromDisk() {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        apply(text)
    }

    private func apply(_ text: String) {
        rawText = text
        recomputeMeta(text)
    }

    private func recomputeMeta(_ text: String) {
        let (front, body, _) = Markdown.split(text)
        colorName = Markdown.frontmatterValue("colorful-sticky-bg", in: front)
        title = Self.computeTitle(body: body, url: url)
    }

    private static func computeTitle(body: [String], url: URL) -> String {
        for line in body {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("#") {
                return t.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
            }
        }
        return url.deletingPathExtension().lastPathComponent
    }

    private func reloadIfChanged() {
        if isSaving || isEditorFocused { return }
        let disk = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if disk != rawText { apply(disk) }
    }

    // MARK: Édition / sauvegarde

    /// Appelé par l'éditeur à chaque frappe.
    func onEditorChanged(_ text: String) {
        rawText = text
        recomputeMeta(text)
        scheduleSave(text)
    }

    private func scheduleSave(_ text: String) {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.write(text) }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Sauvegarde immédiate (ex: à la perte de focus).
    func flushSave() {
        saveWorkItem?.cancel()
        write(rawText)
    }

    private func write(_ text: String) {
        isSaving = true
        try? text.write(to: url, atomically: true, encoding: .utf8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isSaving = false
        }
    }
}
