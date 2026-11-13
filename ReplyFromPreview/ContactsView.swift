import SwiftUI

// MARK: - Контакты

struct ContactsView: View {
    @Environment(AppModel.self) private var model
    let store: ChatStore
    var onOpenProfile: (Chat.ID) -> Void

    @State private var sortByName = false
    @State private var adding = false

    private var contacts: [Chat] {
        let people = store.people
        if sortByName {
            return people.sorted { $0.name < $1.name }
        }
        return people.sorted { ($0.isOnline ? 0 : 1) < ($1.isOnline ? 0 : 1) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                actionRow("person.badge.plus", "Invite Friends") {
                    model.showToast("Invite link copied", icon: "link")
                }
                actionRow("location.circle", "Find People Nearby") {
                    model.showToast("Looking for people nearby…", icon: "location")
                }
                SectionLabel(text: sortByName ? "Sorted by name" : "Sorted by last seen time")
                    .padding(.bottom, 6)
                ForEach(contacts) { contact in
                    Button { onOpenProfile(contact.id) } label: {
                        ContactRow(chat: contact)
                    }
                    .buttonStyle(RowPressStyle())
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: sortByName)
        }
        .background(Color.white)
        .safeAreaInset(edge: .top, spacing: 0) {
            TabHeader {
                CapsuleButton(title: "Sort") { sortByName.toggle() }
            } center: {
                TabTitle(text: "Contacts")
            } trailing: {
                CircleButton(systemName: "plus") { adding = true }
            }
        }
        .sheet(isPresented: $adding) {
            AddContactView(store: store)
                .environment(model)
        }
    }

    private func actionRow(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.tgBlue)
                    .frame(width: 46)
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(Color.tgBlue)
                Spacer()
            }
            .padding(.leading, 16)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
    }
}

struct ContactRow: View {
    let chat: Chat

    var body: some View {
        HStack(spacing: 12) {
            Avatar(chat: chat, size: 46)
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 3) {
                            Text(chat.name)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.black)
                            NameBadgeView(badge: chat.badge, size: 14)
                        }
                        Text(chat.status)
                            .font(.system(size: 15))
                            .foregroundStyle(chat.isOnline ? Color.tgBlue : Color.tgGray)
                    }
                    Spacer()
                }
                .frame(maxHeight: .infinity)
                Rectangle().fill(Color.tgSeparator).frame(height: 0.5)
            }
        }
        .padding(.leading, 16)
        .frame(height: 62)
        .contentShape(Rectangle())
    }
}

struct AddContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    let store: ChatStore

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                }
                Section {
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let name = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
                        _ = store.addContact(name: name, phone: phone)
                        model.showToast("\(name) added to contacts", icon: "person.crop.circle.badge.checkmark")
                        dismiss()
                    }
                    .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Звонки

struct CallsView: View {
    @Environment(AppModel.self) private var model
    let store: ChatStore
    var onOpenProfile: (Chat.ID) -> Void

    @State private var missedOnly = false
    @State private var editing = false
    @State private var picking = false
    @Namespace private var namespace

    private var calls: [CallRecord] {
        model.current.calls.filter { !missedOnly || $0.missed }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Button { picking = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "phone.badge.plus")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.tgBlue)
                            .frame(width: 46)
                        Text("Start New Call")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.tgBlue)
                        Spacer()
                    }
                    .padding(.leading, 16)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RowPressStyle())

                SectionLabel(text: "Recent Calls").padding(.bottom, 6)

                ForEach(calls) { call in
                    if let chat = store.chat(call.chatID) {
                        CallRow(
                            call: call, chat: chat, editing: editing,
                            onTap: { model.startCall(chat, video: call.video) },
                            onInfo: { onOpenProfile(chat.id) },
                            onDelete: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    model.current.calls.removeAll { $0.id == call.id }
                                }
                            }
                        )
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }

                if calls.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "phone.down").font(.system(size: 40))
                        Text(missedOnly ? "No missed calls" : "No recent calls")
                    }
                    .foregroundStyle(Color.tgGray)
                    .padding(.top, 70)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: missedOnly)
        }
        .background(Color.white)
        .safeAreaInset(edge: .top, spacing: 0) {
            TabHeader {
                CapsuleButton(title: editing ? "Done" : "Edit", tint: editing ? Color.tgBlue : .primary) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { editing.toggle() }
                }
            } center: {
                segmented
            } trailing: {
                CircleButton(systemName: "phone.badge.plus") { picking = true }
            }
        }
        .sheet(isPresented: $picking) {
            CallPickerView(store: store) { chat in
                picking = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { model.startCall(chat) }
            }
        }
    }

    private var segmented: some View {
        HStack(spacing: 0) {
            ForEach([false, true], id: \.self) { missed in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { missedOnly = missed }
                } label: {
                    Text(missed ? "Missed" : "All")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 76, height: 38)
                        .background {
                            if missedOnly == missed {
                                Capsule()
                                    .fill(Color.black.opacity(0.07))
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .glass(Capsule())
    }
}

struct CallRow: View {
    let call: CallRecord
    let chat: Chat
    let editing: Bool
    var onTap: () -> Void
    var onInfo: () -> Void
    var onDelete: () -> Void

    private var icon: String {
        if call.video { return "video.fill" }
        return call.outgoing ? "phone.arrow.up.right.fill" : "phone.arrow.down.left.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            if editing {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white, Color(hex: 0xFF3B30))
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            Avatar(chat: chat, size: 46)
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chat.name + (call.count > 1 ? " (\(call.count))" : ""))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(call.missed ? Color(hex: 0xFF3B30) : Color.black)
                        HStack(spacing: 4) {
                            Image(systemName: icon).font(.system(size: 12))
                            Text(call.missed ? "Missed" : (call.outgoing ? "Outgoing" : "Incoming"))
                                .font(.system(size: 15))
                        }
                        .foregroundStyle(Color.tgGray)
                    }
                    Spacer()
                    Text(call.time)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.tgGray)
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.tgBlue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 16)
                .frame(maxHeight: .infinity)
                Rectangle().fill(Color.tgSeparator).frame(height: 0.5)
            }
        }
        .padding(.leading, 16)
        .frame(height: 62)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct CallPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let store: ChatStore
    var onPick: (Chat) -> Void

    var body: some View {
        NavigationStack {
            List(store.people) { chat in
                Button { onPick(chat) } label: {
                    HStack(spacing: 12) {
                        Avatar(chat: chat, size: 42)
                        Text(chat.name).foregroundStyle(.black)
                        Spacer()
                        Image(systemName: "phone.fill").foregroundStyle(Color.tgBlue)
                    }
                }
            }
            .navigationTitle("New Call")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
