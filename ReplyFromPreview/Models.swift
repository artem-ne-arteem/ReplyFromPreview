import SwiftUI
import Observation

// MARK: - Сообщения и чаты

enum MessageStatus: Hashable {
    case sending, sent, read
}

struct Message: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var isOutgoing: Bool
    var time: String
    /// Видеосообщение-кружок: имя картинки и длительность.
    var video: String? = nil
    var duration: String? = nil
    var status: MessageStatus = .read
    var reaction: String? = nil
    var replyAuthor: String? = nil
    var replyText: String? = nil

    var previewText: String { video != nil ? "Video message" : text }
}

enum NameBadge: Hashable {
    case none
    case star
    case verified
    case emoji(String)
}

enum ChatKind: Hashable {
    case person, group, channel, bot, saved
}

enum Folder: String, CaseIterable, Hashable {
    case all = "All"
    case groups = "Groups"
    case work = "WORK"
    case bots = "Bots"
}

struct Chat: Identifiable, Hashable {
    let id = UUID()
    var name: String
    /// Картинка аватара из Assets; без неё рисуются инициалы.
    var avatar: String? = nil
    var color: Color = .blue
    var badge: NameBadge = .none
    var kind: ChatKind = .person
    var status: String
    var messages: [Message]
    var unread: Int = 0
    var isPinned = false
    var isMuted = false
    var isArchived = false
    /// Имя автора последнего сообщения в группе.
    var sender: String? = nil
    /// Миниатюра вложения в превью последнего сообщения.
    var thumbnail: String? = nil
    var hasOpenButton = false
    var folders: Set<Folder> = []
    var phone: String = ""
    var username: String = ""
    var bio: String = ""

    var lastMessage: Message? { messages.last }
    var canReply: Bool { kind == .person || kind == .bot || kind == .group }
    var isOnline: Bool { status == "online" }

    var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}

// MARK: - Хранилище чатов одного аккаунта

@Observable
final class ChatStore {
    var chats: [Chat]
    /// Кто сейчас «печатает».
    var typing: Set<Chat.ID> = []
    /// Открытый сейчас чат: в него входящие приходят без счётчика.
    var openChatID: Chat.ID?
    /// Растёт при каждом входящем сообщении — для вибрации.
    var incomingTick = 0

    init(chats: [Chat]) {
        self.chats = chats
    }

    func chat(_ id: Chat.ID) -> Chat? {
        chats.first { $0.id == id }
    }

    var visibleChats: [Chat] { chats.filter { !$0.isArchived && !$0.messages.isEmpty } }
    var archivedChats: [Chat] { chats.filter(\.isArchived) }
    var people: [Chat] { chats.filter { $0.kind == .person } }
    var savedChatID: Chat.ID? { chats.first { $0.kind == .saved }?.id }

    var totalUnread: Int {
        visibleChats.filter { !$0.isMuted }.reduce(0) { $0 + $1.unread }
    }

    func chats(in folder: Folder) -> [Chat] {
        folder == .all ? visibleChats : visibleChats.filter { $0.folders.contains(folder) }
    }

    /// Сколько непрочитанных в папке и все ли они в чатах без звука.
    func badge(for folder: Folder) -> (count: Int, muted: Bool) {
        let list = chats(in: folder).filter { $0.unread > 0 }
        return (list.reduce(0) { $0 + $1.unread }, list.allSatisfy(\.isMuted))
    }

    func update(_ id: Chat.ID, _ change: (inout Chat) -> Void) {
        guard let index = chats.firstIndex(where: { $0.id == id }) else { return }
        change(&chats[index])
    }

    func moveToTop(_ id: Chat.ID) {
        guard let index = chats.firstIndex(where: { $0.id == id }) else { return }
        let chat = chats.remove(at: index)
        let target = chat.isPinned
            ? (chats.firstIndex { $0.isPinned } ?? 0)
            : (chats.firstIndex { !$0.isPinned } ?? chats.count)
        chats.insert(chat, at: target)
    }

    /// Отправка: часики → одна галочка → (после ответа) две галочки.
    func send(_ text: String, to id: Chat.ID, replyTo: Message? = nil) {
        guard let index = chats.firstIndex(where: { $0.id == id }) else { return }
        var message = Message(text: text, isOutgoing: true, time: Self.now(), status: .sending)
        if let replyTo {
            message.replyAuthor = replyTo.isOutgoing ? "You" : chats[index].name
            message.replyText = replyTo.previewText
        }
        let messageID = message.id
        let isSaved = chats[index].kind == .saved
        chats[index].messages.append(message)
        chats[index].unread = 0
        chats[index].sender = nil
        chats[index].thumbnail = nil
        chats[index].isArchived = false
        moveToTop(id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            withAnimation(.easeOut(duration: 0.2)) {
                self?.setStatus(isSaved ? .read : .sent, message: messageID, in: id)
            }
        }
        scheduleReply(for: id)
    }

    private func setStatus(_ status: MessageStatus, message: Message.ID, in chatID: Chat.ID) {
        update(chatID) { chat in
            if let i = chat.messages.firstIndex(where: { $0.id == message }) {
                chat.messages[i].status = status
            }
        }
    }

    /// Собеседник «читает», печатает и отвечает.
    private func scheduleReply(for chatID: Chat.ID) {
        guard let chat = chat(chatID), chat.canReply, !typing.contains(chatID) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            guard let self, !self.typing.contains(chatID) else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.update(chatID) { chat in
                    for i in chat.messages.indices where chat.messages[i].isOutgoing {
                        chat.messages[i].status = .read
                    }
                }
                _ = self.typing.insert(chatID)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.6...2.8)) { [weak self] in
                self?.deliverReply(to: chatID)
            }
        }
    }

    private func deliverReply(to chatID: Chat.ID) {
        guard let index = chats.firstIndex(where: { $0.id == chatID }) else {
            typing.remove(chatID)
            return
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            typing.remove(chatID)
            let text = Self.replies.randomElement() ?? "👍"
            chats[index].messages.append(Message(text: text, isOutgoing: false, time: Self.now()))
            if chats[index].kind == .group {
                chats[index].sender = ["Pepe", "Dog", "Penguin"].randomElement()
            }
            if openChatID != chatID {
                chats[index].unread += 1
            }
            moveToTop(chatID)
        }
        incomingTick += 1
    }

    func togglePin(_ id: Chat.ID) {
        update(id) { $0.isPinned.toggle() }
        chats = chats.filter(\.isPinned) + chats.filter { !$0.isPinned }
    }

    func toggleMute(_ id: Chat.ID) {
        update(id) { $0.isMuted.toggle() }
    }

    func toggleRead(_ id: Chat.ID) {
        update(id) { $0.unread = $0.unread > 0 ? 0 : 1 }
    }

    func setArchived(_ id: Chat.ID, _ archived: Bool) {
        update(id) { chat in
            chat.isArchived = archived
            if archived { chat.isPinned = false }
        }
    }

    @discardableResult
    func delete(_ id: Chat.ID) -> (chat: Chat, index: Int)? {
        guard let index = chats.firstIndex(where: { $0.id == id }) else { return nil }
        typing.remove(id)
        return (chats.remove(at: index), index)
    }

    func restore(_ chat: Chat, at index: Int) {
        chats.insert(chat, at: min(index, chats.count))
    }

    func react(_ emoji: String, message: Message.ID, in chatID: Chat.ID) {
        update(chatID) { chat in
            if let i = chat.messages.firstIndex(where: { $0.id == message }) {
                chat.messages[i].reaction = chat.messages[i].reaction == emoji ? nil : emoji
            }
        }
    }

    func deleteMessage(_ message: Message.ID, in chatID: Chat.ID) {
        update(chatID) { $0.messages.removeAll { $0.id == message } }
    }

    func addContact(name: String, phone: String) -> Chat.ID {
        let colors: [UInt32] = [0xF0648A, 0x8E7CF8, 0x5BC86E, 0xF5A04B, 0x4FA8E8, 0xE5605A]
        let chat = Chat(name: name, color: Color(hex: colors.randomElement() ?? 0x4FA8E8),
                        status: "last seen recently", messages: [], phone: phone)
        chats.append(chat)
        return chat.id
    }

    static let replies = [
        "Haha 😄", "Sounds good!", "On my way 🏃", "👍", "Really? Tell me more",
        "Let's do it!", "Can't wait ✨", "Sure, why not", "Ok, see you there",
        "Wow 🔥", "I'll check and let you know", "😂😂😂",
    ]

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter
    }()

    static func now() -> String { formatter.string(from: .now) }
}

// MARK: - Аккаунты, звонки, настройки

struct CallRecord: Identifiable, Hashable {
    let id = UUID()
    var chatID: Chat.ID
    var outgoing: Bool
    var missed: Bool
    var video: Bool
    var time: String
    var count: Int = 1
}

struct ActiveCall: Identifiable {
    let id = UUID()
    let chat: Chat
    let video: Bool
}

struct Toast: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
    let undo: (() -> Void)?
}

@Observable
final class Account: Identifiable {
    let id = UUID()
    var name: String
    var phone: String
    var username: String
    var bio: String
    var color: Color
    let store: ChatStore
    var calls: [CallRecord]

    init(name: String, phone: String, username: String, bio: String, color: Color, chats: [Chat]) {
        self.name = name
        self.phone = phone
        self.username = username
        self.bio = bio
        self.color = color
        self.store = ChatStore(chats: chats)
        self.calls = Account.sampleCalls(for: chats)
    }

    var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    private static func sampleCalls(for chats: [Chat]) -> [CallRecord] {
        let people = chats.filter { $0.kind == .person }
        guard !people.isEmpty else { return [] }
        let specs: [(outgoing: Bool, missed: Bool, video: Bool, time: String, count: Int)] = [
            (false, true, false, "9:30", 2),
            (true, false, false, "Yesterday", 1),
            (false, false, true, "Wed", 1),
            (true, false, false, "Tue", 1),
            (false, true, false, "Mon", 1),
            (true, false, true, "Sun", 3),
        ]
        return specs.enumerated().map { index, spec in
            CallRecord(chatID: people[index % people.count].id, outgoing: spec.outgoing,
                       missed: spec.missed, video: spec.video, time: spec.time, count: spec.count)
        }
    }
}

@Observable
final class AppModel {
    var accounts: [Account]
    var currentID: Account.ID
    var messageFontSize: Double = 17
    var useCustomWallpaper = true
    var language = "English"
    var toggles: [String: Bool] = [:]
    var toast: Toast?
    var activeCall: ActiveCall?

    init() {
        let main = Account(name: "Alex Morgan", phone: "+1 555 012 3456", username: "alexmorgan",
                           bio: "Designer. Coffee. Telegram.", color: Color(hex: 0x5AA9F8),
                           chats: Chat.makeSamples())
        let work = Account(name: "Alex Work", phone: "+1 555 987 6543", username: "alex_work",
                           bio: "", color: Color(hex: 0xF5A04B), chats: Chat.makeStarter())
        accounts = [main, work]
        currentID = main.id
    }

    var current: Account {
        accounts.first { $0.id == currentID } ?? accounts[0]
    }

    func isOn(_ key: String) -> Bool { toggles[key, default: true] }

    func binding(_ key: String) -> Binding<Bool> {
        Binding(get: { self.toggles[key, default: true] }, set: { self.toggles[key] = $0 })
    }

    func switchAccount(_ id: Account.ID) {
        guard id != currentID, let account = accounts.first(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { currentID = id }
        showToast("Switched to \(account.name)", icon: "person.crop.circle.badge.checkmark")
    }

    func addAccount(name: String, phone: String) {
        let colors: [UInt32] = [0x8E7CF8, 0x5BC86E, 0xF0648A, 0x4FA8E8]
        let username = name.lowercased().replacingOccurrences(of: " ", with: "_")
        let account = Account(name: name, phone: phone, username: username, bio: "",
                              color: Color(hex: colors.randomElement() ?? 0x4FA8E8), chats: Chat.makeStarter())
        accounts.append(account)
        switchAccount(account.id)
    }

    func startCall(_ chat: Chat, video: Bool = false) {
        activeCall = ActiveCall(chat: chat, video: video)
    }

    func finishCall(_ call: ActiveCall) {
        let record = CallRecord(chatID: call.chat.id, outgoing: true, missed: false,
                                video: call.video, time: ChatStore.now())
        current.calls.insert(record, at: 0)
    }

    func showToast(_ text: String, icon: String = "checkmark.circle.fill", undo: (() -> Void)? = nil) {
        let toast = Toast(text: text, icon: icon, undo: undo)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { self.toast = toast }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.toast?.id == toast.id else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.toast = nil }
        }
    }
}

// MARK: - Цвета

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static let tgBlue = Color(hex: 0x007AFF)
    static let tgGray = Color(hex: 0x8E8E93)
    static let tgSeparator = Color(hex: 0xD9D9DE)
    static let tgPinned = Color(hex: 0xF2F2F7)
    static let tgOutgoing = Color(hex: 0xEFFEDD)
}

// MARK: - Демо-данные

extension Chat {
    static func makeSamples() -> [Chat] {
        [
            Chat(
                name: "Saved Messages", avatar: "avatar_saved", kind: .saved, status: "your cloud storage",
                messages: [Message(text: "IMG_420.png", isOutgoing: false, time: "Fri")],
                isPinned: true, thumbnail: "thumb_img420"
            ),
            Chat(
                name: "Cat", avatar: "avatar_cat", badge: .star, status: "online",
                messages: [
                    Message(text: "Advance to Illinois Ave. If you pass Go, collect coffee", isOutgoing: true, time: "9:38"),
                    Message(text: "Passed!", isOutgoing: false, time: "9:41"),
                    Message(text: "", isOutgoing: false, time: "9:41", video: "video_cat", duration: "0:04"),
                    Message(text: "Okay", isOutgoing: true, time: "9:41"),
                    Message(text: "Wait for me there.", isOutgoing: true, time: "9:41"),
                    Message(text: "Pepe says hi.", isOutgoing: true, time: "9:41"),
                ],
                isPinned: true, phone: "+1 555 010 2030", username: "cat", bio: "Professional napper 😼"
            ),
            Chat(
                name: "Pepe", avatar: "avatar_pepe", badge: .emoji("status_pepe"), status: "online",
                messages: [
                    Message(text: "Did you talk to Cat today?", isOutgoing: true, time: "9:30"),
                    Message(text: "Say hello to Cat.", isOutgoing: false, time: "9:41"),
                ],
                unread: 1, folders: [.work], phone: "+1 555 010 4455", username: "pepe", bio: "Feels good man"
            ),
            Chat(
                name: "16Bit Team", avatar: "avatar_bit16", kind: .channel, status: "1,204 subscribers",
                messages: [Message(text: "16Bit Team started a Live Stream", isOutgoing: false, time: "9:41")],
                unread: 1, isMuted: true, folders: [.groups], username: "bit16team", bio: "Pixel art & retro games"
            ),
            Chat(
                name: "Digital Nomads", avatar: "avatar_nomads", kind: .group, status: "2,500 members",
                messages: [Message(text: "We just reached 2,500 members! WOO!", isOutgoing: false, time: "9:22")],
                isMuted: true, sender: "Pepe", folders: [.groups], username: "nomads", bio: "Work from anywhere 🌍"
            ),
            Chat(
                name: "Dog", avatar: "avatar_dog", badge: .emoji("status_dog"), status: "last seen recently",
                messages: [Message(text: "Table for four, 2 PM be there", isOutgoing: false, time: "9:12")],
                phone: "+1 555 010 7788", username: "dog", bio: "Good boy"
            ),
            Chat(
                name: "Penguin", avatar: "avatar_penguin", status: "last seen 5 minutes ago",
                messages: [
                    Message(text: "Got the photos from the trip?", isOutgoing: true, time: "8:20"),
                    Message(text: "Check these out!", isOutgoing: false, time: "8:28"),
                ],
                unread: 1, folders: [.work], phone: "+1 555 010 9900", username: "penguin", bio: "Antarctica 🧊"
            ),
            Chat(
                name: "Wallet", avatar: "avatar_wallet", badge: .verified, kind: .bot, status: "bot",
                messages: [Message(text: "Welcome to Crypto Wallet!\n...", isOutgoing: false, time: "8:12")],
                unread: 1, hasOpenButton: true, folders: [.bots], username: "wallet", bio: "Buy, sell and store crypto."
            ),
            Chat(
                name: "Alicia Brown", color: Color(hex: 0xF0648A), status: "online",
                messages: [Message(text: "Are you free tonight?", isOutgoing: false, time: "Thu")],
                phone: "+1 555 011 1234", username: "alicia", bio: "Light installations ✨"
            ),
            Chat(
                name: "Design Team", color: Color(hex: 0x8E7CF8), kind: .group, status: "12 members",
                messages: [Message(text: "New icons are in Figma", isOutgoing: false, time: "Wed")],
                sender: "Max", folders: [.groups, .work]
            ),
            Chat(
                name: "Mom", color: Color(hex: 0x5BC86E), status: "last seen recently",
                messages: [Message(text: "Don't forget to call grandma ❤️", isOutgoing: false, time: "Tue")],
                phone: "+1 555 011 0001"
            ),
            Chat(
                name: "Max Ivanov", color: Color(hex: 0x4FA8E8), status: "last seen yesterday",
                messages: [Message(text: "Sent you the build", isOutgoing: false, time: "Mon")],
                isArchived: true, phone: "+1 555 011 7654", username: "max"
            ),
        ]
    }

    static func makeStarter() -> [Chat] {
        [
            Chat(
                name: "Saved Messages", avatar: "avatar_saved", kind: .saved, status: "your cloud storage",
                messages: [Message(text: "Forward messages here to save them", isOutgoing: false, time: "Mon")],
                isPinned: true
            ),
            Chat(
                name: "Design Team", color: Color(hex: 0x8E7CF8), kind: .group, status: "12 members",
                messages: [Message(text: "Standup in 5 minutes", isOutgoing: false, time: "9:55")],
                unread: 3, sender: "Max", folders: [.groups, .work]
            ),
            Chat(
                name: "Alicia Brown", color: Color(hex: 0xF0648A), status: "online",
                messages: [Message(text: "Sent the contract 📄", isOutgoing: false, time: "9:40")],
                unread: 1, folders: [.work], phone: "+1 555 011 1234", username: "alicia"
            ),
            Chat(
                name: "Penguin", avatar: "avatar_penguin", status: "last seen recently",
                messages: [Message(text: "Meeting moved to 3 PM", isOutgoing: true, time: "Yesterday")],
                folders: [.work], phone: "+1 555 010 9900", username: "penguin"
            ),
        ]
    }
}
