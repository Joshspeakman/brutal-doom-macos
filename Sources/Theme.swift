import AppKit

let gold = NSColor(srgbRed: 0.86, green: 0.77, blue: 0.55, alpha: 1)
let parchment = NSColor(srgbRed: 0.94, green: 0.91, blue: 0.84, alpha: 1)
let muted = NSColor(srgbRed: 0.68, green: 0.64, blue: 0.55, alpha: 1)
func copper(_ size: CGFloat, bold: Bool = false) -> NSFont {
    NSFont(name: bold ? "Copperplate-Bold" : "Copperplate-Light", size: size) ?? .systemFont(ofSize: size, weight: bold ? .bold : .regular)
}
func label(_ text: String, _ rect: NSRect, size: CGFloat = 14, color: NSColor = parchment, bold: Bool = false, align: NSTextAlignment = .left) -> NSTextField {
    let field = NSTextField(wrappingLabelWithString: text)
    field.frame = rect; field.font = copper(size, bold: bold); field.textColor = color
    field.alignment = align; field.maximumNumberOfLines = 0
    return field
}
final class FlippedView: NSView { override var isFlipped: Bool { true } }
final class MetalButton: NSButton {
    var primary = false
    var hovering = false
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        let lift: CGFloat = isHighlighted ? -0.06 : hovering ? 0.06 : 0
        let r = bounds.insetBy(dx: 1.5, dy: 1.5)
        let edge = NSBezierPath(roundedRect: r, xRadius: 3, yRadius: 3)
        NSGradient(starting: NSColor(white: 0.29 + lift, alpha: 1), ending: NSColor(white: 0.11 + lift, alpha: 1))!.draw(in: edge, angle: 90)
        NSColor(srgbRed: 0.61, green: 0.49, blue: 0.29, alpha: 1).setStroke(); edge.lineWidth = 1.5; edge.stroke()
        NSColor(white: 0.04, alpha: 1).setStroke()
        NSBezierPath(roundedRect: r.insetBy(dx: 3, dy: 3), xRadius: 2, yRadius: 2).stroke()
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black; shadow.shadowOffset = NSSize(width: 0, height: -1); shadow.shadowBlurRadius = 2
        let font = copper(primary ? 23 : 18, bold: true)
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: isEnabled ? (primary ? gold : parchment) : muted, .shadow: shadow, .paragraphStyle: paragraph]
        let h = font.ascender - font.descender + 2
        (title as NSString).draw(in: NSRect(x: 6, y: (bounds.height - h) / 2, width: bounds.width - 12, height: h + 4), withAttributes: attrs)
        if window?.firstResponder === self {
            gold.withAlphaComponent(0.8).setStroke()
            NSBezierPath(roundedRect: r.insetBy(dx: -1, dy: -1), xRadius: 4, yRadius: 4).stroke()
        }
    }
}
final class Panel: NSView {
    var framed = true
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(srgbRed: 0.055, green: 0.045, blue: 0.035, alpha: framed ? 1 : 0.87).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4).fill()
        if framed {
            for (inset, width, shade) in [(2.0, 5.0, 0.12), (3.0, 2.0, 0.48), (6.0, 1.0, 0.10)] {
                let p = NSBezierPath(rect: bounds.insetBy(dx: inset, dy: inset)); p.lineWidth = width
                NSColor(white: shade, alpha: 1).setStroke(); p.stroke()
            }
            for x in [10.0, bounds.width - 10] { for y in [10.0, bounds.height - 10] {
                let p = NSBezierPath(ovalIn: NSRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7))
                NSGradient(starting: gold, ending: NSColor(srgbRed: 0.36, green: 0.23, blue: 0.09, alpha: 1))!.draw(in: p, angle: 80)
            }}
        } else {
            gold.withAlphaComponent(0.6).setStroke()
            let p = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4); p.lineWidth = 1.5; p.stroke()
        }
    }
}
final class Backdrop: NSView {
    let assets: URL
    var gameID = "doom2" { didSet { needsDisplay = true } }
    var images: [String: NSImage] = [:]
    init(frame: NSRect, assets: URL) { self.assets = assets; super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isFlipped: Bool { true }
    func art(_ name: String) -> NSImage? {
        if let image = images[name] { return image }
        let image = NSImage(contentsOf: assets.appendingPathComponent(name + ".png")); images[name] = image
        return image
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0.045, alpha: 1).setFill(); bounds.fill()
        if let stone = art("stone") {
            NSGraphicsContext.current?.imageInterpolation = .none
            for x in stride(from: CGFloat(0), to: bounds.width, by: 128) { for y in stride(from: CGFloat(0), to: bounds.height, by: 128) {
                stone.draw(in: NSRect(x: x, y: y, width: 128, height: 128), from: .zero, operation: .sourceOver, fraction: 0.25, respectFlipped: true, hints: nil)
            }}
        }
        let hero = NSRect(x: 0, y: 0, width: bounds.width, height: 252)
        NSGraphicsContext.saveGraphicsState(); NSBezierPath(rect: hero).addClip()
        if let image = art(gameID == "pbmonsters" ? "doom2" : gameID) {
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(in: NSRect(x: 272, y: -26, width: 510, height: 319), from: .zero, operation: .sourceOver, fraction: 0.92, respectFlipped: true, hints: nil)
        }
        if gameID == "lambda" {
            ("λ" as NSString).draw(at: NSPoint(x: 480, y: -18), withAttributes: [.font: NSFont.systemFont(ofSize: 230, weight: .bold), .foregroundColor: NSColor.systemOrange.withAlphaComponent(0.65)])
        }
        NSGradient(colorsAndLocations: (NSColor(white: 0.025, alpha: 1), 0), (NSColor(white: 0.025, alpha: 0.93), 0.32), (NSColor(white: 0.025, alpha: 0.10), 0.72), (NSColor.clear, 1))!.draw(in: hero, angle: 0)
        NSGradient(starting: .clear, ending: NSColor(white: 0.025, alpha: 1))!.draw(in: NSRect(x: 0, y: 185, width: bounds.width, height: 67), angle: 90)
        NSGraphicsContext.restoreGraphicsState()
        let specialTitles: [String: (String, String)] = [
            "schism": ("SCHISM", "FOUR HEROES"),
            "projectbrutality": ("PROJECT", "BRUTALITY"),
            "pbmonsters": ("BRUTAL DOOM", "EXPANDED MONSTERS"),
            "aliens": ("ALIENS", "ERADICATION"),
            "lambda": ("LAMBDA", "HALF-LIFE ARSENAL")
        ]
        let family: (String, String) = specialTitles[gameID] ?? (gameID.hasPrefix("chex") ? ("BRUTAL", "CHEX QUEST") : gameID == "wolfenstein" ? ("BRUTAL", "WOLFENSTEIN") : gameID == "hexen" ? ("BRUTAL", "HEXEN RPG") : gameID == "doom64" ? ("BRUTAL", "DOOM 64") : ("BRUTAL", "DOOM"))
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black; shadow.shadowOffset = NSSize(width: 1, height: -3); shadow.shadowBlurRadius = 5
        let attributes: [NSAttributedString.Key: Any] = [.font: copper(47, bold: true), .foregroundColor: parchment, .strokeColor: NSColor(srgbRed: 0.38, green: 0.17, blue: 0.09, alpha: 1), .strokeWidth: -2, .shadow: shadow, .kern: 2]
        (family.0 as NSString).draw(at: NSPoint(x: 42, y: 51), withAttributes: attributes)
        var second = attributes; second[.font] = copper(family.1.count > 9 ? 30 : 47, bold: true)
        (family.1 as NSString).draw(at: NSPoint(x: 42, y: 105), withAttributes: second)
        ("THE BRUTAL COLLECTION" as NSString).draw(at: NSPoint(x: 46, y: 181), withAttributes: [.font: copper(14), .foregroundColor: gold, .kern: 1.1])
        gold.withAlphaComponent(0.45).setFill(); NSRect(x: 40, y: 240, width: bounds.width - 80, height: 1).fill()
    }
}
