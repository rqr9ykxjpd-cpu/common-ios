import SwiftUI

/// Ana eylem düğmesi (Kaydet, Gönder): dolu kapsül, üç hâl.
///
/// Basınca yazının yerini yükleme alır; iş bitince yarım saniye ✓ görünür,
/// sonra `onDone` çalışır (genelde ekranı kapatmak). Eskiden ekran doğrudan
/// kapanıyordu; kullanıcı işin olduğunu düğmenin kendisinde görmüyordu.
/// Başarı titreşimi AppState'teki işlemin kendisinde; burada tekrarlanmıyor.
struct PrimaryActionButton: View {
    let title: String
    var enabled = true
    var fill: Color = BondTheme.acid
    var foreground: Color = BondTheme.onAccent
    /// `true` dönerse başarılı sayılır ve ✓ gösterilir.
    let action: () async -> Bool
    var onDone: () -> Void = {}

    private enum Phase { case idle, working, done }
    @State private var phase: Phase = .idle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            guard phase == .idle else { return }
            Task { await run() }
        } label: {
            ZStack {
                Text(title)
                    .fontWeight(.semibold)
                    .opacity(phase == .idle ? 1 : 0)
                ProgressView()
                    .tint(foreground)
                    .opacity(phase == .working ? 1 : 0)
                Image(systemName: "checkmark")
                    .font(.headline.weight(.bold))
                    .scaleEffect(phase == .done ? 1 : 0.4)
                    .opacity(phase == .done ? 1 : 0)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(fill, in: Capsule())
        }
        .buttonStyle(.pressable)
        .disabled(!enabled || phase != .idle)
        .opacity(enabled || phase != .idle ? 1 : 0.45)
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: enabled)
        .animation(reduceMotion ? nil : .bouncy(duration: 0.35, extraBounce: 0.15), value: phase)
        .accessibilityLabel(title)
    }

    private func run() async {
        phase = .working
        guard await action() else {
            phase = .idle
            return
        }
        phase = .done
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 600))
        onDone()
    }
}
