import AppKit
import Foundation

// Génère packaging/AppIcon-1024.png : un post-it jaune avec une checklist.
let S: CGFloat = 1024
let image = NSImage(size: NSSize(width: S, height: S))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

// Carte (post-it)
let pad: CGFloat = 96
let card = NSRect(x: pad, y: pad, width: S - 2 * pad, height: S - 2 * pad)
let radius: CGFloat = 190
let cardPath = NSBezierPath(roundedRect: card, xRadius: radius, yRadius: radius)

// Ombre portée douce
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 44,
              color: NSColor.black.withAlphaComponent(0.22).cgColor)
NSColor(srgbRed: 0.99, green: 0.85, blue: 0.34, alpha: 1).setFill()
cardPath.fill()
ctx.restoreGState()

// Dégradé jaune
ctx.saveGState()
cardPath.addClip()
let grad = NSGradient(colors: [
    NSColor(srgbRed: 1.0, green: 0.92, blue: 0.50, alpha: 1),
    NSColor(srgbRed: 0.99, green: 0.80, blue: 0.28, alpha: 1)
])!
grad.draw(in: card, angle: -90)
ctx.restoreGState()

// Checklist : 3 lignes (case + trait)
let ink = NSColor.black.withAlphaComponent(0.58)
let green = NSColor(srgbRed: 0.20, green: 0.62, blue: 0.34, alpha: 1)

let boxSize: CGFloat = 118
let lineH: CGFloat = 60
let leftX = card.minX + 130
let lineX = leftX + boxSize + 70
let lineW = card.maxX - lineX - 130
let rowGap: CGFloat = 96
let startY = card.maxY - 230

for i in 0..<3 {
    let y = startY - CGFloat(i) * (boxSize + rowGap)
    let boxRect = NSRect(x: leftX, y: y - boxSize, width: boxSize, height: boxSize)
    let box = NSBezierPath(roundedRect: boxRect, xRadius: 28, yRadius: 28)

    if i == 0 {
        green.setFill(); box.fill()
        // coche
        let check = NSBezierPath()
        check.move(to: NSPoint(x: boxRect.minX + 26, y: boxRect.midY - 4))
        check.line(to: NSPoint(x: boxRect.midX - 6, y: boxRect.minY + 30))
        check.line(to: NSPoint(x: boxRect.maxX - 22, y: boxRect.maxY - 30))
        check.lineWidth = 22
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        NSColor.white.setStroke(); check.stroke()
    } else {
        ink.setStroke(); box.lineWidth = 16; box.stroke()
    }

    let lineRect = NSRect(x: lineX, y: y - boxSize / 2 - lineH / 2,
                          width: i == 2 ? lineW * 0.62 : lineW, height: lineH)
    let line = NSBezierPath(roundedRect: lineRect, xRadius: lineH / 2, yRadius: lineH / 2)
    (i == 0 ? ink.withAlphaComponent(0.32) : ink).setFill()
    line.fill()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
let out = URL(fileURLWithPath: "packaging/AppIcon-1024.png")
try? png.write(to: out)
print("Wrote \(out.path)")
