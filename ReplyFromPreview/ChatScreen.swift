import SwiftUI

/// Полный экран чата со стеклянной шапкой.
struct ChatScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let store: ChatStore
    let chatID: Chat.ID
    var onOpenProfile: (Chat.ID) -> Void

    @State private var draft = ""
    @State private var replyTo: Message?
    @FocusState private var focused: Bool

    var body: some View {
        if let chat = store.chat(chatID) {
            MessagesList(
                messages: chat.messages,
                topInset: 8,
                isTyping: store.typing.contains(chatID),
                onReply: { message in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { replyTo = message }
                    focused = true
                },
                onReact: { message in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                        store.react("❤️", message: message.id, in: chatID)
                    }
                },
                onDelete: { message in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        store.deleteMessage(message.id, in: chatID)
                    }
                }
            )
            .background(ChatWallpaper().ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                GlassHeader(onBack: { dismiss() }, fade: nil) {
                    title(chat)
                        .contentShape(Rectangle())
                        .onTapGesture { onOpenProfile(chatID) }
                } trailing: {
                    Button { onOpenProfile(chatID) } label: {
                        Avatar(chat: chat, size: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                InputBar(
                    draft: $draft,
                    focused: $focused,
                    replyAuthor: replyTo.map { $0.isOutgoing ? "You" : chat.name },
                    replyText: replyTo?.previewText,
                    onCancelReply: { withAnimation { replyTo = nil } },
                    onSend: send
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                store.openChatID = chatID
                withAnimation { store.update(chatID) { $0.unread = 0 } }
            }
            .onDisappear {
                if store.openChatID == chatID { store.openChatID = nil }
            }
        }
    }

    private func title(_ chat: Chat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                Text(chat.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                NameBadgeView(badge: chat.badge, size: 14)
            }
            if store.typing.contains(chatID) {
                TypingLabel(text: chat.kind == .group ? "Pepe is typing" : "typing", font: 13)
            } else {
                Text(chat.status)
                    .font(.system(size: 13))
                    .foregroundStyle(chat.isOnline ? Color.tgBlue : Color.tgGray)
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.typing.contains(chatID))
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let reply = replyTo
        draft = ""
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { replyTo = nil }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            store.send(text, to: chatID, replyTo: reply)
        }
        focused = true
    }
}
