// Bond uygulama ikonu üretici.
//
// Kullanım:  swift Scripts/make-appicon.swift
//
// Onaylanan Bond sembolünden üç varyant üretir (açık / koyu / tinted)
// ve varlık kataloğuna yazar. iOS 26 tek görselden koyu varyantı
// kendisi türetiyor ama açık zeminli bir ikonda sonuç kötü oluyor.

import AppKit

let boyut = 1024
let kaynakYol = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Scripts/AppIconSource.png"
let klasor = CommandLine.arguments.count > 2
    ? CommandLine.arguments[2]
    : "Bond/Resources/Assets.xcassets/AppIcon.appiconset"

guard let kaynakGorsel = NSImage(contentsOf: URL(fileURLWithPath: kaynakYol)),
      let kaynak = kaynakGorsel.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Kaynak ikon okunamadı: \(kaynakYol)\n", stderr)
    exit(1)
}

func yeniRep() -> NSBitmapImageRep {
    NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: boyut,
        pixelsHigh: boyut,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
}

func yaz(_ ad: String, _ rep: NSBitmapImageRep) {
    let url = URL(fileURLWithPath: "\(klasor)/\(ad)")
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("  \(ad)")
}

func çizKaynak(_ ctx: CGContext) {
    ctx.interpolationQuality = .high
    ctx.draw(kaynak, in: CGRect(x: 0, y: 0, width: CGFloat(boyut), height: CGFloat(boyut)))
}

func üretAcik() {
    let rep = yeniRep()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(boyut), height: CGFloat(boyut)))
    çizKaynak(ctx)
    NSGraphicsContext.restoreGraphicsState()
    yaz("AppIcon-1024.png", rep)
}

func üretKoyu() {
    let rep = yeniRep()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(boyut), height: CGFloat(boyut)))
    çizKaynak(ctx)
    ctx.setBlendMode(.difference)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(boyut), height: CGFloat(boyut)))
    NSGraphicsContext.restoreGraphicsState()
    yaz("AppIcon-1024-dark.png", rep)
}

func üretTinted() {
    let rep = yeniRep()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.clear(CGRect(x: 0, y: 0, width: CGFloat(boyut), height: CGFloat(boyut)))
    çizKaynak(ctx)
    NSGraphicsContext.restoreGraphicsState()

    if let data = rep.bitmapData {
        let spp = rep.samplesPerPixel
        let row = rep.bytesPerRow
        for y in 0..<boyut {
            for x in 0..<boyut {
                let i = y * row + x * spp
                let r = Double(data[i])
                let g = Double(data[i + 1])
                let b = Double(data[i + 2])
                let lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
                let alpha = UInt8(max(0, min(255, Int((1.0 - lum) * 255.0))))
                data[i] = 255
                data[i + 1] = 255
                data[i + 2] = 255
                data[i + 3] = alpha
            }
        }
    }
    yaz("AppIcon-1024-tinted.png", rep)
}

üretAcik()
üretKoyu()
üretTinted()
