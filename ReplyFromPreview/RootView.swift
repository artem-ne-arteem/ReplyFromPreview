import SwiftUI

enum Route: Hashable {
    case chat(Chat.ID)
    case profile(Chat.ID)
    case archive
    case settings(SettingsPage)
}

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

struct RootView: View {
    @State private var model = AppModel()

    var body: some View {
        RootContent()
            .environment(model)
            .preferredColorScheme(.light)
    }
}

struct RootContent: View {
    @Environment(AppModel.self) private var model

    @State private var path: [Route] = []
    @State private var tab: MainTab = .chats
    @State private var previewID: Chat.ID?
    @State private var previewFrame: CGRect = .zero
    @State private var frames = FrameStore()
    @State private var suppressTap = false
    @State private var editing = false
    @State private var selected: Set<Chat.ID> = []
    @State private var isSearching = false
    @State private var query = ""
    @State private var hapticTick = 0

    private var store: ChatStore { model.current.store }

    var body: some View {
        ZStack(alignment: .top) {
            NavigationStack(path: $path) {
                tabContent
                    .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: Route.self) { route in
                        destination(route)
                    }
            }

            if let previewID {
                ChatPreviewOverlay(
                    store: store,
                    chatID: previewID,
                    sourceFrame: previewFrame,
                    currentFrame: { frames.frames[previewID] },
                    onClose: {
                        self.previewID = nil
                        suppressTap = false
                    },
                    onOpen: {
                        path.append(.chat(previewID))
                        self.previewID = nil
                        suppressTap = false
                    }
                )
                .zIndex(1)
            }

            if let toast = model.toast {
                ToastView(toast: toast) {
                    toast.undo?()
                    withAnimation { model.toast = nil }
                }
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .fullScreenCover(item: Binding(get: { model.activeCall }, set: { model.activeCall = $0 })) { call in
            CallScreen(call: call)
                .environment(model)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTick)
        .sensoryFeedback(.impact(weight: .light), trigger: store.incomingTick)
        .onChange(of: model.currentID) {
            path = []
            editing = false
            selected = []
        }
    }

    // MARK: - Вкладки

    @ViewBuilder
    private var tabContent: some View {
        if isSearching {
            SearchView(store: store, query: query) { openChat($0) }
        } else {
            switch tab {
            case .chats:
                ChatsTab(
                    store: store, frames: frames, previewID: previewID,
                    editing: $editing, selected: $selected, suppressTap: $suppressTap,
                    onOpen: { openChat($0) },
                    onPreview: { showPreview($0) },
                    onArchive: { path.append(.archive) }
                )
            case .contacts:
                ContactsView(store: store) { path.append(.profile($0)) }
            case .calls:
                CallsView(store: store) { path.append(.profile($0)) }
            case .settings:
                SettingsView(
                    onNavigate: { path.append($0) },
                    onOpenChat: { openChat($0) },
                    onShowCalls: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = .calls } }
                )
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if editing, tab == .chats, !isSearching {
            EditActionBar(
                hasSelection: !selected.isEmpty,
                onRead: { readSelected() },
                onArchive: { archiveSelected() },
                onDelete: { deleteSelected() }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            BottomTabBar(selection: $tab, isSearching: $isSearching, query: $query, chatsBadge: store.totalUnread)
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .chat(let id):
            ChatScreen(store: store, chatID: id) { path.append(.profile($0)) }
        case .profile(let id):
            ProfileView(store: store, chatID: id) { messageFromProfile(id) }
        case .archive:
            ArchiveView(store: store) { path.append(.chat($0)) }
        case .settings(let page):
            SettingsDetailView(page: page)
        }
    }

    // MARK: - Действия

    private func openChat(_ id: Chat.ID) {
        if isSearching {
            withAnimation { isSearching = false }
            query = ""
        }
        path.append(.chat(id))
    }

    private func showPreview(_ id: Chat.ID) {
        guard previewID == nil, !editing else { return }
        suppressTap = true
        hapticTick += 1
        previewFrame = frames.frames[id] ?? .zero
        previewID = id
    }

    private func messageFromProfile(_ id: Chat.ID) {
        if path.count >= 2, path[path.count - 2] == .chat(id) {
            path.removeLast()
        } else {
            path.append(.chat(id))
        }
    }

    private func finishEditing() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            editing = false
            selected = []
        }
    }

    private func readSelected() {
        let ids = selected.isEmpty ? Set(store.visibleChats.map(\.id)) : selected
        withAnimation {
            for id in ids { store.update(id) { $0.unread = 0 } }
        }
        model.showToast(selected.isEmpty ? "All chats marked as read" : "Marked as read", icon: "envelope.open")
        finishEditing()
    }

    private func archiveSelected() {
        guard !selected.isEmpty else { return }
        let ids = selected
        withAnimation { for id in ids { store.setArchived(id, true) } }
        model.showToast(ids.count == 1 ? "Chat archived" : "\(ids.count) chats archived", icon: "archivebox") {
            withAnimation { for id in ids { store.setArchived(id, false) } }
        }
        finishEditing()
    }

    private func deleteSelected() {
        guard !selected.isEmpty else { return }
        let count = selected.count
        withAnimation { for id in selected { store.delete(id) } }
        model.showToast(count == 1 ? "Chat deleted" : "\(count) chats deleted", icon: "trash")
        finishEditing()
    }
}

// MARK: - Нижний таб-бар с поиском

struct BottomTabBar: View {
    @Binding var selection: MainTab
    @Binding var isSearching: Bool
    @Binding var query: String
    var chatsBadge: Int

    @FocusState private var searchFocused: Bool
    @Namespace private var glassNamespace
    @Namespace private var pillNamespace

    var body: some View {
        GlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                if isSearching {
                    Button { closeSearch() } label: {
                        Image(systemName: selection.icon)
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 56, height: 56)
                            .contentShape(Circle())
                            .glass(Circle(), interactive: true)
                            .glassID("tabs", in: glassNamespace)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.tgGray)
                        TextField("Search", text: $query)
                            .font(.system(size: 17))
                            .focused($searchFocused)
                            .submitLabel(.search)
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Color.tgGray)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 56)
                    .glass(Capsule())
                    .glassID("search", in: glassNamespace)
                } else {
                    tabs
                        .glass(Capsule())
                        .glassID("tabs", in: glassNamespace)

                    Button { openSearch() } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 62, height: 62)
                            .contentShape(Circle())
                            .glass(Circle(), interactive: true)
                            .glassID("search", in: glassNamespace)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, isSearching ? 14 : 22)
        .padding(.bottom, isSearching ? 6 : 0)
        .background(alignment: .bottom) {
            LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = tab }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 21, weight: .medium))
                            .frame(height: 26)
                            .overlay(alignment: .topTrailing) {
                                if tab == .chats, chatsBadge > 0 {
                                    Text("\(chatsBadge)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .contentTransition(.numericText())
                                        .padding(.horizontal, 5)
                                        .frame(minWidth: 18, minHeight: 18)
                                        .background(Capsule().fill(Color(hex: 0xFF3B30)))
                                        .offset(x: 13, y: -5)
                                }
                            }
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
                                .matchedGeometryEffect(id: "tab", in: pillNamespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
    }

    private func openSearch() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { isSearching = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { searchFocused = true }
    }

    private func closeSearch() {
        searchFocused = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            isSearching = false
            query = ""
        }
    }
}

/// Панель действий в режиме Edit.
struct EditActionBar: View {
    var hasSelection: Bool
    var onRead: () -> Void
    var onArchive: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack {
            Button(hasSelection ? "Read" : "Read All", action: onRead)
            Spacer()
            Button("Archive", action: onArchive)
                .disabled(!hasSelection)
            Spacer()
            Button("Delete", role: .destructive, action: onDelete)
                .disabled(!hasSelection)
        }
        .font(.system(size: 17, weight: .medium))
        .tint(Color.tgBlue)
        .padding(.horizontal, 26)
        .frame(height: 58)
        .glass(Capsule())
        .padding(.horizontal, 22)
        .animation(.easeOut(duration: 0.2), value: hasSelection)
    }
}

// MARK: - Поиск

struct SearchView: View {
    let store: ChatStore
    let query: String
    var onOpen: (Chat.ID) -> Void

    struct Hit: Identifiable {
        let chat: Chat
        let message: Message
        var id: UUID { message.id }
    }

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    private var chatHits: [Chat] {
        trimmed.isEmpty ? [] : store.chats.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private var messageHits: [Hit] {
        guard !trimmed.isEmpty else { return [] }
        return store.chats.flatMap { chat in
            chat.messages
                .filter { $0.text.localizedCaseInsensitiveContains(trimmed) }
                .map { Hit(chat: chat, message: $0) }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if trimmed.isEmpty {
                    SectionLabel(text: "Recent")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(store.people) { chat in
                                Button { onOpen(chat.id) } label: {
                                    VStack(spacing: 6) {
                                        Avatar(chat: chat, size: 60)
                                        Text(chat.name.split(separator: " ").first.map(String.init) ?? chat.name)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.black)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 66)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    SectionLabel(text: "Frequent").padding(.top, 8)
                    ForEach(store.visibleChats.prefix(6)) { chat in
                        compactRow(chat)
                    }
                } else {
                    if !chatHits.isEmpty {
                        SectionLabel(text: "Chats and Contacts")
                        ForEach(chatHits) { compactRow($0) }
                    }
                    if !messageHits.isEmpty {
                        SectionLabel(text: "Messages").padding(.top, 8)
                        ForEach(messageHits) { hit in
                            messageRow(hit)
                        }
                    }
                    if chatHits.isEmpty, messageHits.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").font(.system(size: 40))
                            Text("No results for “\(trimmed)”")
                        }
                        .foregroundStyle(Color.tgGray)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 90)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.white)
        .safeAreaInset(edge: .top, spacing: 0) {
            GlassHeader(pill: false) { TabTitle(text: "Search") }
        }
    }

    private func compactRow(_ chat: Chat) -> some View {
        Button { onOpen(chat.id) } label: {
            HStack(spacing: 12) {
                Avatar(chat: chat, size: 46)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Text(chat.name).font(.system(size: 17, weight: .medium)).foregroundStyle(.black)
                        NameBadgeView(badge: chat.badge, size: 14)
                    }
                    Text(chat.status)
                        .font(.system(size: 15))
                        .foregroundStyle(chat.isOnline ? Color.tgBlue : Color.tgGray)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
    }

    private func messageRow(_ hit: Hit) -> some View {
        Button { onOpen(hit.chat.id) } label: {
            HStack(spacing: 12) {
                Avatar(chat: hit.chat, size: 46)
                VStack(alignment: .leading, spacing: 1) {
                    HStack {
                        Text(hit.chat.name).font(.system(size: 17, weight: .medium)).foregroundStyle(.black)
                        Spacer()
                        Text(hit.message.time).font(.system(size: 14)).foregroundStyle(Color.tgGray)
                    }
                    highlighted(hit.message.text)
                        .font(.system(size: 15))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
    }

    private func highlighted(_ text: String) -> Text {
        var string = AttributedString(text)
        string.foregroundColor = Color.tgGray
        if let range = string.range(of: trimmed, options: .caseInsensitive) {
            string[range].foregroundColor = Color.tgBlue
        }
        return Text(string)
    }
}
