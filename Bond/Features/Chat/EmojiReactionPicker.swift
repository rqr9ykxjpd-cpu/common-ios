import SwiftUI

/// Mesaja tepki için emoji seçimi. Hızlı çubuktaki altı emoji yetmeyince "+"
/// ile açılır; son kullanılanlar en üstte ve hızlı çubuğa da taşınır.
enum ReactionEmoji {
    static let quickDefaults = ["❤️", "😂", "😮", "😢", "🔥", "👍"]
    private static let recentKey = "sonTepkiler"

    static var recent: [String] {
        (UserDefaults.standard.string(forKey: recentKey) ?? "")
            .split(separator: "|").map(String.init).filter { !$0.isEmpty }
    }

    /// Hızlı çubuk: son kullanılanlar önde, boşluk varsayılanlarla dolar.
    static var quick: [String] {
        var sonuc: [String] = []
        for emoji in recent + quickDefaults where !sonuc.contains(emoji) {
            sonuc.append(emoji)
            if sonuc.count == 6 { break }
        }
        return sonuc
    }

    static func remember(_ emoji: String) {
        let yeni = [emoji] + recent.filter { $0 != emoji }
        UserDefaults.standard.set(yeni.prefix(18).joined(separator: "|"), forKey: recentKey)
    }

    struct Category: Identifiable {
        let id: String
        let title: String
        let emojis: [String]
    }

    static var categories: [Category] {
        [
            Category(id: "faces", title: L10n.ChatReactions.faces, emojis: [
                "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "😉", "😊", "😇",
                "🥰", "😍", "🤩", "😘", "😋", "😛", "😜", "🤪", "😝", "🤗", "🤭", "🤫",
                "🤔", "🤐", "🤨", "😐", "😑", "😶", "🫠", "😏", "😒", "🙄", "😬",
                "😌", "😔", "😪", "😴", "😷", "🥴", "😵‍💫", "🤯", "🥳", "😎", "🤓", "🧐",
                "😕", "🫤", "😟", "🙁", "😮", "😯", "😲", "😳", "🥺", "🥹", "😦", "😧",
                "😨", "😰", "😥", "😢", "😭", "😱", "😖", "😣", "😞", "😓", "😩", "😫",
                "🥱", "😤", "😡", "😠", "🤬", "😈", "💀", "🤡", "👻", "👀", "🫣", "🙈",
            ]),
            Category(id: "gestures", title: L10n.ChatReactions.gestures, emojis: [
                "👍", "👎", "👏", "🙌", "🫶", "👐", "🤲", "🤝", "🙏", "✌️", "🤞", "🫰",
                "🤟", "🤘", "👌", "🤌", "🤏", "👈", "👉", "👆", "👇", "☝️", "✋", "🤚",
                "🖐️", "🖖", "👋", "🤙", "💪", "🫵", "✍️", "🤳",
            ]),
            Category(id: "hearts", title: L10n.ChatReactions.hearts, emojis: [
                "❤️", "🧡", "💛", "💚", "💙", "🩵", "💜", "🤎", "🖤", "🩶", "🤍", "🩷",
                "💔", "❤️‍🔥", "❤️‍🩹", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "♥️",
            ]),
            Category(id: "fun", title: L10n.ChatReactions.fun, emojis: [
                "🔥", "✨", "⭐", "🌟", "💯", "🎉", "🎊", "🥂", "🍾", "🎁", "🏆", "🥇",
                "⚽", "🏀", "🎮", "🎧", "🎵", "🎶", "📸", "🎬", "📚", "🎓", "💡", "🚀",
            ]),
            Category(id: "food", title: L10n.ChatReactions.food, emojis: [
                "☕", "🍵", "🧋", "🍺", "🍻", "🍷", "🍕", "🍔", "🍟", "🌯", "🍩", "🍪",
                "🍫", "🍰", "🧁", "🍦", "🍓", "🍉", "🍌", "🥑",
            ]),
            Category(id: "animals", title: L10n.ChatReactions.animals, emojis: [
                "🐶", "🐱", "🐻", "🐼", "🦊", "🐸", "🐵", "🦁", "🐯", "🐰", "🐥", "🦋",
                "🌸", "🌹", "🌻", "🌈", "☀️", "🌙", "⛅", "❄️",
            ]),
            Category(id: "symbols", title: L10n.ChatReactions.symbols, emojis: [
                "✅", "❌", "❗", "❓", "‼️", "⁉️", "💤", "💬", "💭", "🗯️", "📌", "📍",
                "⏰", "📅", "💸", "💰", "🎯", "🧠", "🫀", "👑", "💎", "🍀", "🪄", "🆗",
            ]),
        ]
    }
}

struct EmojiReactionPicker: View {
    let selected: String?
    let pick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 4)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: BondTheme.Space.lg, pinnedViews: [.sectionHeaders]) {
                    let recent = ReactionEmoji.recent
                    if !recent.isEmpty {
                        section(L10n.ChatReactions.recent, recent)
                    }
                    ForEach(ReactionEmoji.categories) { kategori in
                        section(kategori.title, kategori.emojis)
                    }
                }
                .padding(.horizontal, BondTheme.Space.md)
                .padding(.bottom, BondTheme.Space.xl)
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.ChatReactions.pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
        }
    }

    private func section(_ title: String, _ emojis: [String]) -> some View {
        Section {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(emojis, id: \.self) { emoji in
                    Button {
                        Haptics.impact(.light)
                        pick(emoji)
                        dismiss()
                    } label: {
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(width: 44, height: 44)
                            .background(selected == emoji ? BondTheme.ink.opacity(0.08) : .clear, in: Circle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(L10n.Chat.addReaction(emoji))
                }
            }
        } header: {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(BondTheme.muted)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BondTheme.paper)
        }
    }
}
