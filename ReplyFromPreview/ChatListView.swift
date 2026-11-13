import SwiftUI

/// Хранит позиции строк списка, не вызывая перерисовку.
final class FrameStore {
    var frames: [Chat.ID: CGRect] = [:]
}

struct ChatListView: View {
    struct PreviewState: Equatable {
        let id: Chat.ID
        let frame: CGRect
    }

    @State private var store = ChatStore()
    @State private var frames = FrameStore()
    @State private var preview: PreviewState?
    @State private var openedChat: Chat.ID?
    @State private var suppressTap = false
    @State private var hapticTick = 0

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.chats) { chat in
                            row(chat)
                        }
                    }
                }
                .navigationTitle("Chats")
                .navigationDestination(item: $openedChat) { id in
                    ChatScreen(store: store, chatID: id)
                }
            }

            if let preview {
                ChatPreviewOverlay(
                    store: store,
                    chatID: preview.id,
                    sourceFrame: preview.frame,
                    currentFrame: { frames.frames[preview.id] },
                    onClose: {
                        self.preview = nil
                        suppressTap = false
                    },
                    onOpen: {
                        openedChat = preview.id
                        self.preview = nil
                        suppressTap = false
                    }
                )
                .zIndex(1)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTick)
    }

    /// Кнопка + долгое нажатие поверх неё: так список нормально скроллится,
    /// а после долгого нажатия обычный тап не открывает чат.
    private func row(_ chat: Chat) -> some View {
        Button {
            if suppressTap {
                suppressTap = false
                return
            }
            openedChat = chat.id
        } label: {
            ChatRow(chat: chat)
        }
        .buttonStyle(RowPressStyle())
        .opacity(preview?.id == chat.id ? 0 : 1)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            frames.frames[chat.id] = frame
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                guard preview == nil else { return }
                suppressTap = true
                hapticTick += 1
                preview = PreviewState(id: chat.id, frame: frames.frames[chat.id] ?? .zero)
            }
        )
    }
}

struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(Color.primary.opacity(configuration.isPressed ? 0.06 : 0))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ChatRow: View {
    let chat: Chat

    private var preview: String {
        guard let message = chat.lastMessage else { return "" }
        return (message.isOutgoing ? "You: " : "") + message.text
    }

    var body: some View {
        HStack(spacing: 12) {
            Avatar(chat: chat, size: 56)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(chat.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if chat.isMuted {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if chat.lastMessage?.isOutgoing == true {
                        DoubleCheck().foregroundStyle(Color(hex: 0x2AABEE))
                    }
                    Text(chat.lastMessage?.time ?? "")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top) {
                    Text(preview)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                    if chat.unread > 0 {
                        Text("\(chat.unread)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(Capsule().fill(chat.isMuted ? Color.gray : Color(hex: 0x2AABEE)))
                            .transition(.scale.combined(with: .opacity))
                    } else if chat.isPinned {
                        Image(systemName: "pin.fill")
                            .rotationEffect(.degrees(45))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 78)
        .background(chat.isPinned ? Color(.secondarySystemBackground) : Color(.systemBackground))
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 82)
        }
    }
}

struct ChatScreen: View {
    let store: ChatStore
    let chatID: Chat.ID

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        if let chat = store.chat(chatID) {
            MessagesList(messages: chat.messages)
                .background(ChatWallpaper().ignoresSafeArea())
                .safeAreaInset(edge: .bottom) {
                    InputBar(draft: $draft, focused: $focused, onSend: send)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 0) {
                            Text(chat.name).font(.system(size: 16, weight: .semibold))
                            Text(chat.status).font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Avatar(chat: chat, size: 34)
                    }
                }
                .onAppear {
                    store.update(chatID) { $0.unread = 0 }
                }
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            store.send(text, to: chatID)
        }
        focused = true
    }
}
