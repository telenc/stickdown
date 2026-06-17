import SwiftUI

/// Palette des post-it, alignée sur les couleurs du frontmatter colorful-sticky-bg.
enum StickyColor {
    static func background(_ name: String?) -> Color {
        switch (name ?? "yellow").lowercased() {
        case "yellow":  return Color(red: 0.99, green: 0.94, blue: 0.66)
        case "green":   return Color(red: 0.80, green: 0.93, blue: 0.74)
        case "blue":    return Color(red: 0.74, green: 0.86, blue: 0.97)
        case "pink":    return Color(red: 0.98, green: 0.78, blue: 0.86)
        case "purple":  return Color(red: 0.86, green: 0.78, blue: 0.96)
        case "orange":  return Color(red: 0.99, green: 0.83, blue: 0.62)
        case "red":     return Color(red: 0.98, green: 0.72, blue: 0.69)
        case "gray", "grey": return Color(red: 0.88, green: 0.88, blue: 0.90)
        default:        return Color(red: 0.99, green: 0.94, blue: 0.66)
        }
    }

    /// Couleur d'accent (titres, barre d'entête) plus sombre que le fond.
    static func accent(_ name: String?) -> Color {
        background(name).opacity(1.0).mix(with: .black, by: 0.35)
    }

    static let all = ["yellow", "green", "blue", "pink", "purple", "orange", "red", "gray"]
}

extension Color {
    /// Mélange simple deux couleurs (fallback maison, sans dépendre d'iOS 18+).
    func mix(with other: Color, by amount: Double) -> Color {
        let a = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let b = NSColor(other).usingColorSpace(.sRGB) ?? .black
        let t = max(0, min(1, amount))
        return Color(
            red: Double(a.redComponent) * (1 - t) + Double(b.redComponent) * t,
            green: Double(a.greenComponent) * (1 - t) + Double(b.greenComponent) * t,
            blue: Double(a.blueComponent) * (1 - t) + Double(b.blueComponent) * t
        )
    }
}
