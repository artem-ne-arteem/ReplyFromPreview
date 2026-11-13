import SwiftUI

/// Профиль собеседника или группы.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let store: ChatStore
    let chatID: Chat.ID
    var onMessage: () -> Void

    @State private var mediaTab = 0
    @Namespace private var namespace

    var body: some View {
        if let chat = store.chat(chatID) {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Avatar(chat: chat, size: 112)
                        HStack(spacing: 4) {
                            Text(chat.name).font(.system(size: 25, weight: .semibold))
                            NameBadgeView(badge: chat.badge, size: 18)
                        }
                        .padding(.top, 6)
                        if store.typing.contains(chatID) {
                            TypingLabel(font: 15)
                        } else {
                            Text(chat.status)
                                .font(.system(size: 15))
                                .foregroundStyle(chat.isOnline ? Color.tgBlue : Color.tgGray)
                        }
                    }

                    actions(chat)
                    info(chat)
                    media
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(Color.tgPinned)
            .safeAreaInset(edge: .top, spacing: 0) {
                GlassHeader(onBack: { dismiss() }, pill: false, fade: Color.tgPinned) {
                    EmptyView()
                } trailing: {
                    CapsuleButton(title: "Edit") {
                        model.showToast("Editing contacts is coming soon", icon: "pencil")
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func actions(_ chat: Chat) -> some View {
        HStack(spacing: 8) {
            actionButton("message.fill", "Message", action: onMessage)
            actionButton(chat.isMuted ? "bell.fill" : "bell.slash.fill", chat.isMuted ? "Unmute" : "Mute") {
                withAnimation { store.toggleMute(chatID) }
                model.showToast(chat.isMuted ? "Notifications on" : "Notifications muted",
                                icon: chat.isMuted ? "bell" : "bell.slash")
            }
            if chat.kind == .person {
                actionButton("phone.fill", "Call") { model.startCall(chat) }
                actionButton("video.fill", "Video") { model.startCall(chat, video: true) }
            } else {
                actionButton("square.and.arrow.up", "Share") {
                    model.showToast("Link copied", icon: "link")
                }
            }
            actionButton("ellipsis", "More") {
                model.showToast("More options are coming soon", icon: "ellipsis.circle")
            }
        }
    }

    private func actionButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 20, weight: .medium))
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color.tgBlue)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
        }
        .buttonStyle(RowPressStyle())
    }

    @ViewBuilder
    private func info(_ chat: Chat) -> some View {
        let all: [(String, String, Color)] = [
            ("mobile", chat.phone, Color.tgBlue),
            ("username", chat.username.isEmpty ? "" : "@\(chat.username)", Color.tgBlue),
            ("bio", chat.bio, Color.black),
        ]
        let rows = all.filter { !$0.1.isEmpty }

        if !rows.isEmpty {
            GroupCard {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.0).font(.system(size: 14)).foregroundStyle(.black)
                        Text(row.1).font(.system(size: 17)).foregroundStyle(row.2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIPasteboard.general.string = row.1
                        model.showToast("Copied to clipboard", icon: "doc.on.doc")
                    }
                    if index < rows.count - 1 {
                        Rectangle().fill(Color.tgSeparator).frame(height: 0.5).padding(.leading, 16)
                    }
                }
            }
        }
    }

    private var media: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(Array(["Media", "Files", "Links", "Voice"].enumerated()), id: \.offset) { index, title in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { mediaTab = index }
                    } label: {
                        Text(title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background {
                                if mediaTab == index {
                                    Capsule()
                                        .fill(Color.black.opacity(0.07))
                                        .matchedGeometryEffect(id: "media", in: namespace)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .glass(Capsule())

            if mediaTab == 0 {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                    ForEach(0..<9, id: \.self) { index in
                        tile(index)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.opacity)
            } else {
                GroupCard {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 12) {
                            IconSquare(systemName: mediaIcon, color: Color.tgBlue)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(mediaTitle(index)).font(.system(size: 16)).foregroundStyle(.black)
                                Text("\(index + 2) days ago").font(.system(size: 14)).foregroundStyle(Color.tgGray)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 58)
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var mediaIcon: String {
        switch mediaTab {
        case 1: return "doc.fill"
        case 2: return "link"
        default: return "waveform"
        }
    }

    private func mediaTitle(_ index: Int) -> String {
        switch mediaTab {
        case 1: return ["Design_v3.fig", "Contract.pdf", "Photos.zip"][index]
        case 2: return ["telegram.org", "github.com", "figma.com"][index]
        default: return "Voice message 0:\(12 + index * 7)"
        }
    }

    private func tile(_ index: Int) -> some View {
        let images = ["video_cat", "thumb_img420", "Backgrounds"]
        let colors: [[Color]] = [
            [Color(hex: 0xFF9A8B), Color(hex: 0xFF6A88)],
            [Color(hex: 0x89F7FE), Color(hex: 0x66A6FF)],
            [Color(hex: 0xFDDB92), Color(hex: 0xD1FDFF)],
            [Color(hex: 0xC2E59C), Color(hex: 0x64B3F4)],
            [Color(hex: 0xA18CD1), Color(hex: 0xFBC2EB)],
            [Color(hex: 0xF6D365), Color(hex: 0xFDA085)],
        ]
        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if index < images.count, UIImage(named: images[index]) != nil {
                    AssetImage(name: images[index], fill: true)
                } else {
                    LinearGradient(colors: colors[index % colors.count], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .clipped()
    }
}
