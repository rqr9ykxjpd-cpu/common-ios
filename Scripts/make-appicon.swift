// Bond uygulama ikonu üretici.
//
// Kullanım:  swift Scripts/make-appicon.swift
//
// Üç varyant üretir (açık / koyu / tinted) ve doğrudan varlık kataloğuna
// yazar. iOS 26 tek görselden koyu varyantı kendisi türetiyor ama açık
// zeminli bir ikonda sonuç kötü oluyor; açıkça vermek doğru yol.
//
// İşaret: küçük harf "b", New York (sistem yazı tipinin serif varyantı).
// Uygulamanın editoryal başlıklarıyla aynı kesim.

import AppKit
import CoreText

let boyut: CGFloat = 1024
let klasor = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Bond/Resources/Assets.xcassets/AppIcon.appiconset"

func renk(_ hex: String) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 255)/255,
                   green: CGFloat((v >> 8) & 255)/255,
                   blue: CGFloat(v & 255)/255, alpha: 1)
}

/// Harfin gerçek mürekkep sınırları. Metnin ilerleme genişliği yan boşluğu da
/// içeriyor; ona göre ortalayınca harf gözle görülür biçimde sola kayıyor.
func mürekkepKutusu(_ line: CTLine) -> CGRect {
    CTLineGetImageBounds(line, nil)
}

func üret(ad: String, zeminUst: NSColor?, zeminAlt: NSColor?, harf: NSColor) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(boyut), pixelsHigh: Int(boyut),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Tinted varyantta zemin şeffaf: iOS maskeyi kendi rengiyle dolduruyor.
    if let ust = zeminUst, let alt = zeminAlt {
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [ust.cgColor, alt.cgColor] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: boyut), end: CGPoint(x: 0, y: 0), options: [])
    }

    // Serif varyant: sistem yazı tipinin New York kesimi.
    let temel = NSFont.systemFont(ofSize: 700, weight: .bold)
    let font = temel.fontDescriptor.withDesign(.serif)
        .map { NSFont(descriptor: $0, size: 700) ?? temel } ?? temel

    let attr = NSAttributedString(string: "b", attributes: [.font: font, .foregroundColor: harf])
    let line = CTLineCreateWithAttributedString(attr)
    let kutu = mürekkepKutusu(line)

    // Harf tuvalin ~%58'ini kaplasın; kenarlarda cömert boşluk (Apple ızgarası).
    let hedef = boyut * 0.58
    let olcek = hedef / max(kutu.width, kutu.height)

    ctx.saveGState()
    ctx.translateBy(x: boyut/2, y: boyut/2)
    ctx.scaleBy(x: olcek, y: olcek)
    ctx.translateBy(x: -kutu.midX, y: -kutu.midY)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    let url = URL(fileURLWithPath: "\(klasor)/\(ad).png")
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("  \(ad).png")
}

üret(ad: "AppIcon-1024",        zeminUst: renk("FFFFFF"), zeminAlt: renk("F0F0F2"), harf: renk("1D1D1F"))
üret(ad: "AppIcon-1024-dark",   zeminUst: renk("1C1C1E"), zeminAlt: renk("000000"), harf: renk("F5F5F7"))
üret(ad: "AppIcon-1024-tinted", zeminUst: nil,            zeminAlt: nil,            harf: renk("FFFFFF"))
