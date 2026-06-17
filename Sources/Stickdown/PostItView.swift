import SwiftUI

struct PostItView: View {
    @ObservedObject var vm: PostItViewModel
    var onClose: () -> Void
    var onOpenNote: (String) -> Void

    @State private var hoveringHeader = false
    @State private var showOpacity = false

    private var bg: Color { StickyColor.background(vm.colorName) }
    private var accent: Color { StickyColor.accent(vm.colorName) }

    var body: some View {
        VStack(spacing: 0) {
            header
            if !vm.collapsed {
                Divider().opacity(0.12)
                MarkdownTextView(vm: vm, onOpenNote: onOpenNote)
            }
        }
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.black.opacity(hoveringHeader ? 0.45 : 0.2))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("w", modifiers: .command)
            .help("Fermer (⌘W)")

            Button { vm.collapsed.toggle() } label: {
                Image(systemName: vm.collapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black.opacity(hoveringHeader ? 0.5 : 0.28))
            }
            .buttonStyle(.plain)
            .help(vm.collapsed ? "Déplier" : "Replier en barre de titre")

            Text(vm.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button { vm.pinned.toggle() } label: {
                Image(systemName: vm.pinned ? "pin.fill" : "pin")
                    .font(.system(size: 11))
                    .foregroundStyle(accent.opacity(vm.pinned ? 0.9 : (hoveringHeader ? 0.8 : 0.45)))
            }
            .buttonStyle(.plain)
            .help(vm.pinned ? "Désépingler (ne plus rester au-dessus)" : "Épingler au-dessus de tout")

            opacityButton
            colorMenu
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onHover { hoveringHeader = $0 }
        // Double-clic sur l'entête → replie / déplie en barre de titre.
        .onTapGesture(count: 2) { vm.collapsed.toggle() }
    }

    private var opacityButton: some View {
        Button { showOpacity.toggle() } label: {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 12))
                .foregroundStyle(accent.opacity(hoveringHeader ? 0.85 : 0.5))
        }
        .buttonStyle(.plain)
        .help("Opacité")
        .popover(isPresented: $showOpacity, arrowEdge: .bottom) {
            HStack(spacing: 8) {
                Image(systemName: "circle.dotted").font(.system(size: 11))
                Slider(value: $vm.opacity, in: 0.4...1.0)
                Image(systemName: "circle.fill").font(.system(size: 11))
            }
            .frame(width: 180)
            .padding(12)
        }
    }

    private var colorMenu: some View {
        Menu {
            ForEach(StickyColor.all, id: \.self) { name in
                Button {
                    vm.setColor(name)
                } label: {
                    Label(name.capitalized, systemImage:
                            (vm.colorName ?? "yellow") == name ? "checkmark.circle.fill" : "circle.fill")
                }
            }
        } label: {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 12))
                .foregroundStyle(accent.opacity(hoveringHeader ? 0.9 : 0.55))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Couleur du post-it")
    }
}
