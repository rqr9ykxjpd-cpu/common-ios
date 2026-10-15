import SwiftUI

/// Sohbeti özelleştir: ortak tema, hızlı tepki ve kişisel yazı boyutu.
///
/// Seçim sohbete hemen yansıyor (arkadaki sohbet ve üstteki önizleme aynı
/// anda değişiyor); sunucuya ekran kapanınca son hâl gidiyor. Her dokunuşta
/// gönderilseydi sohbet "temayı … yaptı" satırlarıyla dolardı.
struct ChatCustomizeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemScheme
    let conversationID: UUID
    @AppStorage(ChatTextSize.storageKey) private var textSizeRaw = ChatTextSize.normal.rawValue
    @State private var originalTheme: CardTheme?
    @State private var originalReaction: String?
    @State private var showEmojiPicker = false

    private var conversation: Conversation? { appState.conversations.first { $0.id == conversationID } }
    private var theme: CardTheme { conversation?.theme ?? .classic }
    private var quickReaction: String { conversation?.quickReaction ?? ChatStyleDefaults.quickReaction }
    private var textSize: ChatTextSize { ChatTextSize(rawValue: textSizeRaw) ?? .normal }

    /// Hızlı çubuktaki emojiler; seçili olan listede yoksa başa ekleniyor.
    private var reactionChoices: [String] {
        let liste = ReactionEmoji.quick
        return liste.contains(quickReaction) ? liste : [quickReaction] + liste.dropLast()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                    preview
                    section(L10n.ChatStyle.theme, hint: L10n.ChatStyle.sharedHint) { themeGrid }
                    section(L10n.ChatStyle.quickReaction, hint: L10n.ChatStyle.quickReactionHint) { reactionRow }
                    section(L10n.ChatStyle.textSize, hint: L10n.ChatStyle.textSizeHint) {
                        Picker(L10n.ChatStyle.textSize, selection: $textSizeRaw) {
                            ForEach(ChatTextSize.allCases) { boyut in
                                Text(boyut.title).tag(boyut.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.bottom, BondTheme.Space.xl)
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.ChatStyle.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
        }
        .onAppear {
            guard originalTheme == nil else { return }
            originalTheme = theme
            originalReaction = quickReaction
        }
        .onDisappear {
            guard let originalTheme, let originalReaction else { return }
            Task {
                await appState.saveChatStyle(in: conversationID, originalTheme: originalTheme,
                                             originalReaction: originalReaction)
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiReactionPicker(selected: quickReaction) { emoji in
                ReactionEmoji.remember(emoji)
                appState.previewQuickReaction(emoji, in: conversationID)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    /// İki balon, seçilen temada ve yazı boyutunda; kendi balonunun köşesinde hızlı tepki.
    private var preview: some View {
        VStack(spacing: 10) {
            HStack {
                Text(L10n.ChatStyle.previewTheirs)
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .background(theme.theirBubble, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.theirBubbleStroke))
                    .foregroundStyle(BondTheme.ink)
                Spacer(minLength: 48)
            }
            HStack {
                Spacer(minLength: 48)
                Text(L10n.ChatStyle.previewMine)
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .foregroundStyle(theme.myBubbleText)
                    .background(theme.myBubble, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        Text(quickReaction)
                            .font(.system(size: 14))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(BondTheme.surface, in: Capsule())
                            .background(Capsule().fill(theme.chatBackground).padding(-2.5))
                            .offset(x: -8, y: 12)
                            .id(quickReaction)
                            .transition(.scale(scale: 0.3).combined(with: .opacity)
                                .animation(.spring(response: 0.38, dampingFraction: 0.5)))
                    }
            }
            .padding(.bottom, 10)
        }
        .font(textSize.font)
        .padding(BondTheme.Space.md)
        .frame(maxWidth: .infinity)
        .background(theme.chatBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(BondTheme.hairline))
        .environment(\.colorScheme, theme.scheme ?? systemScheme)
        .animation(BondTheme.Motion.smooth, value: theme)
        .animation(BondTheme.Motion.smooth, value: textSizeRaw)
        .accessibilityHidden(true)
        .padding(.top, BondTheme.Space.sm)
    }

    private var themeGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 14) {
            ForEach(CardTheme.allCases) { tema in
                Button {
                    Haptics.selection()
                    appState.previewChatTheme(tema, in: conversationID)
                } label: {
                    VStack(spacing: 6) {
                        ThemeSwatch(theme: tema, selected: tema == theme)
                        Text(tema.title)
                            .font(.caption2)
                            .foregroundStyle(tema == theme ? BondTheme.ink : BondTheme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(tema.title)
                .accessibilityAddTraits(tema == theme ? .isSelected : [])
            }
        }
    }

    private var reactionRow: some View {
        HStack(spacing: 6) {
            ForEach(reactionChoices, id: \.self) { emoji in
                Button {
                    Haptics.selection()
                    appState.previewQuickReaction(emoji, in: conversationID)
                } label: {
                    Text(emoji)
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                        .background(emoji == quickReaction ? BondTheme.ink.opacity(0.08) : .clear, in: Circle())
                        .overlay(Circle().stroke(emoji == quickReaction ? BondTheme.ink : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(emoji)
                .accessibilityAddTraits(emoji == quickReaction ? .isSelected : [])
            }
            Button { showEmojiPicker = true } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BondTheme.muted)
                    .frame(width: 44, height: 44)
                    .background(BondTheme.ink.opacity(0.06), in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(L10n.ChatStyle.moreEmoji)
        }
        .animation(BondTheme.Motion.snappy, value: quickReaction)
    }

    private func section<C: View>(_ title: String, hint: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BondTheme.ink)
            content()
            Text(hint)
                .font(.footnote)
                .foregroundStyle(BondTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Tema seçicideki yuvarlak: temanın zemini, içinde kendi balonunun rengi.
private struct ThemeSwatch: View {
    let theme: CardTheme
    let selected: Bool

    var body: some View {
        ZStack {
            Circle().fill(theme == .classic ? Color(hex: "F2F2F7") : theme.chatBackground)
            Circle()
                .fill(theme == .classic ? Color(hex: "1D1D1F") : theme.myBubble)
                .frame(width: 18, height: 18)
                .offset(x: 7, y: 7)
        }
        .frame(width: 48, height: 48)
        .overlay(Circle().stroke(BondTheme.ink.opacity(0.12), lineWidth: 0.5))
        .padding(3)
        .overlay(Circle().stroke(selected ? BondTheme.ink : .clear, lineWidth: 2))
        .animation(BondTheme.Motion.snappy, value: selected)
    }
}
