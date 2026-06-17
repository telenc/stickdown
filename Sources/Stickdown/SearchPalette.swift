import SwiftUI
import AppKit

/// Panneau de recherche rapide (⌘O / raccourci global) pour ouvrir ou créer une note.
@MainActor
final class SearchPaletteController {
    private var panel: KeyPanel?
    var onOpenNote: ((URL) -> Void)?
    var onCreateNote: ((String) -> Void)?

    func toggle() {
        if let panel, panel.isVisible { close() } else { show() }
    }

    func show() {
        if panel == nil {
            let p = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 540, height: 380),
                             styleMask: [.borderless], backing: .buffered, defer: false)
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = true
            p.level = .floating
            p.isMovableByWindowBackground = true
            p.hidesOnDeactivate = true
            panel = p
        }
        guard let panel else { return }
        let view = SearchPalette(
            notes: Vault.markdownFiles(),
            onOpen: { [weak self] url in self?.onOpenNote?(url); self?.close() },
            onCreate: { [weak self] name in self?.onCreateNote?(name); self?.close() },
            onClose: { [weak self] in self?.close() }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        panel.contentView = hosting
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }
}

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct SearchPalette: View {
    let notes: [URL]
    var onOpen: (URL) -> Void
    var onCreate: (String) -> Void
    var onClose: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    private var results: [URL] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return notes }
        return notes
            .compactMap { url -> (URL, Int)? in
                let name = url.deletingPathExtension().lastPathComponent.lowercased()
                guard let score = matchScore(q, name) else { return nil }
                return (url, score)
            }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1
                : $0.0.lastPathComponent.localizedCaseInsensitiveCompare($1.0.lastPathComponent) == .orderedAscending }
            .map { $0.0 }
    }

    /// Score de pertinence, ou nil si pas de correspondance.
    private func matchScore(_ q: String, _ name: String) -> Int? {
        if name == q { return 100 }
        if name.hasPrefix(q) { return 80 }
        if name.contains(q) { return 60 }
        if isSubsequence(q, name) { return 40 }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Rechercher ou créer une note…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($focused)
                    .onSubmit(commit)
                    .onKeyPress(.downArrow) { move(1); return .handled }
                    .onKeyPress(.upArrow) { move(-1); return .handled }
                    .onKeyPress(.escape) { onClose(); return .handled }
            }
            .padding(14)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.element) { index, url in
                            row(index: index, url: url)
                                .id(index)
                        }
                        if results.isEmpty && !query.isEmpty {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Créer « \(query) »")
                                Spacer()
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                        }
                    }
                }
                .onChange(of: selection) { _, sel in
                    withAnimation(.linear(duration: 0.1)) { proxy.scrollTo(sel, anchor: .center) }
                }
            }
        }
        .frame(width: 540, height: 380)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.black.opacity(0.1)))
        .onAppear { focused = true; selection = 0 }
        .onChange(of: query) { _, _ in selection = 0 }
    }

    private func row(index: Int, url: URL) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "note.text").foregroundStyle(.secondary)
            Text(url.deletingPathExtension().lastPathComponent)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(index == selection ? Color.accentColor.opacity(0.22) : .clear)
        .contentShape(Rectangle())
        .onTapGesture { onOpen(url) }
    }

    private func move(_ delta: Int) {
        let count = results.count
        guard count > 0 else { return }
        selection = (selection + delta + count) % count
    }

    private func commit() {
        if results.indices.contains(selection) {
            onOpen(results[selection])
        } else if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            onCreate(query.trimmingCharacters(in: .whitespaces))
        }
    }

    /// « Sous-séquence » : les lettres de q apparaissent dans l'ordre dans s.
    private func isSubsequence(_ q: String, _ s: String) -> Bool {
        var qi = q.startIndex
        for ch in s {
            if qi == q.endIndex { break }
            if ch == q[qi] { qi = q.index(after: qi) }
        }
        return qi == q.endIndex
    }
}
