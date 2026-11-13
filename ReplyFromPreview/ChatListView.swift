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
    @State private var folder: Folder = .all
    @State private var tab: MainTab = .chats

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.chats(in: folder)) { chat in
                            row(chat)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .background(Color.white)
                .safeAreaInset(edge: .top, spacing: 0) {
                    TopBar(store: store, folder: $folder)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    BottomTabBar(selection: $tab)
                }
                .toolbar(.hidden, for: .navigationBar)
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
            .overlay(Color.black.opacity(configuration.isPressed ? 0.05 : 0))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Верхняя панель: Edit, «Chats», кнопки и папки

struct TopBar: View {
    let store: ChatStore
    @Binding var folder: Folder

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                HStack {
                    Button {} label: {
                        Text("Edit")
                            .font(.system(size: 17))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .contentShape(Capsule())
                            .glass(Capsule(), interactive: true)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    HStack(spacing: 22) {
                        Image(systemName: "plus.circle.dashed")
                        Image(systemName: "square.and.pencil")
                    }
                    .font(.system(size: 19))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .glass(Capsule(), interactive: true)
                }

                HStack(spacing: 6) {
                    StoryStack(images: ["avatar_bit16", "avatar_dog", "avatar_pepe"])
                    Text("Chats")
                        .font(.system(size: 19, weight: .semibold))
                    Image(systemName: "star.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.tgBlue)
                }
            }

            FolderBar(store: store, selection: $folder)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(alignment: .top) {
            LinearGradient(
                colors: [Color.white, Color.white.opacity(0.85), Color.white.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }
}

/// Стопка аватаров историй рядом с заголовком.
struct StoryStack: View {
    let images: [String]

    var body: some View {
        HStack(spacing: -12) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, name in
                AssetImage(name: name)
                    .frame(width: 31, height: 31)
                    .zIndex(Double(images.count - index))
            }
        }
    }
}

struct FolderBar: View {
    let store: ChatStore
    @Binding var selection: Folder
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Folder.allCases, id: \.self) { folder in
                let badge = store.badge(for: folder)
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = folder }
                } label: {
                    HStack(spacing: 6) {
                        Text(folder.rawValue)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                        if folder != .all, folder != .bots, badge.count > 0 {
                            Text("\(badge.count)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(badge.muted ? Color.black.opacity(0.75) : Color.white)
                                .padding(.horizontal, badge.count > 9 ? 5 : 0)
                                .frame(minWidth: 20, minHeight: 20)
                                .background(Capsule().fill(badge.muted ? Color(hex: 0xDCDCE0) : Color.tgBlue))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background {
                        if selection == folder {
                            Capsule()
                                .fill(Color.black.opacity(0.07))
                                .matchedGeometryEffect(id: "folder", in: namespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .glass(Capsule())
    }
}

// MARK: - Нижний таб-бар

enum MainTab: String, CaseIterable {
    case contacts = "Contacts"
    case calls = "Calls"
    case chats = "Chats"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .contacts: return "person.crop.circle.fill"
        case .calls: return "phone.fill"
        case .chats: return "bubble.left.and.bubble.right.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct BottomTabBar: View {
    @Binding var selection: MainTab
    @Namespace private var namespace

    var body: some View {
        GlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 0) {
                    ForEach(MainTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = tab }
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 21, weight: .medium))
                                    .frame(height: 26)
                                Text(tab.rawValue)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(selection == tab ? Color.tgBlue : Color.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background {
                                if selection == tab {
                                    Capsule()
                                        .fill(Color.black.opacity(0.07))
                                        .matchedGeometryEffect(id: "tab", in: namespace)
                                }
                            }
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .glass(Capsule())

                Button {} label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 62, height: 62)
                        .contentShape(Circle())
                        .glass(Circle(), interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .background(alignment: .bottom) {
            LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Строка чата

struct ChatRow: View {
    let chat: Chat

    private var previewText: String {
        guard let message = chat.lastMessage else { return "" }
        return message.video != nil ? "Video message" : message.text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Avatar(chat: chat, size: 64)
                .padding(.top, 7)

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        title
                        preview
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 0) {
                        HStack(spacing: 3) {
                            if chat.lastMessage?.isOutgoing == true {
                                DoubleCheck(size: 11).foregroundStyle(Color.tgBlue)
                            }
                            Text(chat.lastMessage?.time ?? "")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.tgGray)
                        }
                        Spacer(minLength: 0)
                        accessory
                    }
                }
                .padding(.top, 9)
                .padding(.bottom, 10)
                .padding(.trailing, 16)
                .frame(maxHeight: .infinity)

                Rectangle()
                    .fill(Color.tgSeparator)
                    .frame(height: 0.5)
                    .padding(.trailing, 16)
            }
        }
        .padding(.leading, 9)
        .frame(height: 78)
        .background(chat.isPinned ? Color.tgPinned : Color.white)
        .contentShape(Rectangle())
    }

    private var title: some View {
        HStack(spacing: 4) {
            Text(chat.name)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.black)
                .lineLimit(1)
            NameBadgeView(badge: chat.badge, size: 15)
            if chat.isMuted {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0xBDBDC2))
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let sender = chat.sender {
            VStack(alignment: .leading, spacing: 0) {
                Text(sender).foregroundStyle(.black)
                Text(previewText).foregroundStyle(Color.tgGray).lineLimit(1)
            }
            .font(.system(size: 16))
        } else {
            HStack(alignment: .top, spacing: 5) {
                if let thumbnail = chat.thumbnail {
                    AssetImage(name: thumbnail)
                        .frame(width: 19, height: 19)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .padding(.top, 1)
                }
                Text(previewText)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.tgGray)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var accessory: some View {
        HStack(spacing: 8) {
            if chat.hasOpenButton {
                Text("OPEN")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .background(Capsule().fill(Color.tgBlue))
            }
            if chat.unread > 0 {
                Text("\(chat.unread)")
                    .font(.system(size: 14))
                    .foregroundStyle(chat.isMuted ? Color.black.opacity(0.75) : Color.white)
                    .padding(.horizontal, chat.unread > 9 ? 5 : 0)
                    .frame(minWidth: 21, minHeight: 21)
                    .background(Capsule().fill(chat.isMuted ? Color(hex: 0xE3E3E8) : Color.tgBlue))
                    .transition(.scale.combined(with: .opacity))
            } else if chat.isPinned {
                Image(systemName: "pin.fill")
                    .rotationEffect(.degrees(45))
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: 0xB0B0B6))
            }
        }
    }
}

// MARK: - Полный чат

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
                            HStack(spacing: 3) {
                                Text(chat.name).font(.system(size: 16, weight: .semibold))
                                NameBadgeView(badge: chat.badge, size: 13)
                            }
                            Text(chat.status).font(.system(size: 12)).foregroundStyle(Color.tgGray)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Avatar(chat: chat, size: 38)
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
