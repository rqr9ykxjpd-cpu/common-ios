import SwiftUI

struct DiscoverView: View {
    @State private var profiles = StudentProfile.samples
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "08080A").ignoresSafeArea()

                VStack(spacing: 16) {
                    header

                    ZStack {
                        if profiles.isEmpty {
                            emptyState
                        } else {
                            ForEach(Array(profiles.prefix(2).enumerated()).reversed(), id: \.element.id) { index, profile in
                                ProfileCard(profile: profile)
                                    .scaleEffect(index == 0 ? 1 : 0.95)
                                    .offset(y: index == 0 ? 0 : 15)
                                    .zIndex(index == 0 ? 1 : 0)
                                    .offset(index == 0 ? dragOffset : .zero)
                                    .rotationEffect(.degrees(index == 0 ? Double(dragOffset.width / 24) : 0))
                                    .gesture(index == 0 ? dragGesture : nil)
                            }
                        }
                    }
                    .padding(.horizontal, 18)

                    actionBar
                }
                .padding(.bottom, 4)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            Wordmark(compact: true)
            Spacer()
            Button {} label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.body.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.08), in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                if abs(value.translation.width) > 110 {
                    dismiss(direction: value.translation.width > 0 ? 1 : -1)
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { dragOffset = .zero }
                }
            }
    }

    private var actionBar: some View {
        HStack(spacing: 18) {
            RoundAction(icon: "xmark", size: 56, tint: .white.opacity(0.75)) { dismiss(direction: -1) }
            RoundAction(icon: "bookmark.fill", size: 46, tint: Color(hex: "B287F5")) {}
            RoundAction(icon: "heart.fill", size: 66, tint: .black, fill: .white) { dismiss(direction: 1) }
            RoundAction(icon: "paperplane.fill", size: 46, tint: Color(hex: "FF7A99")) {}
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "moon.stars.fill").font(.system(size: 42))
            Text("Şimdilik bu kadar").font(.title2.bold())
            Text("Yeni profiller birazdan burada olacak.").foregroundStyle(.secondary)
            Button("Kartları yenile") { profiles = StudentProfile.samples }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dismiss(direction: CGFloat) {
        guard !profiles.isEmpty else { return }
        withAnimation(.easeIn(duration: 0.28)) {
            dragOffset = CGSize(width: direction * 700, height: 80)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            profiles.removeFirst()
            dragOffset = .zero
        }
    }
}

struct ProfileCard: View {
    let profile: StudentProfile

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                ProfileMedia(url: profile.imageURL, data: nil, assetName: profile.imageAssetName)
                .frame(width: proxy.size.width, height: proxy.size.height)

                LinearGradient(colors: [.clear, .black.opacity(0.1), .black.opacity(0.94)], startPoint: .top, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 7) {
                        Text("%\(profile.compatibility) UYUM")
                        Circle().frame(width: 3, height: 3)
                        Text("BUGÜN AKTİF")
                    }
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.75))

                    HStack(spacing: 8) {
                        Text("\(profile.name), \(profile.age)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        if profile.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color(hex: "B287F5"))
                        }
                    }

                    Label(profile.university, systemImage: "graduationcap.fill")
                        .font(.subheadline.weight(.semibold))
                    Text("\(profile.department) · \(profile.year)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))

                    HStack {
                        ForEach(profile.interests, id: \.self) { interest in
                            Text(interest)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                }
                .padding(24)
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white.opacity(0.1)))
        }
    }
}

struct RoundAction: View {
    let icon: String
    let size: CGFloat
    let tint: Color
    var fill: Color = Color.white.opacity(0.08)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.31, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(fill, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.1)))
        }
    }
}
