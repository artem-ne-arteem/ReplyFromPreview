import SwiftUI

/// Превью чата по долгому тапу: можно ответить, не открывая чат.
struct ChatPreviewOverlay: View {
    let store: ChatStore
    let chatID: Chat.ID
    /// Где была строка чата в момент долгого тапа: отсюда превью «вырастает».
    let sourceFrame: CGRect
    /// Где строка сейчас (после ответа чат поднимается наверх): туда превью «улетает».
    let currentFrame: () -> CGRect?
    var onClose: () -> Void
    var onOpen: () -> Void

    @State private var appeared = false
    @State private var expanded = false
    @State private var isSending = false
    @State private var isClosing = false
    @State private var closingFrame: CGRect?
    @State private var dragOffset: CGFloat = 0
    @State private var draft = ""
    @State private var sentTick = 0
    @FocusState private var focused: Bool

    private let spring = Animation.spring(response: 0.38, dampingFraction: 0.84)

    var body: some View {
        GeometryReader { geo in
            let screenMidY = geo.frame(in: .global).midY
            let originY = (closingFrame ?? sourceFrame).midY - screenMidY

            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.08))
                    .ignoresSafeArea()
                    .opacity(appeared ? max(0.3, 1 - dragOffset / 500) : 0)
                    .onTapGesture { close() }

                if let chat = store.chat(chatID) {
                    VStack(spacing: 10) {
                        card(chat)
                            // Место под поле ввода и меню, чтобы всё влезало и на маленьких iPhone.
                            .frame(maxHeight: expanded ? .infinity : max(220, min(470, geo.size.height - 300)))

                        InputBar(draft: $draft, focused: $focused, onSend: send)

                        if !expanded {
                            menu(chat)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .frame(maxHeight: .infinity)
                    .scaleEffect(appeared ? 1 : 0.35)
                    .offset(y: appeared ? dragOffset : originY)
                    .opacity(appeared ? 1 : 0)
                }
            }
        }
        .animation(spring, value: expanded)
        .sensoryFeedback(.success, trigger: sentTick)
        .onChange(of: focused) {
            guard !isSending, !isClosing else { return }
            expanded = focused
        }
        .onAppear {
            withAnimation(spring) { appeared = true }
        }
    }

    // MARK: - Карточка с чатом

    private func card(_ chat: Chat) -> some View {
        ZStack(alignment: .top) {
            ChatWallpaper()

            MessagesList(messages: chat.messages, topInset: 66)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.14),
                            .init(color: .black, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            header(chat)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
    }

    private func header(_ chat: Chat) -> some View {
        HStack {
            CircleButton(systemName: "chevron.left") { close() }
            Spacer()
            VStack(spacing: 0) {
                Text(chat.name)
                    .font(.system(size: 15, weight: .semibold))
                Text(chat.status)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 5)
            .glass(Capsule())
            Spacer()
            Avatar(chat: chat, size: 40)
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture { open() }
        .gesture(dragToDismiss)
    }

    // MARK: - Меню

    private func menu(_ chat: Chat) -> some View {
        VStack(spacing: 0) {
            MenuRow(title: chat.unread > 0 ? "Mark as Read" : "Mark as Unread",
                    icon: chat.unread > 0 ? "envelope.open" : "envelope.badge") {
                store.update(chatID) { $0.unread = $0.unread > 0 ? 0 : 1 }
                close()
            }
            MenuRow(title: chat.isPinned ? "Unpin" : "Pin",
                    icon: chat.isPinned ? "pin.slash" : "pin") {
                withAnimation(spring) { store.togglePin(chatID) }
                close()
            }
            MenuRow(title: chat.isMuted ? "Unmute" : "Mute",
                    icon: chat.isMuted ? "bell" : "bell.slash") {
                store.update(chatID) { $0.isMuted.toggle() }
                close()
            }
            MenuRow(title: "Delete", icon: "trash", destructive: true) {
                close { withAnimation(spring) { store.delete(chatID) } }
            }
        }
        .padding(.vertical, 6)
        .glass(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Жесты и действия

    private var dragToDismiss: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 120 || value.predictedEndTranslation.height > 320 {
                    close()
                } else {
                    withAnimation(spring) { dragOffset = 0 }
                }
            }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        isSending = true
        expanded = true
        draft = ""
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            store.send(text, to: chatID)
        }
        sentTick += 1
        // Даём увидеть, как сообщение встало в чат, и закрываем превью.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { close() }
    }

    private func open() {
        focused = false
        onOpen()
    }

    private func close(then completion: (() -> Void)? = nil) {
        guard !isClosing else { return }
        isClosing = true
        focused = false
        closingFrame = currentFrame() ?? sourceFrame
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            completion?()
            onClose()
        }
    }
}

struct MenuRow: View {
    let title: String
    let icon: String
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                Spacer()
            }
            .font(.system(size: 17))
            .foregroundStyle(destructive ? Color.red : Color.primary)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
