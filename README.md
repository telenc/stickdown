<p align="center">
  <img src="docs/icon.png" width="140" alt="Stickdown icon">
</p>

<h1 align="center">Stickdown</h1>

**Floating sticky notes for your Markdown / Obsidian vault — native macOS, live preview, always on top.**

Stickdown turns any `.md` file into a floating sticky note on your desktop. Edit it
in place with a live Markdown preview (just like Obsidian's Live Preview), tick
checkboxes, and `⌘`-click `[[wikilinks]]` to pop open linked notes as new stickies.
Everything you type is saved straight back to the original `.md` file, so it stays
perfectly in sync with Obsidian.

> Native AppKit + SwiftUI. No Electron. Fast and light.

---

## ✨ Features

- 🪟 **Floating panels** — borderless, rounded, always-on-top sticky notes that stay
  visible across Spaces, even when Obsidian is closed.
- ✍️ **Live Markdown editing** — type directly in the note; headings, **bold**,
  _italic_, `code`, checkboxes and links are styled as you write. The raw Markdown
  is revealed only on the line your cursor is on (Obsidian-style).
- ☑️ **Real checkboxes** — `- [ ]` renders as a clickable checkbox; click to toggle,
  checked items get struck through. Saved instantly to the file.
- 🔗 **Wikilinks** — `[[Note]]` renders without the brackets; `⌘`-click opens it as a
  new sticky. Linking to a note that doesn't exist yet **creates the file**.
- 🎨 **Per-note color** — pick from a palette in the header; written to the
  `colorful-sticky-bg` frontmatter key (`yellow`, `green`, `blue`, `pink`,
  `purple`, `orange`, `red`, `gray`).
- ⏎ **List auto-continuation** — pressing Enter on a checkbox/bullet line starts the
  next item; an empty item exits the list.
- 📌 **Pin / unpin** — toggle always-on-top per note (unpinned notes drop behind when
  you click another window).
- 🫥 **Adjustable opacity** & 🔼 **roll-up** — make a note translucent, or collapse it
  to just its title bar (chevron or double-click the header).
- 🔠 **Per-note text zoom** — `⌘+` / `⌘-` / `⌘0`.
- 🔎 **Quick-search palette** — `⌘O`, or the global hotkey **⌃⌥N** from anywhere, to
  fuzzy-find/open a note or create a new one.
- 🙈 **Clean chrome** — frontmatter and the redundant top-level title are hidden in
  the note body (the title shows in the sticky's header bar).
- 🔄 **Two-way sync** — external edits (Obsidian, iCloud) update the sticky live.
- 🧷 **Sticky sessions** — open notes, positions, sizes, colors and pin/zoom state are
  remembered across launches. Optional **launch at login**.

## 🖼️ Screenshots

![Stickdown — three linked notes on the desktop](docs/screenshot.png)

## 🚀 Install / Build

Requirements: macOS 14+, Xcode 16 (Swift 6.1) command-line tools.

```bash
git clone <your-fork-url> stickdown
cd stickdown

# (optional) generate the app icon
bash packaging/make-icon.sh

# build the double-clickable app bundle
bash package.sh

# then move it to /Applications and launch it
open Stickdown.app
```

On first launch, Stickdown asks you to pick your **vault** (your Obsidian folder, or
any folder containing `.md` files). Use the menu-bar 📝 icon to open notes, create a
new one, or change the vault.

### Run from source (dev)

```bash
swift run -c release
```

## 🕹️ Usage

| Action | How |
|--------|-----|
| Quick search / open | `⌘O`, or global hotkey `⌃⌥N` |
| Open a note | Menu-bar 📝 → pick a note |
| New note | `⌘N`, menu-bar 📝 → **New note…**, or `⌘`-click a non-existing `[[link]]` |
| Edit | Just click and type on a note |
| Toggle a checkbox | Click the checkbox |
| Follow a link | `⌘`-click the link / wikilink |
| Continue a list | Press Enter on a checkbox/bullet line |
| Change color | Palette button in the header |
| Pin / unpin (always on top) | Pin button in the header |
| Opacity | Opacity button in the header |
| Roll up / down | Chevron in the header, or double-click the header |
| Zoom text | `⌘+` / `⌘-` / `⌘0` |
| Move / resize | Drag the note / drag its edges |
| Close a note | × in the header (or `⌘W`) |
| Launch at login | Menu-bar 📝 → **Launch at login** |

## 🧱 How it works

- A small **AppKit** app (`LSUIElement`, menu-bar only) manages one floating
  `NSPanel` per open note.
- Each note is rendered by a custom `NSTextView` (TextKit 1) whose `NSTextStorage`
  **is** the raw Markdown. A `Highlighter` re-applies styling on every keystroke and
  hides syntax markers off the active line.
- A custom `NSLayoutManager` draws the real checkbox glyphs over the hidden `[ ]`.
- A `DispatchSource` file watcher keeps the note in sync with on-disk changes.

```
Sources/Stickdown/
├── main.swift                  # bootstrap (accessory app)
├── AppDelegate.swift           # menu bar, vault, window management, hotkey
├── Vault.swift                 # find / resolve / create .md notes
├── PostItWindowController.swift # floating NSPanel + geometry / collapse / opacity
├── PostItView.swift            # SwiftUI header (color/pin/opacity/collapse) + editor host
├── PostItViewModel.swift       # note state, save, file sync, per-note settings
├── MarkdownTextView.swift      # live editor (NSTextView) + checkbox layout manager
├── Highlighter.swift           # live Markdown styling / marker hiding / zoom
├── Markdown.swift              # frontmatter + checkbox parsing helpers
├── StickyColor.swift           # color palette
├── FileWatcher.swift           # on-disk change watcher
├── SearchPalette.swift         # quick-search / quick-create palette
└── GlobalHotKey.swift          # Carbon global hotkey
```

## 🗺️ Roadmap ideas

- Unresolved links shown in a distinct color
- Inline images, tables, nested lists
- Settings window (default color, opacity, customizable hotkey)
- Notarized release with a downloadable `.app`

## 📄 License

[MIT](./LICENSE) — Stickdown authors. Contributions welcome!
