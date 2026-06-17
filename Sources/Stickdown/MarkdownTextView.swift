import SwiftUI
import AppKit

extension NSAttributedString.Key {
    /// Cible d'un lien/wikilink (nom de note ou URL), pour le ⌘+clic.
    static let mdTarget = NSAttributedString.Key("mdTarget")
    /// Marque la zone "[ ]"/"[x]" d'une case à cocher (valeur = NSNumber coché).
    static let checkboxBox = NSAttributedString.Key("checkboxBox")
}

/// Dessine de vraies cases à cocher (SF Symbol) par-dessus la zone "[ ]" rendue invisible.
final class CheckboxLayoutManager: NSLayoutManager {
    var accent: NSColor = .systemBlue

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage, let container = textContainers.first else { return }
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        storage.enumerateAttribute(.checkboxBox, in: charRange) { value, range, _ in
            guard let checked = (value as? NSNumber)?.boolValue else { return }
            let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rect = boundingRect(forGlyphRange: glyphRange, in: container)
            rect.origin.x += origin.x
            rect.origin.y += origin.y
            drawCheckbox(checked: checked, in: rect)
        }
    }

    private func drawCheckbox(checked: Bool, in rect: CGRect) {
        let size = min(rect.height - 1, 15)
        let color = checked ? accent : NSColor.black.withAlphaComponent(0.5)
        let conf = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            .applying(.init(paletteColors: [color]))
        let name = checked ? "checkmark.square.fill" : "square"
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(conf) else { return }
        img.draw(in: CGRect(x: rect.minX, y: rect.midY - size / 2, width: size, height: size))
    }
}

/// Éditeur markdown "live" : on édite le texte brut, mais le style s'applique en direct
/// (titres, gras, italique, cases à cocher, liens, code). Pas de mode rendu séparé.
struct MarkdownTextView: NSViewRepresentable {
    @ObservedObject var vm: PostItViewModel
    var onOpenNote: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(vm: vm, onOpenNote: onOpenNote) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        // Stack TextKit 1 explicite pour utiliser notre layout manager custom.
        let storage = NSTextStorage()
        let layout = CheckboxLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)

        let tv = MarkdownNSTextView(frame: .zero, textContainer: container)
        tv.coordinator = context.coordinator
        tv.delegate = context.coordinator
        tv.allowsUndo = true
        tv.isRichText = true
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.textColor = Style.text
        tv.insertionPointColor = NSColor.black.withAlphaComponent(0.75)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.smartInsertDeleteEnabled = false
        tv.textContainerInset = NSSize(width: 8, height: 10)
        tv.font = Style.base
        tv.typingAttributes = Style.baseAttributes

        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true

        tv.string = vm.rawText
        context.coordinator.textView = tv
        context.coordinator.accent = NSColor(StickyColor.accent(vm.colorName))
        context.coordinator.highlight()

        scroll.documentView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        context.coordinator.accent = NSColor(StickyColor.accent(vm.colorName))
        context.coordinator.onOpenNote = onOpenNote
        // Mise à jour externe (Obsidian / iCloud) : on ne pousse que si l'utilisateur n'édite pas.
        if vm.rawText != tv.string && !context.coordinator.isFocused {
            tv.string = vm.rawText
            context.coordinator.highlight()
        }
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let vm: PostItViewModel
        var onOpenNote: (String) -> Void
        weak var textView: NSTextView?
        var accent: NSColor = .systemBlue
        var isFocused = false

        init(vm: PostItViewModel, onOpenNote: @escaping (String) -> Void) {
            self.vm = vm
            self.onOpenNote = onOpenNote
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            vm.onEditorChanged(tv.string)
            highlight()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            // Re-rend pour révéler/masquer le markdown de la ligne active.
            highlight()
        }

        func setFocused(_ f: Bool) {
            isFocused = f
            vm.isEditorFocused = f
            if !f { vm.flushSave() }
            highlight()
        }

        func highlight() {
            guard let tv = textView else { return }
            // Ligne active = celle du curseur, seulement si l'éditeur a le focus.
            var activeLine = NSRange(location: NSNotFound, length: 0)
            if isFocused, let storage = tv.textStorage {
                let sel = tv.selectedRange
                let ns = storage.string as NSString
                let probe = min(sel.location, max(ns.length - 1, 0))
                if ns.length > 0 {
                    activeLine = ns.lineRange(for: NSRange(location: probe, length: 0))
                }
            }
            (tv.layoutManager as? CheckboxLayoutManager)?.accent = accent
            Highlighter.apply(to: tv, accent: accent, activeLine: activeLine)
            tv.needsDisplay = true
        }

        /// Gère ⌘+clic (ouvre lien) et clic sur une case à cocher (toggle).
        func handleMouseDown(_ event: NSEvent, in tv: NSTextView) -> Bool {
            guard let storage = tv.textStorage, storage.length > 0 else { return false }
            let point = tv.convert(event.locationInWindow, from: nil)
            let idx = tv.characterIndexForInsertion(at: point)
            let ns = storage.string as NSString

            // ⌘+clic sur un lien / wikilink
            if event.modifierFlags.contains(.command) {
                let probe = min(idx, storage.length - 1)
                if probe >= 0, let target = storage.attribute(.mdTarget, at: probe, effectiveRange: nil) as? String {
                    if target.hasPrefix("http") || target.hasPrefix("mailto:") {
                        if let url = URL(string: target) { NSWorkspace.shared.open(url) }
                    } else {
                        onOpenNote(target)
                    }
                    return true
                }
                return false
            }

            // Clic sur une case à cocher → toggle
            let safe = min(max(idx, 0), max(ns.length - 1, 0))
            let lineRange = ns.lineRange(for: NSRange(location: safe, length: 0))
            let line = ns.substring(with: lineRange) as NSString
            let openR = line.range(of: "[")
            let closeR = line.range(of: "]")
            if openR.location != NSNotFound, closeR.location == openR.location + 2 {
                let markStart = lineRange.location + openR.location
                if idx >= markStart && idx <= markStart + 3 {
                    let charRange = NSRange(location: markStart + 1, length: 1)
                    let cur = (storage.string as NSString).substring(with: charRange)
                    if cur == " " || cur == "x" || cur == "X" {
                        let new = (cur == " ") ? "x" : " "
                        if tv.shouldChangeText(in: charRange, replacementString: new) {
                            storage.replaceCharacters(in: charRange, with: new)
                            tv.didChangeText()
                        }
                        return true
                    }
                }
            }
            return false
        }
    }
}

/// NSTextView qui délègue focus et clics au coordinator.
final class MarkdownNSTextView: NSTextView {
    weak var coordinator: MarkdownTextView.Coordinator?

    override func becomeFirstResponder() -> Bool {
        coordinator?.setFocused(true)
        return super.becomeFirstResponder()
    }
    override func resignFirstResponder() -> Bool {
        coordinator?.setFocused(false)
        return super.resignFirstResponder()
    }
    override func mouseDown(with event: NSEvent) {
        if coordinator?.handleMouseDown(event, in: self) == true { return }
        super.mouseDown(with: event)
    }
}
