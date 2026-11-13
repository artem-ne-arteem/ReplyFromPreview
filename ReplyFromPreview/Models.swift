import SwiftUI
import Observation

struct Message: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var isOutgoing: Bool
    var time: String
    /// Видеосообщение-кружок: имя картинки и длительность.
    var video: String? = nil
    var duration: String? = nil
}

enum NameBadge: Hashable {
    case none
    case star
    case verified
    case emoji(String)
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
    var status: String
    var messages: [Message]
    var unread: Int = 0
    var isPinned = false
    var isMuted = false
    /// Имя автора последнего сообщения в группе.
    var sender: String? = nil
    /// Миниатюра вложения в превью последнего сообщения.
    var thumbnail: String? = nil
    var hasOpenButton = false
    var folders: Set<Folder> = []

    var lastMessage: Message? { messages.last }

    var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}

@Observable
final class ChatStore {
    var chats: [Chat] = Chat.samples

    func chat(_ id: Chat.ID) -> Chat? {
        chats.first { $0.id == id }
    }

    func chats(in folder: Folder) -> [Chat] {
        folder == .all ? chats : chats.filter { $0.folders.contains(folder) }
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

    /// Отправка сообщения: чат становится прочитанным и поднимается наверх списка.
    func send(_ text: String, to id: Chat.ID) {
        guard let index = chats.firstIndex(where: { $0.id == id }) else { return }
        var chat = chats.remove(at: index)
        chat.messages.append(Message(text: text, isOutgoing: true, time: Self.now()))
        chat.unread = 0
        chat.sender = nil
        chat.thumbnail = nil
        let target = chat.isPinned
            ? (chats.firstIndex { $0.isPinned } ?? 0)
            : (chats.firstIndex { !$0.isPinned } ?? chats.count)
        chats.insert(chat, at: target)
    }

    func togglePin(_ id: Chat.ID) {
        update(id) { $0.isPinned.toggle() }
        chats = chats.filter(\.isPinned) + chats.filter { !$0.isPinned }
    }

    func delete(_ id: Chat.ID) {
        chats.removeAll { $0.id == id }
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter
    }()

    static func now() -> String { formatter.string(from: .now) }
}

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

extension Chat {
    static let samples: [Chat] = [
        Chat(
            name: "Saved Messages", avatar: "avatar_saved", status: "your cloud storage",
            messages: [Message(text: "IMG_420.png", isOutgoing: false, time: "Fri")],
            isPinned: true, thumbnail: "thumb_img420"
        ),
        Chat(
            name: "Cat", avatar: "avatar_cat", badge: .star, status: "last seen just now",
            messages: [
                Message(text: "Advance to Illinois Ave. If you pass Go, collect coffee", isOutgoing: true, time: "9:38"),
                Message(text: "Passed!", isOutgoing: false, time: "9:41"),
                Message(text: "", isOutgoing: false, time: "9:41", video: "video_cat", duration: "0:04"),
                Message(text: "Okay", isOutgoing: true, time: "9:41"),
                Message(text: "Wait for me there.", isOutgoing: true, time: "9:41"),
                Message(text: "Pepe says hi.", isOutgoing: true, time: "9:41"),
            ],
            isPinned: true
        ),
        Chat(
            name: "Pepe", avatar: "avatar_pepe", badge: .emoji("status_pepe"), status: "online",
            messages: [
                Message(text: "Did you talk to Cat today?", isOutgoing: true, time: "9:30"),
                Message(text: "Say hello to Cat.", isOutgoing: false, time: "9:41"),
            ],
            unread: 1, folders: [.work]
        ),
        Chat(
            name: "16Bit Team", avatar: "avatar_bit16", status: "1,204 members",
            messages: [Message(text: "16Bit Team started a Live Stream", isOutgoing: false, time: "9:41")],
            unread: 1, isMuted: true, folders: [.groups]
        ),
        Chat(
            name: "Digital Nomads", avatar: "avatar_nomads", status: "2,500 members",
            messages: [Message(text: "We just reached 2,500 members! WOO!", isOutgoing: false, time: "9:22")],
            isMuted: true, sender: "Pepe", folders: [.groups]
        ),
        Chat(
            name: "Dog", avatar: "avatar_dog", badge: .emoji("status_dog"), status: "last seen recently",
            messages: [Message(text: "Table for four, 2 PM be there", isOutgoing: false, time: "9:12")]
        ),
        Chat(
            name: "Penguin", avatar: "avatar_penguin", status: "last seen 5 minutes ago",
            messages: [
                Message(text: "Got the photos from the trip?", isOutgoing: true, time: "8:20"),
                Message(text: "Check these out!", isOutgoing: false, time: "8:28"),
            ],
            unread: 1, folders: [.work]
        ),
        Chat(
            name: "Wallet", avatar: "avatar_wallet", badge: .verified, status: "bot",
            messages: [Message(text: "Welcome to Crypto Wallet!\n...", isOutgoing: false, time: "8:12")],
            unread: 1, hasOpenButton: true, folders: [.bots]
        ),
        Chat(
            name: "Alicia Brown", color: Color(hex: 0xF0648A), status: "online",
            messages: [Message(text: "Are you free tonight?", isOutgoing: false, time: "Thu")]
        ),
        Chat(
            name: "Design Team", color: Color(hex: 0x8E7CF8), status: "12 members",
            messages: [Message(text: "New icons are in Figma", isOutgoing: false, time: "Wed")],
            sender: "Max", folders: [.groups, .work]
        ),
        Chat(
            name: "Mom", color: Color(hex: 0x5BC86E), status: "last seen recently",
            messages: [Message(text: "Don't forget to call grandma ❤️", isOutgoing: false, time: "Tue")]
        ),
    ]
}
