import SwiftUI

/// Rozetin tek gösterim biçimi.
///
/// Rozet önce her ekranda ayrı ayrı çiziliyordu ve çoğu yerde çıplak bir ikondu:
/// yıldızı gören "bu ne demek" diye soruyordu. Üstelik her yeni ekranda yeniden
/// yazıldığı için biçimler birbirinden ayrışıyordu. Tek bileşene bağlandı.
struct ProfileBadgeLabel: View {
    let badge: ProfileBadge
    /// Dar yerlerde (akış başlığı, liste satırı) daha küçük durur.
    var compact = false

    var body: some View {
        if let icon = badge.systemImage, let title = badge.title {
            Label(title, systemImage: icon)
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
                .foregroundStyle(badge.accentForeground)
                .padding(.horizontal, compact ? 8 : 10)
                .frame(height: compact ? 22 : 26)
                .background(badge.accent, in: Capsule())
                .lineLimit(1)
                .fixedSize()
        }
    }
}

/// Kurucu künyesi — rozetin altındaki kimlik satırı.
///
/// Basit el yazısı (Noteworthy Bold): Girişimci · Startup Developer / Concept Manager.
struct FounderCredLine: View {
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(BondTheme.ember)
                .frame(width: 2, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Badge.founderCredRoles)
                    .font(.custom("Noteworthy-Bold", size: 17))
                    .foregroundStyle(BondTheme.ember.opacity(0.9))

                Text(L10n.Badge.founderCredFocus)
                    .font(.custom("Noteworthy-Bold", size: 17))
                    .foregroundStyle(BondTheme.ember)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.Badge.founderCredRoles), \(L10n.Badge.founderCredFocus)")
    }
}

/// Kurucuya özel iletişim — ofis, adres, telefon.
///
/// Kart/kırmızı kutu yok; profil metninin devamı gibi durur.
struct FounderContactCard: View {
    private static let phoneDisplay = "+90 546 875 85 73"
    private static let phoneURL = URL(string: "tel:+905468758573")

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Badge.founderOffice)
                .font(.custom("Noteworthy-Light", size: 17))
                .foregroundStyle(BondTheme.muted)
                .accessibilityAddTraits(.isHeader)

            // L şeklinde, elle çizilmiş ok → adres.
            HStack(alignment: .center, spacing: 10) {
                HandDrawnLArrow()
                    .stroke(BondTheme.ink.opacity(0.55), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                    .frame(width: 26, height: 28)
                    .accessibilityHidden(true)

                Text(L10n.Badge.founderOfficePlace)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BondTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L10n.Badge.founderOfficePlace)

            if let phoneURL = Self.phoneURL {
                Link(destination: phoneURL) {
                    Text(Self.phoneDisplay)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(BondTheme.ink.opacity(0.78))
                        .underline(true, pattern: .dot)
                }
                .padding(.leading, 36)
                .accessibilityLabel(L10n.Badge.founderCallA11y(Self.phoneDisplay))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Eğitim satırı: 🎓 + bölüm / dil track / üniversite / yıl.
///
/// Kurucu profilinde üniversite kısaltması ("YÜ") açılır ve kalın siyah yazılır.
struct ProfileEducationLine: View {
    let department: String
    var university: String? = nil
    var year: String? = nil
    var font: Font = .system(size: 15, weight: .semibold)
    /// `true` iken YÜ → Yalova Üniversitesi ve üniversite adı ink + bold.
    var highlightUniversity = false

    private var departmentParts: [String] {
        DepartmentCatalog.educationParts(department)
    }

    private var universityLabel: String? {
        guard let university, !university.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return UniversityCatalog.display(university, expanded: highlightUniversity)
    }

    private var yearLabel: String? {
        guard let year else { return nil }
        let shown = AcademicYear.display(year)
        return shown.isEmpty ? nil : shown
    }

    private var accessibilityParts: [String] {
        departmentParts + [universityLabel, yearLabel].compactMap { $0 }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("🎓")
                .font(.system(size: 14))
                .accessibilityHidden(true)
            educationText
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityParts.joined(separator: ", "))
    }

    private var educationText: Text {
        var result = Text("")
        var needsSep = false

        func append(_ value: String, emphasized: Bool = false) {
            if needsSep {
                result = result + Text("  ·  ").font(font).foregroundStyle(BondTheme.muted)
            }
            if emphasized {
                result = result + Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(BondTheme.ink)
            } else {
                result = result + Text(value).font(font).foregroundStyle(BondTheme.muted)
            }
            needsSep = true
        }

        for part in departmentParts { append(part) }
        if let universityLabel { append(universityLabel, emphasized: highlightUniversity) }
        if let yearLabel { append(yearLabel) }
        return result
    }
}

/// Elle çizilmiş L ok: aşağı, sonra sağa, uçta ok başı.
private struct HandDrawnLArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset: CGFloat = 1.5
        let cornerX = rect.minX + rect.width * 0.28
        let top = CGPoint(x: cornerX + 1.2, y: rect.minY + inset)
        let corner = CGPoint(x: cornerX - 0.8, y: rect.maxY - rect.height * 0.28)
        let tip = CGPoint(x: rect.maxX - inset, y: corner.y + 1.0)

        // Dikey bacak — hafif eğri
        path.move(to: top)
        path.addQuadCurve(
            to: corner,
            control: CGPoint(x: cornerX + 2.2, y: rect.midY - 1)
        )
        // Yatay bacak
        path.addQuadCurve(
            to: tip,
            control: CGPoint(x: (corner.x + tip.x) * 0.5, y: tip.y - 2.4)
        )
        // Ok başı
        path.move(to: CGPoint(x: tip.x - 7.5, y: tip.y - 4.8))
        path.addQuadCurve(
            to: tip,
            control: CGPoint(x: tip.x - 3.2, y: tip.y - 3.6)
        )
        path.addQuadCurve(
            to: CGPoint(x: tip.x - 7.2, y: tip.y + 4.6),
            control: CGPoint(x: tip.x - 2.6, y: tip.y + 2.8)
        )
        return path
    }
}
