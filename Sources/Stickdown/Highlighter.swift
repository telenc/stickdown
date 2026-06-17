import AppKit

/// Polices et couleurs de l'éditeur. `scale` applique le zoom par note.
enum Style {
    static var scale: CGFloat = 1

    static var base: NSFont { .systemFont(ofSize: 13 * scale) }
    static var bold: NSFont { .boldSystemFont(ofSize: 13 * scale) }
    static var mono: NSFont { .monospacedSystemFont(ofSize: 12 * scale, weight: .regular) }
    static var italic: NSFont { NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask) }
    /// Police "invisible" pour masquer les marqueurs markdown hors ligne active.
    static var hidden: NSFont { .systemFont(ofSize: 0.01) }

    static func heading(_ level: Int) -> NSFont {
        let size: CGFloat
        switch level { case 1: size = 19; case 2: size = 16.5; case 3: size = 14.5; default: size = 13 }
        return NSFont.boldSystemFont(ofSize: size * scale)
    }

    static let text = NSColor.black.withAlphaComponent(0.85)
    static let dim = NSColor.black.withAlphaComponent(0.40)
    static let codeBG = NSColor.black.withAlphaComponent(0.06)

    static var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: base, .foregroundColor: text]
    }
}

/// Applique le style markdown "live" (façon Obsidian) : marqueurs masqués,
/// case à cocher dessinée, liens sans crochets ; la ligne du curseur reste en markdown brut.
enum Highlighter {
    private static let wikiLink = try! NSRegularExpression(pattern: "\\[\\[([^\\]\\|]+)(?:\\|([^\\]]+))?\\]\\]")
    private static let mdLink   = try! NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)")
    private static let boldRe   = try! NSRegularExpression(pattern: "\\*\\*([^*]+)\\*\\*")
    private static let italicRe = try! NSRegularExpression(pattern: "(?<![_\\w])_([^_]+)_(?![_\\w])")
    private static let codeRe   = try! NSRegularExpression(pattern: "`([^`]+)`")

    static func apply(to textView: NSTextView?, accent: NSColor, activeLine: NSRange, scale: CGFloat = 1) {
        guard let textView, let storage = textView.textStorage else { return }
        Style.scale = scale
        let ns = storage.string as NSString
        let full = NSRange(location: 0, length: ns.length)

        storage.beginEditing()
        storage.setAttributes(Style.baseAttributes, range: full)

        var firstHeadingHandled = false
        ns.enumerateSubstrings(in: full, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let active = lineRange.location == activeLine.location
            let trimmed = ns.substring(with: lineRange).trimmingCharacters(in: .whitespaces)
            // Premier titre = déjà affiché dans l'entête du post-it → on le masque dans le corps.
            if !firstHeadingHandled, headingLevel(trimmed) != nil {
                firstHeadingHandled = true
                if !active {
                    hide(storage, ns.lineRange(for: lineRange))
                    return
                }
            }
            styleLine(ns, lineRange, storage, accent, active: active)
        }

        inlinePass(storage, ns, full, accent, activeLine: activeLine)

        hideFrontmatter(ns, storage)

        storage.endEditing()
        textView.typingAttributes = Style.baseAttributes
    }

    /// Niveau de titre (1-6) si la ligne est un titre markdown, sinon nil.
    private static func headingLevel(_ trimmed: String) -> Int? {
        guard trimmed.hasPrefix("#") else { return nil }
        var level = 0
        for c in trimmed { if c == "#" { level += 1 } else { break } }
        guard level <= 6, trimmed.dropFirst(level).first == " " else { return nil }
        return level
    }

    // MARK: Helpers de masquage

    private static func hide(_ storage: NSTextStorage, _ range: NSRange) {
        guard range.length > 0, range.location >= 0,
              range.location + range.length <= storage.length else { return }
        storage.addAttribute(.font, value: Style.hidden, range: range)
        storage.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
    }

    // MARK: Lignes

    private static func styleLine(_ ns: NSString, _ lineRange: NSRange, _ storage: NSTextStorage,
                                  _ accent: NSColor, active: Bool) {
        let line = ns.substring(with: lineRange)
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return }

        // Titre
        if trimmed.hasPrefix("#") {
            var level = 0
            for c in trimmed { if c == "#" { level += 1 } else { break } }
            if level <= 6, trimmed.dropFirst(level).first == " " {
                storage.addAttribute(.font, value: Style.heading(level), range: lineRange)
                storage.addAttribute(.foregroundColor, value: accent, range: lineRange)
                if !active {
                    let leading = line.prefix { $0 == " " || $0 == "\t" }.count
                    hide(storage, NSRange(location: lineRange.location + leading, length: level + 1))
                }
                return
            }
        }

        // Case à cocher
        if let cb = Markdown.parseCheckbox(trimmed) {
            let nsLine = line as NSString
            let openR = nsLine.range(of: "[")
            let closeR = nsLine.range(of: "]")
            guard openR.location != NSNotFound, closeR.location != NSNotFound else { return }
            let leading = line.prefix { $0 == " " || $0 == "\t" }.count

            let triplet = NSRange(location: lineRange.location + openR.location,
                                  length: closeR.location - openR.location + 1)
            if active {
                storage.addAttribute(.foregroundColor, value: accent, range: triplet)
            } else {
                // Masque "- " ; rend "[ ]" invisible mais de largeur normale.
                // La case est dessinée par CheckboxLayoutManager via .checkboxBox.
                let dashIndex = lineRange.location + leading
                hide(storage, NSRange(location: dashIndex, length: openR.location - leading))
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: triplet)
                storage.addAttribute(.checkboxBox, value: NSNumber(value: cb.checked), range: triplet)
            }

            if cb.checked {
                let textStart = lineRange.location + closeR.location + 1
                let textLen = lineRange.length - (closeR.location + 1)
                if textLen > 0 {
                    let r = NSRange(location: textStart, length: textLen)
                    storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: r)
                    storage.addAttribute(.foregroundColor, value: Style.dim, range: r)
                }
            }
            return
        }

        // Citation
        if trimmed.hasPrefix(">") {
            storage.addAttribute(.font, value: Style.italic, range: lineRange)
            storage.addAttribute(.foregroundColor, value: Style.dim, range: lineRange)
            if !active {
                let leading = line.prefix { $0 == " " || $0 == "\t" }.count
                let len = line.dropFirst(leading).prefix { $0 == ">" || $0 == " " }.count
                hide(storage, NSRange(location: lineRange.location + leading, length: len))
            }
            return
        }

        // Puce : colore le marqueur
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            let leading = line.prefix { $0 == " " || $0 == "\t" }.count
            storage.addAttribute(.foregroundColor, value: accent,
                                 range: NSRange(location: lineRange.location + leading, length: 1))
        }
    }

    // MARK: Inline

    private static func inlinePass(_ storage: NSTextStorage, _ ns: NSString, _ full: NSRange,
                                   _ accent: NSColor, activeLine: NSRange) {
        func isActive(_ r: NSRange) -> Bool {
            ns.lineRange(for: NSRange(location: r.location, length: 0)).location == activeLine.location
        }

        // Liens markdown [label](url)
        forEach(mdLink, ns, full) { m in
            let whole = m.range
            let label = m.range(at: 1)
            let url = m.range(at: 2).location != NSNotFound ? ns.substring(with: m.range(at: 2)) : ""
            storage.addAttribute(.foregroundColor, value: accent, range: isActive(whole) ? whole : label)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: label)
            storage.addAttribute(.mdTarget, value: url, range: whole)
            if !isActive(whole) {
                hide(storage, NSRange(location: whole.location, length: label.location - whole.location)) // "["
                hide(storage, NSRange(location: label.location + label.length,
                                      length: whole.location + whole.length - (label.location + label.length))) // "](url)"
            }
        }

        // Wikilinks [[Cible|Alias]]
        forEach(wikiLink, ns, full) { m in
            let whole = m.range
            let target = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            let hasAlias = m.range(at: 2).location != NSNotFound
            let label = hasAlias ? m.range(at: 2) : m.range(at: 1)
            storage.addAttribute(.mdTarget, value: target, range: whole)
            storage.addAttribute(.foregroundColor, value: accent, range: isActive(whole) ? whole : label)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: label)
            if !isActive(whole) {
                hide(storage, NSRange(location: whole.location, length: label.location - whole.location)) // "[[" (+ "Cible|")
                hide(storage, NSRange(location: label.location + label.length,
                                      length: whole.location + whole.length - (label.location + label.length))) // "]]"
            }
        }

        // Code `…`
        forEach(codeRe, ns, full) { m in
            let inner = m.range(at: 1)
            storage.addAttribute(.font, value: Style.mono, range: m.range)
            storage.addAttribute(.backgroundColor, value: Style.codeBG, range: m.range)
            if !isActive(m.range) {
                hide(storage, NSRange(location: m.range.location, length: 1))
                hide(storage, NSRange(location: inner.location + inner.length, length: 1))
            }
        }

        // Gras **…**
        forEach(boldRe, ns, full) { m in
            let inner = m.range(at: 1)
            storage.addAttribute(.font, value: Style.bold, range: isActive(m.range) ? m.range : inner)
            if !isActive(m.range) {
                hide(storage, NSRange(location: m.range.location, length: 2))
                hide(storage, NSRange(location: inner.location + inner.length, length: 2))
            }
        }

        // Italique _…_
        forEach(italicRe, ns, full) { m in
            let inner = m.range(at: 1)
            storage.addAttribute(.font, value: Style.italic, range: isActive(m.range) ? m.range : inner)
            if !isActive(m.range) {
                hide(storage, NSRange(location: m.range.location, length: 1))
                hide(storage, NSRange(location: inner.location + inner.length, length: 1))
            }
        }
    }

    private static func forEach(_ regex: NSRegularExpression, _ ns: NSString, _ range: NSRange,
                                _ body: (NSTextCheckingResult) -> Void) {
        regex.enumerateMatches(in: ns as String, range: range) { m, _, _ in
            if let m { body(m) }
        }
    }

    // MARK: Frontmatter

    private static func hideFrontmatter(_ ns: NSString, _ storage: NSTextStorage) {
        guard ns.hasPrefix("---") else { return }
        let after = NSRange(location: 3, length: ns.length - 3)
        let close = ns.range(of: "\n---", options: [], range: after)
        guard close.location != NSNotFound else { return }
        var end = close.location + close.length
        // Replie aussi les lignes vides juste après le frontmatter.
        while end < ns.length, ns.substring(with: NSRange(location: end, length: 1)) == "\n" { end += 1 }
        hide(storage, NSRange(location: 0, length: end))
    }
}
