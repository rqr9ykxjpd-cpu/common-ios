#!/usr/bin/env swift
import AppKit

/// Ham simülatör karesini App Store 6.9" (1320×2868) pazarlama karesine çevirir.
/// Şeffaflık yok — Connect alpha kabul etmiyor.
///
/// Tasarım: renkli degrade zemin + büyük iki satırlı başlık (ikinci satır vurgu
/// rengi) + alt yazı + üç kapsül + hafif eğik, gölgeli, altı taşan telefon.
let canvasW: CGFloat = 1320
let canvasH: CGFloat = 2868

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
}
let ink = hex(0x1D1D1F)
let paper = hex(0xFFFFFF)
let muted = hex(0x5C5C63)
let burnt = hex(0xC45A18)
let violet = hex(0x6B5BE6)
let teal = hex(0x0E7C7B)

struct Slide {
    let file: String
    let titleTop: String
    let titleAccent: String
    let subtitle: String
    let pills: [String]
    let bgTop: NSColor
    let bgBottom: NSColor
    let text: NSColor       // başlık + marka
    let accent: NSColor     // ikinci satır
    let light: Bool         // açık zemin: kapsüller ve gölge buna göre
    let tilt: CGFloat       // derece
}

let slides: [Slide] = [
    .init(file: "01-feed", titleTop: "Kampüsün", titleAccent: "hali.",
          subtitle: "Soru sor, ders notu paylaş, çalışma grubu kur.",
          pills: ["Soru", "Ders notu", "Çalışma grubu"],
          bgTop: hex(0xD9661F), bgBottom: hex(0x9A4210), text: paper, accent: hex(0xFFE0C2), light: false, tilt: -3),
    .init(file: "04-places", titleTop: "Kim", titleAccent: "nerede?",
          subtitle: "Kampüs noktasını seç, orada kim var gör.",
          pills: ["Kütüphane", "Kantin", "Kulüpler"],
          bgTop: hex(0x128A88), bgBottom: hex(0x0A5453), text: paper, accent: hex(0xBFF1EC), light: false, tilt: 3),
    .init(file: "03-story", titleTop: "Kampüs", titleAccent: "anı.",
          subtitle: "10 saatlik fotoğraf ve video; yanıtla, tanış.",
          pills: ["10 saat", "Fotoğraf", "Video"],
          bgTop: hex(0x2C2C31), bgBottom: hex(0x0B0B0D), text: paper, accent: hex(0xF08A45), light: false, tilt: -3),
    .init(file: "05-chats", titleTop: "Kampüste", titleAccent: "yazış.",
          subtitle: "Bağlantı kur, buluşma iste, sohbeti aç.",
          pills: ["Bağlantı", "Buluşma", "Mesaj"],
          bgTop: hex(0x7566EE), bgBottom: hex(0x4536B5), text: paper, accent: hex(0xDDD8FF), light: false, tilt: 3),
    .init(file: "02-clubs", titleTop: "Kulübünü", titleAccent: "bul.",
          subtitle: "Kampüsteki topluluklara tek dokunuşla katıl.",
          pills: ["Etkinlik", "Üyeler", "Katıl"],
          bgTop: hex(0xF6EFE6), bgBottom: hex(0xFFFFFF), text: ink, accent: violet, light: true, tilt: -3),
    .init(file: "07-paywall", titleTop: "Sınırları", titleAccent: "kaldır.",
          subtitle: "Plus ve Pro: daha fazla bağlantı, buluşma ve gönderi.",
          pills: ["Plus", "Pro", "Haftalık"],
          bgTop: hex(0x2C2C31), bgBottom: hex(0x0B0B0D), text: paper, accent: hex(0xF08A45), light: false, tilt: 3),
]

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let rawDir = root.appendingPathComponent("store/screenshots/raw")
let outDir = root.appendingPathComponent("store/screenshots/69")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func font(_ size: CGFloat, weight: NSFont.Weight, serif: Bool = false) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    guard serif, let d = base.fontDescriptor.withDesign(.serif) else { return base }
    return NSFont(descriptor: d, size: size) ?? base
}

@discardableResult
func drawText(_ string: String, font: NSFont, color: NSColor, in rect: CGRect,
              tracking: CGFloat = 0, lineHeight: CGFloat = 1.0, align: NSTextAlignment = .left) -> CGRect {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.minimumLineHeight = font.pointSize * lineHeight
    paragraph.maximumLineHeight = font.pointSize * lineHeight
    var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    if tracking != 0 { attrs[.kern] = tracking }
    let ns = string as NSString
    let bounds = ns.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                 options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
    ns.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
    return CGRect(x: rect.minX, y: rect.minY, width: bounds.width, height: bounds.height)
}

for slide in slides {
    let sourceURL = rawDir.appendingPathComponent("\(slide.file).png")
    guard let screenshot = NSImage(contentsOf: sourceURL) else {
        fputs("eksik: \(sourceURL.path)\n", stderr)
        continue
    }

    let composed = NSImage(size: NSSize(width: canvasW, height: canvasH), flipped: true) { _ in
        // Zemin: doygun marka rengi, aşağı doğru koyulaşır.
        NSGradient(starting: slide.bgTop, ending: slide.bgBottom)?
            .draw(in: NSRect(x: 0, y: 0, width: canvasW, height: canvasH), angle: -90)

        // Telefonun arkasında ışık: metinle telefonu ayırır, derinlik verir.
        let glowColor = slide.light ? slide.accent.withAlphaComponent(0.28) : paper.withAlphaComponent(0.22)
        NSGradient(colors: [glowColor, glowColor.withAlphaComponent(0)])?
            .draw(in: NSBezierPath(ovalIn: NSRect(x: -300, y: 900, width: 1920, height: 1920)),
                  relativeCenterPosition: .zero)
        // Sağ üstte ikinci, küçük bir ışık — düz zemin hissini kırar.
        let spark = slide.light ? hex(0xC45A18, 0.16) : slide.accent.withAlphaComponent(0.35)
        NSGradient(colors: [spark, spark.withAlphaComponent(0)])?
            .draw(in: NSBezierPath(ovalIn: NSRect(x: 700, y: -500, width: 1300, height: 1300)),
                  relativeCenterPosition: .zero)

        let titleColor = slide.text
        let subColor = slide.light ? muted : paper.withAlphaComponent(0.82)

        // Marka: uygulamadaki serif "common".
        drawText("common", font: font(64, weight: .semibold, serif: true), color: titleColor,
                 in: CGRect(x: 96, y: 112, width: 600, height: 90), tracking: -1)

        // Başlık: iki satır, ikincisi vurgu renginde.
        let titleFont = font(150, weight: .heavy)
        drawText(slide.titleTop, font: titleFont, color: titleColor,
                 in: CGRect(x: 90, y: 250, width: canvasW - 160, height: 180), tracking: -5, lineHeight: 1.0)
        drawText(slide.titleAccent, font: titleFont, color: slide.accent,
                 in: CGRect(x: 90, y: 400, width: canvasW - 160, height: 180), tracking: -5, lineHeight: 1.0)

        let subRect = drawText(slide.subtitle, font: font(50, weight: .medium), color: subColor,
                               in: CGRect(x: 96, y: 610, width: canvasW - 192, height: 140), tracking: -0.5, lineHeight: 1.18)

        // Kapsüller.
        var px: CGFloat = 96
        let py = subRect.maxY + 44
        let pillFont = font(36, weight: .semibold)
        for pill in slide.pills {
            let w = (pill as NSString).size(withAttributes: [.font: pillFont]).width + 64
            let r = NSRect(x: px, y: py, width: w, height: 80)
            (slide.light ? paper : paper.withAlphaComponent(0.16)).setFill()
            let path = NSBezierPath(roundedRect: r, xRadius: 40, yRadius: 40)
            path.fill()
            (slide.light ? ink.withAlphaComponent(0.12) : paper.withAlphaComponent(0.35)).setStroke()
            path.lineWidth = 2
            path.stroke()
            drawText(pill, font: pillFont, color: slide.light ? ink : paper,
                     in: CGRect(x: r.minX, y: r.minY + 19, width: r.width, height: 44), align: .center)
            px += w + 18
        }

        // Telefon: büyük, hafif eğik, altı taşan.
        let deviceW: CGFloat = 1150
        let bezel: CGFloat = 16
        let outerR: CGFloat = 96
        let screenR: CGFloat = 80
        let shot = screenshot.size
        let screenW = deviceW - bezel * 2
        let screenH = screenW * (shot.height / max(shot.width, 1))
        let deviceH = screenH + bezel * 2
        let deviceX = (canvasW - deviceW) / 2
        let deviceY: CGFloat = 1010
        let deviceRect = NSRect(x: deviceX, y: deviceY, width: deviceW, height: deviceH)
        let screenRect = deviceRect.insetBy(dx: bezel, dy: bezel)

        let ctx = NSGraphicsContext.current!.cgContext
        ctx.saveGState()
        let cx = deviceRect.midX, cy = deviceRect.midY
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: slide.tilt * .pi / 180)
        ctx.translateBy(x: -cx, y: -cy)

        let frameColor = slide.light ? ink : hex(0x2A2A2E)
        ctx.setShadow(offset: CGSize(width: 0, height: 34), blur: 100,
                      color: NSColor.black.withAlphaComponent(slide.light ? 0.28 : 0.55).cgColor)
        frameColor.setFill()
        NSBezierPath(roundedRect: deviceRect, xRadius: outerR, yRadius: outerR).fill()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        frameColor.setFill()
        NSBezierPath(roundedRect: deviceRect, xRadius: outerR, yRadius: outerR).fill()
        // İnce açık kenar: çerçeve koyu zeminde erimesin.
        paper.withAlphaComponent(slide.light ? 0.0 : 0.22).setStroke()
        let edge = NSBezierPath(roundedRect: deviceRect.insetBy(dx: 1.5, dy: 1.5), xRadius: outerR - 1.5, yRadius: outerR - 1.5)
        edge.lineWidth = 3
        edge.stroke()

        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(roundedRect: screenRect, xRadius: screenR, yRadius: screenR).addClip()
        screenshot.draw(in: screenRect, from: .zero, operation: .copy, fraction: 1,
                        respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        NSGraphicsContext.current?.restoreGraphicsState()
        ctx.restoreGState()
        return true
    }

    guard let cg = composed.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fputs("raster yok: \(slide.file)\n", stderr)
        continue
    }
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: Int(canvasW), height: Int(canvasH), bitsPerComponent: 8,
                              bytesPerRow: 0, space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("context") }
    ctx.interpolationQuality = .high
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: canvasW, height: canvasH))
    guard let opaque = ctx.makeImage() else { fatalError("opaque") }
    let dest = outDir.appendingPathComponent("\(slide.file).png")
    guard let destRef = CGImageDestinationCreateWithURL(dest as CFURL, "public.png" as CFString, 1, nil) else { fatalError("dest") }
    CGImageDestinationAddImage(destRef, opaque, nil)
    CGImageDestinationFinalize(destRef)
    print("yazıldı \(dest.path)")
}
