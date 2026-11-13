import SwiftUI
import Combine

/// Хранит позиции строк списка, не вызывая перерисовку.
final class FrameStore {
    var frames: [Chat.ID: CGRect] = [:]
}

// MARK: - Вкладка «Чаты»

struct ChatsTab: View {
    @Environment(AppModel.self) private var model
    let store: ChatStore
    let frames: FrameStore
    let previewID: Chat.ID?
    @Binding var editing: Bool
    @Binding var selected: Set<Chat.ID>
    @Binding var suppressTap: Bool
    var onOpen: (Chat.ID) -> Void
    var onPreview: (Chat.ID) -> Void
    var onArchive: () -> Void

    @State private var folder: Folder = .all
    @State private var composing = false
    @State private var showStories = false

    var body: some View {
        List {
            if folder == .all, !store.archivedChats.isEmpty, !editing {
                Button(action: onArchive) {
                    ArchiveRow(chats: store.archivedChats)
                }
                .buttonStyle(RowPressStyle())
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.white)
            }

            ForEach(store.chats(in: folder)) { chat in
                row(chat)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.white)
        .environment(\.defaultMinListRowHeight, 0)
        .safeAreaInset(edge: .top, spacing: 0) {
            TopBar(store: store, folder: $folder, editing: $editing,
                   onCompose: { composing = true },
                   onStories: { showStories = true })
        }
        .sheet(isPresented: $composing) {
            NewMessageView(store: store) { id in
                composing = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onOpen(id) }
            }
            .environment(model)
        }
        .fullScreenCover(isPresented: $showStories) {
            StoryViewer()
        }
    }

    private func row(_ chat: Chat) -> some View {
        let isSelected = selected.contains(chat.id)
        return Button {
            if editing {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if isSelected { selected.remove(chat.id) } else { selected.insert(chat.id) }
                }
                return
            }
            if suppressTap {
                suppressTap = false
                return
            }
            onOpen(chat.id)
        } label: {
            HStack(spacing: 0) {
                if editing {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 23))
                        .foregroundStyle(isSelected ? Color.tgBlue : Color(hex: 0xC4C4C7))
                        .padding(.leading, 14)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                ChatRow(chat: chat, isTyping: store.typing.contains(chat.id))
            }
            .background(chat.isPinned ? Color.tgPinned : Color.white)
        }
        .buttonStyle(RowPressStyle())
        .opacity(previewID == chat.id ? 0 : 1)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            frames.frames[chat.id] = frame
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in onPreview(chat.id) },
            including: editing ? .subviews : .all
        )
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(chat.isPinned ? Color.tgPinned : Color.white)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { delete(chat) } label: {
                Label("Delete", systemImage: "trash.fill")
            }
            Button { archive(chat) } label: {
                Label("Archive", systemImage: "archivebox.fill")
            }
            .tint(Color(hex: 0xA0A0A6))
            Button {
                withAnimation { store.toggleMute(chat.id) }
            } label: {
                Label(chat.isMuted ? "Unmute" : "Mute", systemImage: chat.isMuted ? "bell.fill" : "bell.slash.fill")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation { store.toggleRead(chat.id) }
            } label: {
                Label(chat.unread > 0 ? "Read" : "Unread",
                      systemImage: chat.unread > 0 ? "envelope.open.fill" : "envelope.badge.fill")
            }
            .tint(Color.tgBlue)
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { store.togglePin(chat.id) }
            } label: {
                Label(chat.isPinned ? "Unpin" : "Pin", systemImage: chat.isPinned ? "pin.slash.fill" : "pin.fill")
            }
            .tint(Color(hex: 0x34C759))
        }
    }

    private func delete(_ chat: Chat) {
        guard let removed = withAnimation(.default, { store.delete(chat.id) }) else { return }
        model.showToast("Chat deleted", icon: "trash") {
            withAnimation { store.restore(removed.chat, at: removed.index) }
        }
    }

    private func archive(_ chat: Chat) {
        withAnimation { store.setArchived(chat.id, true) }
        model.showToast("Chat archived", icon: "archivebox") {
            withAnimation { store.setArchived(chat.id, false) }
        }
    }
}

// MARK: - Верхняя панель: Edit, «Chats», кнопки и папки

struct TopBar: View {
    let store: ChatStore
    @Binding var folder: Folder
    @Binding var editing: Bool
    var onCompose: () -> Void
    var onStories: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                HStack {
                    CapsuleButton(title: editing ? "Done" : "Edit", tint: editing ? Color.tgBlue : .primary) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { editing.toggle() }
                    }

                    Spacer()

                    HStack(spacing: 22) {
                        Button(action: onStories) { Image(systemName: "plus.circle.dashed") }
                        Button(action: onCompose) { Image(systemName: "square.and.pencil") }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 19))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .glass(Capsule(), interactive: true)
                }

                Button(action: onStories) {
                    HStack(spacing: 6) {
                        StoryStack(images: ["avatar_bit16", "avatar_dog", "avatar_pepe"])
                        Text("Chats")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.black)
                        Image(systemName: "star.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.tgBlue)
                    }
                }
                .buttonStyle(.plain)
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
                                .contentTransition(.numericText())
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

// MARK: - Строки

struct ChatRow: View {
    let chat: Chat
    var isTyping = false

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
                            if let last = chat.lastMessage, last.isOutgoing {
                                StatusIcon(status: last.status, size: 11)
                                    .foregroundStyle(Color.tgBlue)
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
        let text = chat.lastMessage?.previewText ?? ""
        if isTyping {
            TypingLabel(text: chat.kind == .group ? "Pepe is typing" : "typing")
        } else if let sender = chat.sender {
            VStack(alignment: .leading, spacing: 0) {
                Text(sender).foregroundStyle(.black)
                Text(text).foregroundStyle(Color.tgGray).lineLimit(1)
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
                Text(text)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.tgGray)
                    .lineLimit(2)
            }
        }
    }

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
                    .contentTransition(.numericText())
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

struct ArchiveRow: View {
    let chats: [Chat]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(hex: 0xB4B4BA))
                .overlay(
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 25))
                        .foregroundStyle(.white)
                )
                .frame(width: 60, height: 60)
                .padding(2)
                .padding(.top, 7)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Archived Chats")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.black)
                    Text(chats.map(\.name).joined(separator: ", "))
                        .font(.system(size: 16))
                        .foregroundStyle(Color.tgGray)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 9)
                .padding(.trailing, 16)

                Rectangle().fill(Color.tgSeparator).frame(height: 0.5).padding(.trailing, 16)
            }
        }
        .padding(.leading, 9)
        .frame(height: 78)
        .background(Color.white)
        .contentShape(Rectangle())
    }
}

// MARK: - Архив

struct ArchiveView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let store: ChatStore
    var onOpen: (Chat.ID) -> Void

    var body: some View {
        List {
            ForEach(store.archivedChats) { chat in
                Button { onOpen(chat.id) } label: {
                    ChatRow(chat: chat, isTyping: store.typing.contains(chat.id))
                }
                .buttonStyle(RowPressStyle())
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.white)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        withAnimation { store.setArchived(chat.id, false) }
                        model.showToast("Chat unarchived", icon: "tray.and.arrow.up")
                    } label: {
                        Label("Unarchive", systemImage: "tray.and.arrow.up.fill")
                    }
                    .tint(Color.tgBlue)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.white)
        .environment(\.defaultMinListRowHeight, 0)
        .overlay {
            if store.archivedChats.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "archivebox").font(.system(size: 44)).foregroundStyle(Color.tgGray)
                    Text("No archived chats").foregroundStyle(Color.tgGray)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            GlassHeader(onBack: { dismiss() }) {
                Text("Archived Chats").font(.system(size: 16, weight: .semibold))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Новое сообщение

struct NewMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    let store: ChatStore
    var onSelect: (Chat.ID) -> Void

    @State private var query = ""

    private var contacts: [Chat] {
        let people = store.people.sorted { $0.name < $1.name }
        return query.isEmpty ? people : people.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    action("person.2.fill", "New Group")
                    action("lock.fill", "New Secret Chat")
                    action("megaphone.fill", "New Channel")
                }
                Section("Contacts") {
                    ForEach(contacts) { contact in
                        Button { onSelect(contact.id) } label: {
                            HStack(spacing: 12) {
                                Avatar(chat: contact, size: 42)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(contact.name).foregroundStyle(.black)
                                    Text(contact.status)
                                        .font(.system(size: 14))
                                        .foregroundStyle(contact.isOnline ? Color.tgBlue : Color.tgGray)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query)
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func action(_ icon: String, _ title: String) -> some View {
        Button {
            model.showToast("\(title) is coming soon", icon: icon)
        } label: {
            Label(title, systemImage: icon).foregroundStyle(Color.tgBlue)
        }
    }
}

// MARK: - Истории

struct StoryViewer: View {
    @Environment(\.dismiss) private var dismiss

    struct Story {
        let image: String
        let name: String
        let caption: String
        let colors: [Color]
    }

    private let stories: [Story] = [
        Story(image: "avatar_bit16", name: "16Bit Team", caption: "We're live! Come watch 🍓",
              colors: [Color(hex: 0xFF5E7E), Color(hex: 0xFF9A6B)]),
        Story(image: "avatar_dog", name: "Dog", caption: "Found the lunch spot 🍝",
              colors: [Color(hex: 0x4FC3F7), Color(hex: 0x6A7CFF)]),
        Story(image: "avatar_pepe", name: "Pepe", caption: "Feels good man 🐸",
              colors: [Color(hex: 0x7ED957), Color(hex: 0x2FB37A)]),
    ]

    @State private var index = 0
    @State private var progress: Double = 0
    @State private var dragY: CGFloat = 0
    @State private var reply = ""
    @FocusState private var replyFocused: Bool

    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        let story = stories[index]
        ZStack {
            Color.black.ignoresSafeArea()

            ZStack {
                LinearGradient(colors: story.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                AssetImage(name: story.image)
                    .frame(width: 250, height: 250)
                    .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
                    .id(story.image)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                VStack {
                    Spacer()
                    Text(story.caption)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 8)
                        .padding(.bottom, 110)
                }
                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle()).onTapGesture { previous() }
                    Color.clear.contentShape(Rectangle()).onTapGesture { next() }
                }
                .padding(.vertical, 90)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(alignment: .top) { header(story) }
            .overlay(alignment: .bottom) { replyBar }
            .padding(.top, 4)
        }
        .offset(y: dragY)
        .scaleEffect(1 - dragY / 2000)
        .gesture(
            DragGesture()
                .onChanged { dragY = max(0, $0.translation.height) }
                .onEnded { value in
                    if value.translation.height > 120 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragY = 0 }
                    }
                }
        )
        .onReceive(timer) { _ in
            guard dragY == 0, !replyFocused else { return }
            progress += 0.03 / 4
            if progress >= 1 { next() }
        }
        .animation(.easeInOut(duration: 0.25), value: index)
        .statusBarHidden()
    }

    private func header(_ story: Story) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(stories.indices, id: \.self) { i in
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Color.white).frame(width: geo.size.width * fill(for: i))
                            }
                    }
                    .frame(height: 3)
                }
            }
            HStack(spacing: 10) {
                AssetImage(name: story.image).frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(story.name).font(.system(size: 15, weight: .semibold))
                    Text("2h ago").font(.system(size: 12)).opacity(0.8)
                }
                .foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .glass(Circle(), interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    private var replyBar: some View {
        HStack(spacing: 8) {
            TextField("Reply privately...", text: $reply)
                .focused($replyFocused)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 46)
                .glass(Capsule())
            CircleButton(systemName: "heart", size: 46, tint: .white)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private func fill(for i: Int) -> Double {
        i < index ? 1 : (i == index ? min(progress, 1) : 0)
    }

    private func next() {
        if index < stories.count - 1 {
            index += 1
            progress = 0
        } else {
            dismiss()
        }
    }

    private func previous() {
        if index > 0 { index -= 1 }
        progress = 0
    }
}
