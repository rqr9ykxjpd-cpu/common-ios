// Kaydırmalı post, demo ekran görüntüsü olmadan: her karede uygulamadaki tek
// bir kart, aynı ölçülerle SwiftUI'da yeniden çizilir (PlacesWallView.placeRow,
// StudyGroupCard, akış gönderisi). Fotoğraf yok; yüzlerin yerine baş harfler.
// Çalıştır: swift cards.swift
import AppKit
import SwiftUI

let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// Uygulamada kart (surface) zeminden koyu; burada tuval koyu, kart beyaz —
// aynı kontrast, ters çevrilmiş. Kenarlık ve gölge yok, uygulamadaki gibi.
let canvas = Color(hex: 0xF2F1EE)
let card = Color.white
let ink = Color(hex: 0x1D1D1F)
let muted = Color(hex: 0x707070)
let liveGreen = Color(hex: 0x34C759)
let burntOrange = Color(hex: 0xE0661F)
let eventTint = Color(hex: 0x7C3AED)

// iOS metin stilleri (pt). macOS'un .body'si 13 pt; iOS değerleri elle.
enum IOS {
    static let body: CGFloat = 17, callout: CGFloat = 16, subheadline: CGFloat = 15
    static let footnote: CGFloat = 13, caption: CGFloat = 12
}

struct Initial: View {
    let letter: String, tone: UInt32, size: CGFloat
    var body: some View {
        Circle().fill(Color(hex: tone))
            .overlay(Text(letter).font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(ink.opacity(0.75)))
            .frame(width: size, height: size)
    }
}

let tones: [UInt32] = [0xDCD3C6, 0xC9D3DC, 0xD9CFE0, 0xCFDCCF]

struct Faces: View {
    let letters: [String], size: CGFloat, overlap: CGFloat
    var body: some View {
        HStack(spacing: -overlap) {
            ForEach(Array(letters.enumerated()), id: \.offset) { i, l in
                Initial(letter: l, tone: tones[i % tones.count], size: size)
                    .overlay(Circle().stroke(card, lineWidth: 1.5))
            }
        }
    }
}

// PlacesWallView.placeRow
struct PlaceRow: View {
    let name: String, symbol: String, faces: [String], count: Int
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 38, height: 38)
                    .background(canvas, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.system(size: IOS.body, weight: .medium))
                    HStack(spacing: 6) {
                        Faces(letters: faces, size: 20, overlap: 7)
                        Circle().fill(liveGreen).frame(width: 6, height: 6)
                        Text("\(count) kişi").font(.system(size: IOS.caption, weight: .semibold))
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: IOS.caption)).foregroundStyle(muted)
            }
            Text("Buradayım")
                .font(.system(size: IOS.footnote, weight: .semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(canvas, in: Capsule())
        }
        .foregroundStyle(ink)
        .padding(12)
        .background(card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// StudyGroupCard
struct StudyGroup: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    // Başlamasına bir saatten az kalınca dolan halka.
                    Circle().trim(from: 0, to: 0.62)
                        .stroke(burntOrange, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)
                    Initial(letter: "D", tone: tones[1], size: 36)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Defne").font(.system(size: IOS.subheadline, weight: .semibold))
                    (Text(Image(systemName: "mappin.and.ellipse")) + Text(" Merkez Kütüphane  ")
                        + Text(Image(systemName: "clock")) + Text(" Bugün 20:30"))
                        .font(.system(size: IOS.footnote))
                        .foregroundStyle(muted)
                }
                .padding(.top, 5)
                Spacer(minLength: 8)
            }
            Text("Veri Yapıları vize tekrarı")
                .font(.system(size: IOS.callout, weight: .medium))
            HStack(spacing: 10) {
                Faces(letters: ["D", "A", "S"], size: 24, overlap: 8)
                Text("3/5 kişi").font(.system(size: IOS.footnote, weight: .medium)).foregroundStyle(muted)
                Spacer(minLength: 8)
                Text("Katıl")
                    .font(.system(size: IOS.subheadline, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(minHeight: 40)
                    .background(canvas, in: Capsule())
            }
        }
        .foregroundStyle(ink)
        .padding(14)
        .background(card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// Akış gönderisi (Etkinlik rozeti + en iyi cevap önizlemesi + oy satırı)
struct EventPost: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Initial(letter: "S", tone: tones[2], size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Selin").font(.system(size: IOS.subheadline, weight: .semibold))
                    Text("Hukuk · 3. sınıf · 6 saat önce").font(.system(size: IOS.footnote)).foregroundStyle(muted)
                }
                Spacer()
                Image(systemName: "ellipsis").font(.system(size: IOS.subheadline, weight: .semibold)).foregroundStyle(muted)
            }
            Label("Etkinlik", systemImage: "calendar")
                .font(.system(size: IOS.footnote, weight: .semibold))
                .foregroundStyle(eventTint)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(eventTint.opacity(0.12), in: Capsule())
            Text("Perşembe 19.00 açık hava sineması: amfide, battaniyeni getir. Kısa filmler gecesi.")
                .font(.system(size: IOS.body, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Image(systemName: "arrow.up").font(.system(size: IOS.caption, weight: .semibold)).foregroundStyle(muted)
                Text("7").font(.system(size: IOS.footnote, weight: .semibold)).foregroundStyle(muted)
                Text("Arda").font(.system(size: IOS.footnote, weight: .semibold))
                Text("Biz 3 kişi geliyoruz").font(.system(size: IOS.footnote))
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            HStack(spacing: 10) {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.up")
                    Text("41").font(.system(size: IOS.subheadline, weight: .semibold))
                    Image(systemName: "arrow.down")
                }
                .padding(.horizontal, 14).frame(minHeight: 36)
                .background(canvas, in: Capsule())
                Label("2 yorum", systemImage: "bubble.left")
                    .font(.system(size: IOS.subheadline, weight: .medium))
                    .padding(.horizontal, 14).frame(minHeight: 36)
                    .background(canvas, in: Capsule())
                Spacer()
                Image(systemName: "paperplane")
                Image(systemName: "bookmark").padding(.leading, 12)
            }
            .font(.system(size: IOS.subheadline, weight: .semibold))
        }
        .foregroundStyle(ink)
        .padding(16)
        .background(card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct Lockup: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSImage(contentsOf: dir.appendingPathComponent("mark-ink.png"))!)
                .resizable().scaledToFit().frame(height: 27)
            Text("common").font(.system(size: 30, weight: .bold, design: .serif)).tracking(-0.78)
                .offset(y: -2)
        }
        .foregroundStyle(ink)
    }
}

struct Slide<Content: View>: View {
    let lines: [String]
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) {
            Text(lines.joined(separator: "\n"))
                .font(.system(size: 80, weight: .bold, design: .serif))
                .tracking(-0.5)
                .lineSpacing(-4)
                .multilineTextAlignment(.center)
                .foregroundStyle(ink)
                .padding(.top, 104)
            Spacer()
            content
            Spacer()
            Lockup().padding(.bottom, 92)
        }
        .frame(width: 1080, height: 1350)
        .background(canvas)
    }
}

/// Kart iOS nokta ölçüsünde (400 pt genişlik) kurulur, sonra büyütülür.
func scaled<V: View>(_ v: V, by k: CGFloat) -> some View {
    v.frame(width: 400).fixedSize(horizontal: false, vertical: true).scaleEffect(k).frame(width: 400 * k)
}

@MainActor func save<V: View>(_ view: V, _ name: String) {
    let r = ImageRenderer(content: view)
    r.scale = 2
    let rep = NSBitmapImageRep(cgImage: r.cgImage!)
    try! rep.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent(name))
}

MainActor.assumeIsolated {
    // Kim nerede listesinden üç satır; satır arası uygulamadaki gibi 8 pt.
    let places = VStack(spacing: 8) {
        PlaceRow(name: "Şamdan Kafe", symbol: "cup.and.saucer", faces: ["E", "B", "K"], count: 4)
        PlaceRow(name: "Aytaç Cafe", symbol: "cup.and.saucer", faces: ["M", "D"], count: 2)
        PlaceRow(name: "Merkez Kütüphane", symbol: "books.vertical", faces: ["A", "S", "Z"], count: 6)
    }
    save(Slide(lines: ["Şu an kafede", "kim var?"]) { scaled(places, by: 2.2) }, "carousel-1.png")
    save(Slide(lines: ["Bu akşam vizeye", "kim çalışıyor?"]) { scaled(StudyGroup(), by: 2.2) }, "carousel-2.png")
    save(Slide(lines: ["Bu hafta kampüste", "ne var?"]) { scaled(EventPost(), by: 2.2) }, "carousel-3.png")
    save(
        VStack(spacing: 0) {
            Spacer()
            Text("Hepsi tek yerde.\nYalnızca senin kampüsün.")
                .font(.system(size: 70, weight: .bold, design: .serif))
                .tracking(-0.4)
                .multilineTextAlignment(.center)
                .foregroundStyle(ink)
            Spacer()
            Lockup()
            Text("App Store’da").font(.system(size: 25, weight: .medium)).foregroundStyle(muted)
                .padding(.top, 14).padding(.bottom, 84)
        }
        .frame(width: 1080, height: 1350)
        .background(canvas),
        "carousel-4.png")
}
