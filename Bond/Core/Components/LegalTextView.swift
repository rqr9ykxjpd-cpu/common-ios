import SwiftUI

/// Kullanım koşulları ve gizlilik politikasının uygulama içi hali.
///
/// Metinler yalnızca web adresinde duruyordu. Uygulamanın içinde de olması üç
/// şeyi çözüyor: incelemeyi yapan kişi uygulamadan çıkmadan okuyabiliyor,
/// internet olmadan da açılıyor, ve barındırma tarafında bir aksaklık olsa bile
/// kullanıcı koşullara erişebiliyor.
struct LegalTextView: View {
    let title: String
    let blocks: [LegalBlock]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .baslik:
                        // Başlık gezinme çubuğunda zaten var; iki kez göstermiyoruz.
                        EmptyView()
                    case let .altbaslik(text):
                        Text(text)
                            .font(.system(size: 17, weight: .bold))
                            .padding(.top, 10)
                    case let .paragraf(text):
                        Text(text)
                            .font(.system(size: 15))
                            .foregroundStyle(BondTheme.ink.opacity(0.85))
                    case let .madde(text):
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(BondTheme.violet)
                            Text(text)
                                .font(.system(size: 15))
                                .foregroundStyle(BondTheme.ink.opacity(0.85))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineSpacing(3)
            .padding(BondTheme.Space.lg)
            .padding(.bottom, BondTheme.Space.xxl)
        }
        .background(BondTheme.paper.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button(L10n.Common.done) { dismiss() } }
        }
    }
}
