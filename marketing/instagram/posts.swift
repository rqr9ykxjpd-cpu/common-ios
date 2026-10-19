// Instagram postları. CoreText ile dizilir: uygulamadaki .serif (New York) fontu,
// gerçek kerning ve optik boyutla. Çalıştır: swift posts.swift
import AppKit
import CoreText

let W: CGFloat = 1080, H: CGFloat = 1350, scale: CGFloat = 2
let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let repo = dir.deletingLastPathComponent().deletingLastPathComponent()

let paper = CGColor(srgbRed: 251/255, green: 249/255, blue: 247/255, alpha: 1) // ikon zemini
let ink = CGColor(srgbRed: 29/255, green: 29/255, blue: 31/255, alpha: 1)      // BondTheme.ink

func cgImage(_ url: URL) -> CGImage {
    NSImage(contentsOf: url)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}
let markImage = cgImage(dir.appendingPathComponent("mark-ink.png"))

func serif(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let d = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.serif)!
    return NSFont(descriptor: d, size: size)!
}

func line(_ s: String, _ font: NSFont, tracking: CGFloat) -> CTLine {
    CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [
        .font: font, .foregroundColor: NSColor(cgColor: ink)!, .kern: tracking,
    ]))
}

func width(_ l: CTLine, tracking: CGFloat) -> CGFloat {
    CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil)) - tracking
}

final class Canvas {
    let ctx: CGContext
    init() {
        ctx = CGContext(data: nil, width: Int(W * scale), height: Int(H * scale), bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: scale, y: scale)
        ctx.interpolationQuality = .high
        ctx.setFillColor(paper)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    }

    func draw(_ l: CTLine, x: CGFloat, baselineFromTop y: CGFloat) {
        ctx.textPosition = CGPoint(x: x, y: H - y)
        CTLineDraw(l, ctx)
    }

    /// Ortalanmış satır; sondaki noktalama kenara asılır, ortalamaya katılmaz.
    func centered(_ s: String, _ font: NSFont, tracking: CGFloat, baselineFromTop y: CGFloat) {
        let body = s.hasSuffix(".") ? String(s.dropLast()) : s
        let w = width(line(body, font, tracking: tracking), tracking: tracking)
        draw(line(s, font, tracking: tracking), x: (W - w) / 2, baselineFromTop: y)
    }

    /// İşaret + "common"; uygulamadaki wordmark izlemesi (-0.6 / 23pt).
    func lockup(baselineFromTop baseline: CGFloat) {
        let font = serif(30, .bold)
        let tracking = -0.6 / 23 * font.pointSize
        let word = line("common", font, tracking: tracking)
        let markH = font.ascender * 0.98
        let markW = markH * CGFloat(markImage.width) / CGFloat(markImage.height)
        let gap: CGFloat = 10
        let x = (W - (markW + gap + width(word, tracking: tracking))) / 2
        ctx.draw(markImage, in: CGRect(x: x, y: H - baseline, width: markW, height: markH))
        draw(word, x: x + markW + gap, baselineFromTop: baseline)
    }

    /// Ekran görüntüsünü ince koyu gövdeli bir cihaza koyar; cihaz alttan taşar.
    func phone(_ url: URL, top: CGFloat) {
        let shot = cgImage(url)
        let screenW: CGFloat = 600
        let screenH = screenW * CGFloat(shot.height) / CGFloat(shot.width)
        let bezel: CGFloat = 16
        let radius = screenW * 0.135
        let screen = CGRect(x: (W - screenW) / 2, y: H - top - bezel - screenH, width: screenW, height: screenH)
        let body = screen.insetBy(dx: -bezel, dy: -bezel)

        // Gövde: tek, yumuşak ve kısa bir gölge; parıltı yok.
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 60,
                      color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.14))
        ctx.addPath(CGPath(roundedRect: body, cornerWidth: radius + bezel, cornerHeight: radius + bezel, transform: nil))
        ctx.setFillColor(ink)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: screen, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.clip()
        ctx.draw(shot, in: screen)
        ctx.restoreGState()
    }

    func save(_ name: String) {
        let out = dir.appendingPathComponent(name)
        let dest = CGImageDestinationCreateWithURL(out as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        CGImageDestinationFinalize(dest)
    }
}

let opticalCenter = H * 0.465

// 2 — "Ortak."
do {
    let c = Canvas()
    let font = serif(232, .bold)
    c.centered("Ortak.", font, tracking: 0.004 * font.pointSize,
               baselineFromTop: opticalCenter + font.capHeight / 2)
    c.lockup(baselineFromTop: H - 100)
    c.save("post-2.png")
}

// 3 — "Kampüsün ortak paydası."
do {
    let c = Canvas()
    let font = serif(124, .bold)
    let tracking = -0.004 * font.pointSize
    let leading = font.pointSize * 1.08
    let first = opticalCenter + font.capHeight / 2 - leading / 2
    c.centered("Kampüsün", font, tracking: tracking, baselineFromTop: first)
    c.centered("ortak paydası.", font, tracking: tracking, baselineFromTop: first + leading)
    c.lockup(baselineFromTop: H - 100)
    c.save("post-3.png")
}

// 4 — Ürünün kendisi: gerçek akış ekranı, alttan taşan cihaz.
do {
    let c = Canvas()
    c.lockup(baselineFromTop: 128)
    c.phone(repo.appendingPathComponent("store/screenshots/raw/01-feed.png"), top: 236)
    c.save("post-4.png")
}
