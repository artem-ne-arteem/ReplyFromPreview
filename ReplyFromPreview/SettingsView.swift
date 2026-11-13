import SwiftUI

enum SettingsPage: String, Hashable, CaseIterable, Identifiable {
    case devices = "Devices"
    case folders = "Chat Folders"
    case notifications = "Notifications and Sounds"
    case privacy = "Privacy and Security"
    case data = "Data and Storage"
    case appearance = "Appearance"
    case power = "Power Saving"
    case language = "Language"
    case premium = "Telegram Premium"
    case stars = "My Stars"
    case business = "Telegram Business"
    case gift = "Send a Gift"
    case ask = "Ask a Question"
    case faq = "Telegram FAQ"
    case features = "Telegram Features"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .devices: return "laptopcomputer.and.iphone"
        case .folders: return "folder.fill"
        case .notifications: return "bell.badge.fill"
        case .privacy: return "lock.fill"
        case .data: return "cylinder.split.1x2.fill"
        case .appearance: return "paintbrush.fill"
        case .power: return "battery.75percent"
        case .language: return "globe"
        case .premium: return "star.fill"
        case .stars: return "star.circle.fill"
        case .business: return "briefcase.fill"
        case .gift: return "gift.fill"
        case .ask: return "bubble.left.fill"
        case .faq: return "questionmark.circle.fill"
        case .features: return "lightbulb.fill"
        }
    }

    var color: Color {
        switch self {
        case .devices: return Color(hex: 0xFF9500)
        case .folders: return Color(hex: 0x32ADE6)
        case .notifications: return Color(hex: 0xFF3B30)
        case .privacy: return Color(hex: 0x8E8E93)
        case .data: return Color(hex: 0x34C759)
        case .appearance: return Color(hex: 0x5AC8FA)
        case .power: return Color(hex: 0xFF9500)
        case .language: return Color(hex: 0xAF52DE)
        case .premium: return Color(hex: 0x9B6BF2)
        case .stars: return Color(hex: 0xFFB800)
        case .business: return Color(hex: 0xFF6B3D)
        case .gift: return Color(hex: 0x30B0C7)
        case .ask: return Color(hex: 0xFF9500)
        case .faq: return Color(hex: 0x32ADE6)
        case .features: return Color(hex: 0xFFCC00)
        }
    }

    var blurb: String {
        switch self {
        case .stars: return "Use Stars to pay for digital goods and services in bots and mini apps."
        case .business: return "Turn your account into a business page with opening hours, location and quick replies."
        case .gift: return "Send gifts to your friends that they can display on their profile."
        case .ask: return "Please note that Telegram support is done by volunteers. We try to respond as quickly as possible."
        case .faq: return "Answers to the most common questions about Telegram."
        case .features: return "Tips and tricks to get the most out of Telegram."
        default: return ""
        }
    }
}

// MARK: - Вкладка «Настройки»

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    var onNavigate: (Route) -> Void
    var onOpenChat: (Chat.ID) -> Void
    var onShowCalls: () -> Void

    @State private var editingProfile = false
    @State private var addingAccount = false
    @State private var showQR = false

    var body: some View {
        let account = model.current
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    InitialsAvatar(initials: account.initials, color: account.color, size: 104)
                        .id(account.id)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                    Text(account.name)
                        .font(.system(size: 26, weight: .semibold))
                        .padding(.top, 4)
                    Text("\(account.phone) • @\(account.username)")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.tgGray)
                }

                GroupCard {
                    ForEach(model.accounts) { item in
                        SettingsRow(title: item.name, showsChevron: false) {
                            InitialsAvatar(initials: item.initials, color: item.color, size: 30)
                        } action: {
                            model.switchAccount(item.id)
                        }
                        .overlay(alignment: .trailing) {
                            if item.id == model.currentID {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.tgBlue)
                                    .padding(.trailing, 18)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    SettingsRow(title: "Add Account", titleColor: Color.tgBlue, showsChevron: false, isLast: true) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.tgBlue)
                            .frame(width: 30, height: 30)
                    } action: {
                        addingAccount = true
                    }
                }

                GroupCard {
                    row("person.crop.circle.fill", Color(hex: 0xFF3B30), "My Profile") { editingProfile = true }
                    row("bookmark.fill", Color.tgBlue, "Saved Messages") {
                        if let id = account.store.savedChatID { onOpenChat(id) }
                    }
                    row("phone.fill", Color(hex: 0x34C759), "Recent Calls", action: onShowCalls)
                    page(.devices, value: "3")
                    page(.folders, last: true)
                }

                GroupCard {
                    page(.notifications)
                    page(.privacy)
                    page(.data)
                    page(.appearance)
                    page(.power, value: model.isOn("power.mode") ? "On" : "Off")
                    page(.language, value: model.language, last: true)
                }

                GroupCard {
                    page(.premium)
                    page(.stars, value: "250")
                    page(.business)
                    page(.gift, last: true)
                }

                GroupCard {
                    page(.ask)
                    page(.faq)
                    page(.features, last: true)
                }

                Text("Telegram for iOS · Liquid Glass prototype")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.tgGray)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.currentID)
        }
        .background(Color.tgPinned)
        .safeAreaInset(edge: .top, spacing: 0) {
            TabHeader(fade: Color.tgPinned) {
                CircleButton(systemName: "qrcode") { showQR = true }
            } center: {
                EmptyView()
            } trailing: {
                CapsuleButton(title: "Edit") { editingProfile = true }
            }
        }
        .sheet(isPresented: $editingProfile) {
            EditProfileView(account: account)
                .environment(model)
        }
        .sheet(isPresented: $addingAccount) {
            AddAccountView()
                .environment(model)
        }
        .sheet(isPresented: $showQR) {
            QRView(account: account)
                .presentationDetents([.medium])
        }
    }

    private func row(_ icon: String, _ color: Color, _ title: String, last: Bool = false,
                     action: @escaping () -> Void) -> some View {
        SettingsRow(title: title, isLast: last) {
            IconSquare(systemName: icon, color: color)
        } action: {
            action()
        }
    }

    private func page(_ page: SettingsPage, value: String? = nil, last: Bool = false) -> some View {
        SettingsRow(title: page.rawValue, value: value, isLast: last) {
            IconSquare(systemName: page.icon, color: page.color)
        } action: {
            onNavigate(.settings(page))
        }
    }
}

// MARK: - Подстраницы настроек

struct SettingsDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let page: SettingsPage

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 30)
        }
        .background(Color.tgPinned)
        .safeAreaInset(edge: .top, spacing: 0) {
            GlassHeader(onBack: { dismiss() }, fade: Color.tgPinned) {
                Text(page.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .notifications:
            SectionLabel(text: "Message notifications")
            GroupCard {
                ToggleRow(title: "Private Chats", isOn: model.binding("n.private"))
                ToggleRow(title: "Groups", isOn: model.binding("n.groups"))
                ToggleRow(title: "Channels", isOn: model.binding("n.channels"))
                ToggleRow(title: "Stories", isOn: model.binding("n.stories"), isLast: true)
            }
            SectionLabel(text: "In-app notifications")
            GroupCard {
                ToggleRow(title: "In-App Sounds", isOn: model.binding("n.sounds"))
                ToggleRow(title: "In-App Vibrate", isOn: model.binding("n.vibrate"))
                ToggleRow(title: "In-App Preview", isOn: model.binding("n.preview"), isLast: true)
            }
            GroupCard {
                actionRow("Reset All Notifications", color: Color(hex: 0xFF3B30)) {
                    for key in ["n.private", "n.groups", "n.channels", "n.stories", "n.sounds", "n.vibrate", "n.preview"] {
                        model.toggles[key] = true
                    }
                    model.showToast("Notifications reset", icon: "bell")
                }
            }

        case .privacy:
            GroupCard {
                SettingsRow(title: "Blocked Users", value: "3") {
                    IconSquare(systemName: "hand.raised.fill", color: Color(hex: 0xFF3B30))
                } action: { stub("Blocked Users") }
                SettingsRow(title: "Passcode & Face ID", value: model.isOn("p.passcode") ? "On" : "Off") {
                    IconSquare(systemName: "faceid", color: Color(hex: 0x34C759))
                } action: { stub("Passcode") }
                SettingsRow(title: "Two-Step Verification", value: "Off", isLast: true) {
                    IconSquare(systemName: "key.fill", color: Color(hex: 0xFF9500))
                } action: { stub("Two-Step Verification") }
            }
            SectionLabel(text: "Privacy")
            GroupCard {
                privacyRow("Phone Number", "My Contacts")
                privacyRow("Last Seen & Online", "Everybody")
                privacyRow("Profile Photos", "Everybody")
                privacyRow("Forwarded Messages", "Everybody")
                privacyRow("Calls", "Everybody", last: true)
            }
            GroupCard {
                ToggleRow(title: "Passcode Lock", isOn: model.binding("p.passcode"))
                ToggleRow(title: "Sync Contacts", isOn: model.binding("p.sync"), isLast: true)
            }

        case .data:
            SectionLabel(text: "Storage")
            GroupCard {
                SettingsRow(title: "Storage Usage", value: "1.2 GB") {
                    IconSquare(systemName: "chart.pie.fill", color: Color.tgBlue)
                } action: { stub("Storage Usage") }
                SettingsRow(title: "Data Usage", value: "348 MB", isLast: true) {
                    IconSquare(systemName: "arrow.up.arrow.down", color: Color(hex: 0x34C759))
                } action: { stub("Data Usage") }
            }
            SectionLabel(text: "Automatic media download")
            GroupCard {
                ToggleRow(title: "Photos", isOn: model.binding("d.photos"))
                ToggleRow(title: "Videos", isOn: model.binding("d.videos"))
                ToggleRow(title: "Files", isOn: model.binding("d.files"), isLast: true)
            }
            GroupCard {
                actionRow("Clear Cache", color: Color(hex: 0xFF3B30)) {
                    model.showToast("Cache cleared — 1.2 GB freed", icon: "trash")
                }
            }

        case .appearance:
            SectionLabel(text: "Preview")
            ZStack {
                ChatWallpaper()
                VStack(spacing: 6) {
                    MessageBubble(message: Message(text: "Do you like the new look?", isOutgoing: false, time: "9:41"), showTail: true)
                    MessageBubble(message: Message(text: "Liquid Glass everywhere ✨", isOutgoing: true, time: "9:42"), showTail: true)
                }
                .padding(14)
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.messageFontSize)

            SectionLabel(text: "Text size")
            GroupCard {
                HStack(spacing: 12) {
                    Text("A").font(.system(size: 13))
                    Slider(value: Bindable(model).messageFontSize, in: 13...23, step: 1)
                        .tint(Color.tgBlue)
                    Text("A").font(.system(size: 23))
                }
                .padding(.horizontal, 16)
                .frame(height: 58)
            }
            GroupCard {
                ToggleRow(title: "Custom Wallpaper", isOn: Bindable(model).useCustomWallpaper)
                ToggleRow(title: "Auto-Night Mode", isOn: model.binding("a.night"))
                ToggleRow(title: "Animations", isOn: model.binding("a.animations"), isLast: true)
            }

        case .power:
            GroupCard {
                ToggleRow(title: "Power Saving Mode", isOn: model.binding("power.mode"), isLast: true)
            }
            SectionLabel(text: "Resource-intensive processes")
            GroupCard {
                ToggleRow(title: "Autoplay Videos", isOn: model.binding("power.video"))
                ToggleRow(title: "Animated Stickers", isOn: model.binding("power.stickers"))
                ToggleRow(title: "Animated Emoji", isOn: model.binding("power.emoji"))
                ToggleRow(title: "Interface Effects", isOn: model.binding("power.effects"), isLast: true)
            }

        case .language:
            let languages = ["English", "Русский", "Español", "Deutsch", "Français", "Italiano", "Português"]
            GroupCard {
                ForEach(languages, id: \.self) { language in
                    SettingsRow(title: language, showsChevron: false, isLast: language == languages.last) {
                        EmptyView()
                    } action: {
                        withAnimation(.easeOut(duration: 0.2)) { model.language = language }
                    }
                    .overlay(alignment: .trailing) {
                        if model.language == language {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.tgBlue)
                                .padding(.trailing, 18)
                        }
                    }
                }
            }

        case .devices:
            SectionLabel(text: "This device")
            GroupCard {
                SettingsRow(title: "iPhone · Telegram iOS", value: "online", showsChevron: false, isLast: true) {
                    IconSquare(systemName: "iphone", color: Color.tgBlue)
                }
            }
            GroupCard {
                actionRow("Terminate All Other Sessions", color: Color(hex: 0xFF3B30)) {
                    model.showToast("All other sessions terminated", icon: "xmark.shield")
                }
            }
            SectionLabel(text: "Active sessions")
            GroupCard {
                SettingsRow(title: "MacBook Air · macOS", value: "9:12", showsChevron: false) {
                    IconSquare(systemName: "laptopcomputer", color: Color(hex: 0x8E8E93))
                }
                SettingsRow(title: "Chrome · Telegram Web", value: "Yesterday", showsChevron: false, isLast: true) {
                    IconSquare(systemName: "globe", color: Color(hex: 0x34C759))
                }
            }

        case .folders:
            GroupCard {
                ForEach(Folder.allCases, id: \.self) { folder in
                    SettingsRow(title: folder.rawValue,
                                value: "\(model.current.store.chats(in: folder).count) chats",
                                isLast: folder == Folder.allCases.last) {
                        IconSquare(systemName: "folder.fill", color: Color(hex: 0x32ADE6))
                    } action: { stub(folder.rawValue) }
                }
            }
            GroupCard {
                actionRow("Create New Folder", color: Color.tgBlue) {
                    model.showToast("Folder editor is coming soon", icon: "folder.badge.plus")
                }
            }

        case .premium:
            VStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 66))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: 0x6B8CFF), Color(hex: 0xC86DD7), Color(hex: 0xFF8A65)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .padding(.top, 8)
                Text("Telegram Premium").font(.system(size: 26, weight: .bold))
                Text("Go beyond the limits, get exclusive features and support us by subscribing to Telegram Premium.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.tgGray)
                    .multilineTextAlignment(.center)
            }
            GroupCard {
                feature("arrow.up.circle.fill", Color(hex: 0xFF3B30), "Doubled Limits")
                feature("icloud.fill", Color(hex: 0xFF9500), "Unlimited Cloud Storage")
                feature("bolt.fill", Color(hex: 0xFFCC00), "Faster Download Speed")
                feature("waveform", Color(hex: 0x34C759), "Voice-to-Text Conversion")
                feature("nosign", Color(hex: 0x32ADE6), "No Ads")
                feature("face.smiling.inverse", Color(hex: 0xAF52DE), "Emoji Statuses", last: true)
            }
            Button {
                model.showToast("Prototype — no real purchases", icon: "star")
            } label: {
                Text("Subscribe for $4.99 per month")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Capsule())
                    .glass(Capsule(), tint: Color(hex: 0x9B6BF2), interactive: true)
            }
            .buttonStyle(.plain)

        default:
            VStack(spacing: 10) {
                Image(systemName: page.icon)
                    .font(.system(size: 56))
                    .foregroundStyle(page.color)
                    .padding(.top, 20)
                Text(page.rawValue).font(.system(size: 24, weight: .bold))
                Text(page.blurb)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.tgGray)
                    .multilineTextAlignment(.center)
            }
            GroupCard {
                actionRow("Learn More", color: Color.tgBlue) { stub(page.rawValue) }
            }
        }
    }

    private func stub(_ title: String) {
        model.showToast("\(title) — coming soon", icon: "hammer")
    }

    private func actionRow(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        SettingsRow(title: title, titleColor: color, showsChevron: false, isLast: true) {
            EmptyView()
        } action: {
            action()
        }
    }

    private func privacyRow(_ title: String, _ value: String, last: Bool = false) -> some View {
        SettingsRow(title: title, value: value, isLast: last) {
            EmptyView()
        } action: {
            stub(title)
        }
    }

    private func feature(_ icon: String, _ color: Color, _ title: String, last: Bool = false) -> some View {
        SettingsRow(title: title, showsChevron: false, isLast: last) {
            IconSquare(systemName: icon, color: color)
        }
    }
}

// MARK: - Листы

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    let account: Account

    @State private var name = ""
    @State private var username = ""
    @State private var bio = ""

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        InitialsAvatar(initials: initials, color: account.color, size: 92)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Name", text: $name)
                } footer: {
                    Text("Enter your name and add an optional profile photo.")
                }
                Section("Username") {
                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Bio") {
                    TextField("A few words about you", text: $bio, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        withAnimation {
                            account.name = name.trimmingCharacters(in: .whitespaces)
                            account.username = username.trimmingCharacters(in: .whitespaces)
                            account.bio = bio
                        }
                        model.showToast("Profile updated")
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = account.name
                username = account.username
                bio = account.bio
            }
        }
    }
}

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model

    @State private var name = ""
    @State private var phone = "+1 "

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Image(systemName: "paperplane.circle.fill")
                            .font(.system(size: 76))
                            .foregroundStyle(Color.tgBlue)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Your name", text: $name)
                    TextField("Phone number", text: $phone)
                        .keyboardType(.phonePad)
                } footer: {
                    Text("This is a prototype: no SMS will be sent.")
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log In") {
                        model.addAccount(name: name.trimmingCharacters(in: .whitespaces), phone: phone)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct QRView: View {
    let account: Account

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x7ED0F5), Color(hex: 0x5A8BF2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    Image(systemName: "qrcode")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 170, height: 170)
                        .foregroundStyle(Color(hex: 0x3B6FD8))
                    Text("@\(account.username.uppercased())")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(hex: 0x3B6FD8))
                }
                .padding(26)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.white))

                Text("Scan this code to open my profile")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }
}
