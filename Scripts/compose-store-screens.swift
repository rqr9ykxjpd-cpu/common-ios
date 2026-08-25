#!/usr/bin/env swift
import AppKit

/// Ham simülatör karesini App Store 6.9" (1320×2868) pazarlama karesine çevirir.
/// Şeffaflık yok — Connect alpha kabul etmiyor.

let canvasW: CGFloat = 1320
let canvasH: CGFloat = 2868

let ink = NSColor(srgbRed: 0x1D / 255, green: 0x1D / 255, blue: 0x1F / 255, alpha: 1)
let paper = NSColor(srgbRed: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255, alpha: 1)
let muted = NSColor(srgbRed: 0x6E / 255, green: 0x6E / 255, blue: 0x73 / 255, alpha: 1)
let onDark = NSColor(srgbRed: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255, alpha: 1)
let bezelLight = NSColor(srgbRed: 0x1D / 255, green: 0x1D / 255, blue: 0x1F / 255, alpha: 1)
let bezelDark = NSColor(srgbRed: 0x3A / 255, green: 0x3A / 255, blue: 0x3C / 255, alpha: 1)

struct Slide {
    let file: String
    let title: String
    let subtitle: String
    let dark: Bool
}

let slides: [Slide] = [
    .init(file: "01-feed", title: "Kampüsün hali.", subtitle: "Story, gönderi, kim nerede.", dark: false),
    .init(file: "02-discover", title: "Tanış.", subtitle: "YÜ’den biriyle denk gel.", dark: true),
    .init(file: "03-story", title: "O an.", subtitle: "Fotoğraf veya 15 saniyelik video.", dark: true),
    .init(file: "04-places", title: "Kim nerede?", subtitle: "Kafede kim var, bir bak.", dark: false),
    .init(file: "05-chats", title: "Yazış.", subtitle: "Eşleşince sohbet açılır.", dark: false),
]

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let rawDir = root.appendingPathComponent("store/screenshots/raw")
let outDir = root.appendingPathComponent("store/screenshots/69")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func font(_ size: CGFloat, weight: NSFont.Weight) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}

func drawText(_ string: String, font: NSFont, color: NSColor, in rect: CGRect, tracking: CGFloat = 0) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.minimumLineHeight = font.pointSize * 1.06
    paragraph.maximumLineHeight = font.pointSize * 1.12
    var attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]
    if tracking != 0 { attrs[.kern] = tracking }
    (string as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
}

for slide in slides {
    let sourceURL = rawDir.appendingPathComponent("\(slide.file).png")
    guard let screenshot = NSImage(contentsOf: sourceURL) else {
        fputs("eksik: \(sourceURL.path)\n", stderr)
        continue
    }

    let composed = NSImage(size: NSSize(width: canvasW, height: canvasH), flipped: true) { _ in
        (slide.dark ? NSColor.black : paper).setFill()
        NSRect(x: 0, y: 0, width: canvasW, height: canvasH).fill()

        let titleColor = slide.dark ? onDark : ink
        let subColor = slide.dark ? NSColor.white.withAlphaComponent(0.55) : muted
        let markColor = slide.dark ? NSColor.white.withAlphaComponent(0.4) : muted

        drawText("COMMON", font: font(13, weight: .semibold), color: markColor,
                 in: CGRect(x: 88, y: 108, width: canvasW - 176, height: 24), tracking: 4.4)
        drawText(slide.title, font: font(68, weight: .semibold), color: titleColor,
                 in: CGRect(x: 80, y: 148, width: canvasW - 160, height: 180), tracking: -1.4)
        drawText(slide.subtitle, font: font(26, weight: .regular), color: subColor,
                 in: CGRect(x: 84, y: 340, width: canvasW - 168, height: 72))

        let deviceW: CGFloat = 1040
        let bezel: CGFloat = 16
        let outerR: CGFloat = 86
        let screenR: CGFloat = 72
        let shot = screenshot.size
        let screenW = deviceW - bezel * 2
        let screenH = screenW * (shot.height / max(shot.width, 1))
        let deviceH = screenH + bezel * 2
        let deviceX = (canvasW - deviceW) / 2
        let deviceY: CGFloat = 460
        let deviceRect = NSRect(x: deviceX, y: deviceY, width: deviceW, height: deviceH)
        let screenRect = deviceRect.insetBy(dx: bezel, dy: bezel)

        NSGraphicsContext.current?.cgContext.setShadow(
            offset: CGSize(width: 0, height: 18),
            blur: 48,
            color: NSColor.black.withAlphaComponent(slide.dark ? 0.5 : 0.16).cgColor
        )
        (slide.dark ? bezelDark : bezelLight).setFill()
        NSBezierPath(roundedRect: deviceRect, xRadius: outerR, yRadius: outerR).fill()
        NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

        (slide.dark ? bezelDark : bezelLight).setFill()
        NSBezierPath(roundedRect: deviceRect, xRadius: outerR, yRadius: outerR).fill()

        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(roundedRect: screenRect, xRadius: screenR, yRadius: screenR).addClip()
        screenshot.draw(
            in: screenRect,
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.current?.restoreGraphicsState()
        return true
    }

    guard let cg = composed.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fputs("raster yok: \(slide.file)\n", stderr)
        continue
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: Int(canvasW),
        height: Int(canvasH),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { fatalError("context") }

    ctx.interpolationQuality = .high
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: canvasW, height: canvasH))
    guard let opaque = ctx.makeImage() else { fatalError("opaque") }

    let dest = outDir.appendingPathComponent("\(slide.file).png")
    guard let destRef = CGImageDestinationCreateWithURL(dest as CFURL, "public.png" as CFString, 1, nil) else {
        fatalError("dest")
    }
    CGImageDestinationAddImage(destRef, opaque, nil)
    CGImageDestinationFinalize(destRef)
    print("yazıldı \(dest.path)")
}
