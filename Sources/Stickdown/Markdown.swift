import SwiftUI

/// Un bloc de markdown rendu dans le post-it.
enum Block: Identifiable {
    case heading(id: Int, level: Int, text: String)
    case checkbox(id: Int, checked: Bool, text: String, line: Int)
    case bullet(id: Int, text: String)
    case quote(id: Int, text: String)
    case code(id: Int, text: String)
    case paragraph(id: Int, text: String)
    case blank(id: Int)

    var id: Int {
        switch self {
        case .heading(let id, _, _), .checkbox(let id, _, _, _), .bullet(let id, _),
             .quote(let id, _), .code(let id, _), .paragraph(let id, _), .blank(let id):
            return id
        }
    }
}

enum Markdown {
    /// Sépare le frontmatter YAML du corps. Retourne (lignesFrontmatter, lignesCorps, indexDebutCorps).
    static func split(_ text: String) -> (front: [String], body: [String], bodyStart: Int) {
        let lines = text.components(separatedBy: "\n")
        if lines.first == "---" {
            if let end = lines.dropFirst().firstIndex(of: "---") {
                let front = Array(lines[0...end])
                let body = Array(lines[(end + 1)...])
                return (front, body, end + 1)
            }
        }
        return ([], lines, 0)
    }

    /// Extrait une valeur du frontmatter (ex: colorful-sticky-bg).
    static func frontmatterValue(_ key: String, in front: [String]) -> String? {
        for line in front {
            if line.hasPrefix("\(key):") {
                return line.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Écrit (ou insère) une clé de frontmatter et retourne le texte modifié.
    static func settingFrontmatter(_ text: String, key: String, value: String) -> String {
        var lines = text.components(separatedBy: "\n")
        let newLine = "\(key): \(value)"
        if lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") {
            var replaced = false
            if end > 1 {
                for i in 1..<end where lines[i].hasPrefix("\(key):") {
                    lines[i] = newLine
                    replaced = true
                    break
                }
            }
            if !replaced { lines.insert(newLine, at: end) }
            return lines.joined(separator: "\n")
        }
        return "---\n\(newLine)\n---\n\n" + text
    }

    /// Construit les blocs à partir des lignes du corps. `offset` = index absolu de la 1re ligne du corps.
    static func parse(body: [String], offset: Int) -> [Block] {
        var blocks: [Block] = []
        var inCode = false
        var codeBuffer: [String] = []
        var bid = 0
        func next() -> Int { defer { bid += 1 }; return bid }

        for (i, line) in body.enumerated() {
            let absLine = i + offset
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "```" || trimmed.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(id: next(), text: codeBuffer.joined(separator: "\n")))
                    codeBuffer.removeAll()
                    inCode = false
                } else {
                    inCode = true
                }
                continue
            }
            if inCode { codeBuffer.append(line); continue }

            if trimmed.isEmpty { blocks.append(.blank(id: next())); continue }

            // Titre
            if trimmed.hasPrefix("#") {
                var level = 0
                for c in trimmed { if c == "#" { level += 1 } else { break } }
                if level <= 6, trimmed.dropFirst(level).first == " " {
                    let txt = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                    blocks.append(.heading(id: next(), level: level, text: txt))
                    continue
                }
            }

            // Case à cocher : - [ ] / - [x]
            if let cb = parseCheckbox(trimmed) {
                blocks.append(.checkbox(id: next(), checked: cb.checked, text: cb.text, line: absLine))
                continue
            }

            // Puce
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                blocks.append(.bullet(id: next(), text: String(trimmed.dropFirst(2))))
                continue
            }

            // Citation
            if trimmed.hasPrefix(">") {
                let txt = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                blocks.append(.quote(id: next(), text: txt))
                continue
            }

            blocks.append(.paragraph(id: next(), text: trimmed))
        }
        if inCode { blocks.append(.code(id: next(), text: codeBuffer.joined(separator: "\n"))) }
        return blocks
    }

    static func parseCheckbox(_ trimmed: String) -> (checked: Bool, text: String)? {
        // formats: "- [ ] x", "- [x] x", "* [X] x"
        guard trimmed.count >= 5 else { return nil }
        let chars = Array(trimmed)
        guard (chars[0] == "-" || chars[0] == "*"), chars[1] == " ", chars[2] == "[",
              chars[4] == "]" else { return nil }
        let mark = chars[3]
        let checked = (mark == "x" || mark == "X")
        guard checked || mark == " " else { return nil }
        var rest = String(chars[5...])
        if rest.hasPrefix(" ") { rest.removeFirst() }
        return (checked, rest)
    }

    /// Convertit les wikilinks [[Cible|Alias]] en liens markdown cliquables (schéma postit://).
    static func convertWikilinks(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\[\\[([^\\]\\|]+)(?:\\|([^\\]]+))?\\]\\]") else { return s }
        let ns = s as NSString
        var result = ""
        var last = 0
        for m in regex.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let target = ns.substring(with: m.range(at: 1))
            let alias = m.range(at: 2).location != NSNotFound ? ns.substring(with: m.range(at: 2)) : target
            let encoded = target.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? target
            result += "[\(alias)](postit://open?n=\(encoded))"
            last = m.range.location + m.range.length
        }
        result += ns.substring(from: last)
        return result
    }

    /// Rendu inline (gras/italique/liens/wikilinks) en AttributedString natif.
    static func attributed(_ raw: String) -> AttributedString {
        let converted = convertWikilinks(raw)
        let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let a = try? AttributedString(markdown: converted, options: opts) {
            return a
        }
        return AttributedString(raw)
    }
}
