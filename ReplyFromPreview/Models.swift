import SwiftUI
import Observation

struct Message: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var isOutgoing: Bool
    var time: String
}

struct Chat: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var emoji: String
    var color: Color
    var status: String
    var messages: [Message]
    var unread: Int = 0
    var isPinned: Bool = false
    var isMuted: Bool = false

    var lastMessage: Message? { messages.last }
}

@Observable
final class ChatStore {
    var chats: [Chat] = Chat.samples

    func chat(_ id: Chat.ID) -> Chat? {
        chats.first { $0.id == id }
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
        let target = chat.isPinned ? 0 : (chats.firstIndex { !$0.isPinned } ?? chats.count)
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
        formatter.dateFormat = "HH:mm"
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
}

extension Chat {
    static let samples: [Chat] = [
        Chat(
            name: "Cat", emoji: "😼", color: Color(hex: 0xF5873A), status: "last seen just now",
            messages: [
                Message(text: "Let's play Monopoly tonight?", isOutgoing: true, time: "9:30"),
                Message(text: "Advance to Illinois Ave. If you pass Go, collect coffee", isOutgoing: false, time: "9:38"),
                Message(text: "Passed!", isOutgoing: false, time: "9:39"),
                Message(text: "Okay", isOutgoing: true, time: "9:41"),
                Message(text: "Wait for me there.", isOutgoing: true, time: "9:41"),
                Message(text: "I'm already here ☕️", isOutgoing: false, time: "9:44"),
                Message(text: "Where are you?", isOutgoing: false, time: "9:45"),
            ],
            unread: 2, isPinned: true
        ),
        Chat(
            name: "Alicia Brown", emoji: "👩🏻‍🎨", color: Color(hex: 0xE0607E), status: "online",
            messages: [
                Message(text: "Did you see the new exhibition?", isOutgoing: false, time: "18:02"),
                Message(text: "Not yet! Is it worth it?", isOutgoing: true, time: "18:05"),
                Message(text: "Totally. The light installations are magic ✨", isOutgoing: false, time: "18:06"),
                Message(text: "Are you free tonight?", isOutgoing: false, time: "9:12"),
            ],
            unread: 1
        ),
        Chat(
            name: "Design Team", emoji: "🎨", color: Color(hex: 0x7B6CF6), status: "12 members",
            messages: [
                Message(text: "New icons are in Figma", isOutgoing: false, time: "8:40"),
                Message(text: "Can someone review the onboarding flow before lunch?", isOutgoing: false, time: "8:55"),
            ],
            unread: 5
        ),
        Chat(
            name: "Mom", emoji: "🌷", color: Color(hex: 0x4FBF6B), status: "last seen recently",
            messages: [
                Message(text: "Don't forget to call grandma", isOutgoing: false, time: "Wed"),
                Message(text: "Will do ❤️", isOutgoing: true, time: "Wed"),
            ]
        ),
        Chat(
            name: "Bake House", emoji: "🥐", color: Color(hex: 0xE8A93A), status: "channel",
            messages: [
                Message(text: "Lunch special: fresh pasta with basil, only today.", isOutgoing: false, time: "Tue"),
            ],
            unread: 3, isMuted: true
        ),
        Chat(
            name: "Max", emoji: "🧑🏽‍💻", color: Color(hex: 0x3E9BE0), status: "last seen yesterday",
            messages: [
                Message(text: "Sending you the build now", isOutgoing: false, time: "Mon"),
                Message(text: "Thanks!", isOutgoing: true, time: "Mon"),
            ]
        ),
    ]
}
