import Foundation

/// Gère le coffre Obsidian (ou n'importe quel dossier de .md) : localisation et résolution des notes.
enum Vault {
    private static let rootKey = "vaultRoot"

    /// Dossier racine choisi par l'utilisateur, ou nil si non configuré / introuvable.
    static var rootURL: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: rootKey),
                  FileManager.default.fileExists(atPath: path) else { return nil }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set { UserDefaults.standard.set(newValue?.path, forKey: rootKey) }
    }

    static var isConfigured: Bool { rootURL != nil }

    /// Tous les fichiers .md du coffre (hors dossiers cachés type .obsidian).
    static func markdownFiles() -> [URL] {
        guard let root = rootURL else { return [] }
        let fm = FileManager.default
        guard let en = fm.enumerator(at: root,
                                     includingPropertiesForKeys: [.isRegularFileKey],
                                     options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }
        var out: [URL] = []
        for case let url as URL in en where url.pathExtension.lowercased() == "md" {
            out.append(url)
        }
        return out.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Crée une nouvelle note .md à la racine du coffre (si absente) et retourne son URL.
    static func createNote(named raw: String) -> URL? {
        guard let root = rootURL else { return nil }
        var name = raw
        if let hash = name.firstIndex(of: "#") { name = String(name[..<hash]) }
        name = name.trimmingCharacters(in: .whitespaces)
        if name.lowercased().hasSuffix(".md") { name = String(name.dropLast(3)) }
        guard !name.isEmpty else { return nil }
        name = name.replacingOccurrences(of: "/", with: "-")
                   .replacingOccurrences(of: ":", with: "-")

        let url = root.appendingPathComponent(name + ".md")
        if !FileManager.default.fileExists(atPath: url.path) {
            let content = "# \(name)\n\n"
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Résout un wikilink ([[Nom]]) vers un fichier .md du coffre.
    static func resolve(noteName raw: String) -> URL? {
        var name = raw
        if let hash = name.firstIndex(of: "#") { name = String(name[..<hash]) }
        name = name.trimmingCharacters(in: .whitespaces)
        if name.lowercased().hasSuffix(".md") { name = String(name.dropLast(3)) }

        let files = markdownFiles()
        if let hit = files.first(where: {
            $0.deletingPathExtension().lastPathComponent.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            return hit
        }
        return files.first { $0.path.localizedCaseInsensitiveContains(name) }
    }
}
