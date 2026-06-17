import SwiftUI

struct PostItView: View {
    @ObservedObject var vm: PostItViewModel
    var onClose: () -> Void
    var onOpenNote: (String) -> Void

    @State private var hoveringHeader = false

    private var bg: Color { StickyColor.background(vm.colorName) }
    private var accent: Color { StickyColor.accent(vm.colorName) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.12)
            MarkdownTextView(vm: vm, onOpenNote: onOpenNote)
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

            Text(vm.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
                .lineLimit(1)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onHover { hoveringHeader = $0 }
    }
}
