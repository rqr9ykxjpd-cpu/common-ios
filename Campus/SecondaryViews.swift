import SwiftUI

struct MatchesView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "08080A").ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        Text("Yeni bağlantılar")
                            .font(.system(size: 34, weight: .bold, design: .rounded))

                        HStack(spacing: 18) {
                            ForEach(StudentProfile.samples) { profile in
                                VStack(spacing: 9) {
                                    ProfileMedia(url: profile.imageURL, data: nil, assetName: profile.imageAssetName)
                                    .frame(width: 76, height: 76)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color(hex: "B287F5"), lineWidth: 2))
                                    Text(profile.name).font(.caption.weight(.semibold))
                                }
                            }
                        }

                        Text("Mesajlar")
                            .font(.title2.bold())

                        ForEach(StudentProfile.samples.prefix(2)) { profile in
                            HStack(spacing: 14) {
                                ProfileMedia(url: profile.imageURL, data: nil, assetName: profile.imageAssetName)
                                .frame(width: 58, height: 58)
                                .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(profile.name).font(.headline)
                                    Text("Bu hafta kampüste kahve?").foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("şimdi").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    .padding(22)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct ProfileView: View {
    @AppStorage("didEnterCampus") private var didEnterCampus = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "08080A").ignoresSafeArea()
                VStack(spacing: 22) {
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(LinearGradient(colors: [Color(hex: "B287F5"), Color(hex: "FF7A99")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 124, height: 124)
                            .overlay(Text("S").font(.system(size: 50, weight: .black)))
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title)
                            .foregroundStyle(.white, Color(hex: "8B5CF6"))
                    }
                    Text("Senin profilin")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Öğrenci doğrulaması tamamlandı")
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        ProfileRow(icon: "person.text.rectangle", title: "Profili düzenle")
                        Divider().overlay(.white.opacity(0.08))
                        ProfileRow(icon: "slider.horizontal.3", title: "Tercihler")
                        Divider().overlay(.white.opacity(0.08))
                        ProfileRow(icon: "shield.checkered", title: "Güvenlik merkezi")
                    }
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22))

                    Button("Prototipi başa al") { didEnterCampus = false }
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 12)
                    Spacer()
                }
                .padding(24)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct ProfileRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon).frame(width: 30)
            Text(title).font(.body.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding(18)
    }
}
