import SwiftUI
import UIKit

// MARK: - Стекло

extension View {
    /// Liquid Glass на iOS 26, на старых версиях — материал с обводкой.
    @ViewBuilder
    func glass<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            self
                .background {
                    if let tint {
                        shape.fill(tint)
                    } else {
                        shape.fill(.regularMaterial)
                    }
                }
                .overlay(shape.stroke(Color.white.opacity(0.6), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        }
    }

    /// Связывает стеклянные элементы, чтобы на iOS 26 они перетекали друг в друга.
    @ViewBuilder
    func glassID(_ id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
}

/// Группа стеклянных элементов: на iOS 26 они «сливаются» и перетекают друг в друга.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

struct CircleButton: View {
    let systemName: String
    var size: CGFloat = 44
    var tint: Color = .primary
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .contentShape(Circle())
                .glass(Circle(), interactive: true)
        }
        .buttonStyle(.plain)
    }
}

struct CapsuleButton: View {
    let title: String
    var tint: Color = .primary
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(tint)
                .padding(.horizontal, 15)
                .frame(height: 44)
                .contentShape(Capsule())
                .glass(Capsule(), interactive: true)
        }
        .buttonStyle(.plain)
    }
}

/// Стеклянная шапка экрана: кнопка «назад», центр и правая часть.
struct GlassHeader<Center: View, Trailing: View>: View {
    var onBack: (() -> Void)?
    var pill: Bool
    var fade: Color?
    let center: Center
    let trailing: Trailing

    init(onBack: (() -> Void)? = nil, pill: Bool = true, fade: Color? = .white,
         @ViewBuilder center: () -> Center, @ViewBuilder trailing: () -> Trailing) {
        self.onBack = onBack
        self.pill = pill
        self.fade = fade
        self.center = center()
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            HStack {
                if let onBack {
                    CircleButton(systemName: "chevron.left", size: 44, action: onBack)
                }
                Spacer()
                trailing
            }
            if pill {
                center
                    .padding(.horizontal, 22)
                    .frame(height: 44)
                    .glass(Capsule())
            } else {
                center
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(alignment: .top) {
            if let fade {
                LinearGradient(colors: [fade, fade.opacity(0.85), fade.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
            }
        }
    }
}

extension GlassHeader where Trailing == EmptyView {
    init(onBack: (() -> Void)? = nil, pill: Bool = true, fade: Color? = .white,
         @ViewBuilder center: () -> Center) {
        self.init(onBack: onBack, pill: pill, fade: fade, center: center, trailing: { EmptyView() })
    }
}

/// Заголовок экрана-вкладки, как в Telegram.
struct TabTitle: View {
    let text: String

    var body: some View {
        Text(text).font(.system(size: 19, weight: .semibold))
    }
}

// Свайп «назад» работает и при скрытой системной панели навигации.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

// MARK: - Картинки и аватары

struct AssetImage: View {
    let name: String
    var fill = false

    var body: some View {
        if let image = UIImage(named: name) {
            if fill {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(uiImage: image).resizable().scaledToFit()
            }
        } else {
            Color.clear
        }
    }
}

struct Avatar: View {
    let chat: Chat
    var size: CGFloat = 64

    var body: some View {
        if let name = chat.avatar, UIImage(named: name) != nil {
            AssetImage(name: name)
                .frame(width: size, height: size)
        } else {
            InitialsAvatar(initials: chat.initials, color: chat.color, size: size)
        }
    }
}

struct InitialsAvatar: View {
    let initials: String
    let color: Color
    var size: CGFloat = 64

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .top, endPoint: .bottom))
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .padding(size * 0.03)
            .frame(width: size, height: size)
    }
}

struct NameBadgeView: View {
    let badge: NameBadge
    var size: CGFloat = 16

    var body: some View {
        switch badge {
        case .none:
            EmptyView()
        case .star:
            Image(systemName: "star.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Color.tgBlue)
        case .verified:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: size))
                .foregroundStyle(.white, Color.tgBlue)
        case .emoji(let name):
            AssetImage(name: name)
                .frame(width: size + 6, height: size + 6)
        }
    }
}

/// Три прыгающие точки «печатает…».
struct TypingDots: View {
    var color: Color = .tgBlue
    var size: CGFloat = 5

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: size * 0.6) {
                ForEach(0..<3, id: \.self) { index in
                    let wave = sin(t * 6 - Double(index) * 0.9)
                    Circle()
                        .fill(color)
                        .frame(width: size, height: size)
                        .opacity(0.35 + 0.65 * max(0, wave))
                        .offset(y: -1.5 * max(0, wave))
                }
            }
        }
    }
}

struct TypingLabel: View {
    var text = "typing"
    var font: CGFloat = 16

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
            Text(text).font(.system(size: font)).foregroundStyle(Color.tgBlue)
            TypingDots(size: font * 0.28)
        }
    }
}

// MARK: - Уведомление сверху

struct ToastView: View {
    let toast: Toast
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.tgBlue)
            Text(toast.text)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)
            if toast.undo != nil {
                Spacer(minLength: 8)
                Button("Undo", action: onUndo)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.tgBlue)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 50)
        .glass(Capsule())
        .padding(.horizontal, 16)
    }
}

// MARK: - Пузыри сообщений

struct BubbleShape: Shape {
    var isOutgoing: Bool
    var showTail: Bool

    func path(in rect: CGRect) -> Path {
        let body = Path(roundedRect: rect, cornerRadius: 18, style: .continuous)
        guard showTail else { return body }

        var tail = Path()
        if isOutgoing {
            tail.move(to: CGPoint(x: rect.maxX - 16, y: rect.maxY))
            tail.addLine(to: CGPoint(x: rect.maxX + 6, y: rect.maxY))
            tail.addQuadCurve(to: CGPoint(x: rect.maxX - 1, y: rect.maxY - 14),
                              control: CGPoint(x: rect.maxX - 1, y: rect.maxY - 3))
            tail.addLine(to: CGPoint(x: rect.maxX - 16, y: rect.maxY - 14))
        } else {
            tail.move(to: CGPoint(x: rect.minX + 16, y: rect.maxY))
            tail.addLine(to: CGPoint(x: rect.minX - 6, y: rect.maxY))
            tail.addQuadCurve(to: CGPoint(x: rect.minX + 1, y: rect.maxY - 14),
                              control: CGPoint(x: rect.minX + 1, y: rect.maxY - 3))
            tail.addLine(to: CGPoint(x: rect.minX + 16, y: rect.maxY - 14))
        }
        tail.closeSubpath()
        return body.union(tail)
    }
}

struct DoubleCheck: View {
    var size: CGFloat = 10

    var body: some View {
        ZStack {
            Image(systemName: "checkmark")
            Image(systemName: "checkmark").offset(x: size * 0.45)
        }
        .font(.system(size: size, weight: .bold))
        .padding(.trailing, size * 0.45)
    }
}

/// Часики → галочка → две галочки.
struct StatusIcon: View {
    let status: MessageStatus
    var size: CGFloat = 10

    var body: some View {
        switch status {
        case .sending:
            Image(systemName: "clock")
                .font(.system(size: size, weight: .semibold))
        case .sent:
            Image(systemName: "checkmark")
                .font(.system(size: size, weight: .bold))
        case .read:
            DoubleCheck(size: size)
        }
    }
}

struct MessageBubble: View {
    @Environment(AppModel.self) private var model
    let message: Message
    var showTail: Bool

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 56) }

            Group {
                if let video = message.video {
                    VideoBubble(image: video, duration: message.duration ?? "", time: message.time)
                } else {
                    textBubble
                }
            }
            .overlay(alignment: message.isOutgoing ? .bottomLeading : .bottomTrailing) {
                if let reaction = message.reaction {
                    Text(reaction)
                        .font(.system(size: 15))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white))
                        .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
                        .offset(x: message.isOutgoing ? -10 : 10, y: 12)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            }
            .padding(.bottom, message.reaction == nil ? 0 : 12)

            if !message.isOutgoing { Spacer(minLength: 56) }
        }
    }

    private var textBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let author = message.replyAuthor, let text = message.replyText {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.tgBlue).frame(width: 3)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(author).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.tgBlue)
                        Text(text).font(.system(size: 14)).foregroundStyle(.black.opacity(0.8)).lineLimit(1)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.tgBlue.opacity(0.1)))
                .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(message.text)
                    .font(.system(size: model.messageFontSize))
                    .foregroundStyle(.black)
                HStack(spacing: 2) {
                    Text(message.time)
                    if message.isOutgoing { StatusIcon(status: message.status, size: 9) }
                }
                .font(.system(size: 12))
                .foregroundStyle(message.isOutgoing ? Color(hex: 0x4CAF50) : Color.tgGray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            BubbleShape(isOutgoing: message.isOutgoing, showTail: showTail)
                .fill(message.isOutgoing ? Color.tgOutgoing : Color.white)
        )
    }
}

/// Видеосообщение-кружок с длительностью и временем, как в Telegram.
struct VideoBubble: View {
    let image: String
    let duration: String
    let time: String

    var body: some View {
        AssetImage(name: image)
            .frame(width: 220, height: 220)
            .overlay(alignment: .bottom) {
                HStack {
                    pill("\(duration) •")
                    Spacer()
                    pill(time)
                }
                .padding(.horizontal, 12)
                .offset(y: 2)
            }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.black.opacity(0.32)))
    }
}

/// Строка сообщения: свайп влево — ответить, двойной тап — ❤️, долгий тап — меню.
struct MessageRow: View {
    let message: Message
    let showTail: Bool
    var onReply: () -> Void
    var onReact: () -> Void
    var onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var armed = false

    var body: some View {
        MessageBubble(message: message, showTail: showTail)
            .offset(x: offset)
            .background(alignment: .trailing) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.black.opacity(0.25)))
                    .scaleEffect(armed ? 1.1 : max(0.4, min(1, -offset / 60)))
                    .opacity(min(1, -offset / 40))
                    .padding(.trailing, 4)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: onReact)
            .simultaneousGesture(
                DragGesture(minimumDistance: 18)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height),
                              value.translation.width < 0 else { return }
                        offset = max(value.translation.width * 0.7, -90)
                        let shouldArm = offset < -55
                        if shouldArm != armed { armed = shouldArm }
                    }
                    .onEnded { _ in
                        if armed { onReply() }
                        armed = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { offset = 0 }
                    }
            )
            .sensoryFeedback(.impact(weight: .light), trigger: armed) { _, new in new }
            .contextMenu {
                Button { onReply() } label: { Label("Reply", systemImage: "arrowshape.turn.up.left") }
                Button { onReact() } label: { Label("React ❤️", systemImage: "heart") }
                if message.video == nil {
                    Button { UIPasteboard.general.string = message.text } label: { Label("Copy", systemImage: "doc.on.doc") }
                }
                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
            }
    }
}

// MARK: - Лента сообщений

struct MessagesList: View {
    let messages: [Message]
    var topInset: CGFloat = 8
    var isTyping = false
    var onReply: (Message) -> Void = { _ in }
    var onReact: (Message) -> Void = { _ in }
    var onDelete: (Message) -> Void = { _ in }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    Text("Today")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.2)))
                        .padding(.bottom, 6)

                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        let next: Message? = index + 1 < messages.count ? messages[index + 1] : nil
                        let startsGroup = index > 0 && messages[index - 1].isOutgoing != message.isOutgoing
                        MessageRow(
                            message: message,
                            showTail: message.video == nil && next?.isOutgoing != message.isOutgoing,
                            onReply: { onReply(message) },
                            onReact: { onReact(message) },
                            onDelete: { onDelete(message) }
                        )
                        .padding(.top, startsGroup ? 6 : 0)
                        .id(message.id)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom)
                                    .combined(with: .scale(scale: 0.5, anchor: message.isOutgoing ? .bottomTrailing : .bottomLeading))
                                    .combined(with: .opacity),
                                removal: .scale(scale: 0.6).combined(with: .opacity)
                            )
                        )
                    }

                    if isTyping {
                        HStack {
                            TypingDots(color: Color.tgGray, size: 7)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(BubbleShape(isOutgoing: false, showTail: true).fill(Color.white))
                            Spacer()
                        }
                        .padding(.top, 6)
                        .id("typing")
                        .transition(.scale(scale: 0.5, anchor: .bottomLeading).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, topInset)
                .padding(.bottom, 12)
            }
            .defaultScrollAnchor(.bottom)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) {
                guard let last = messages.last else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: isTyping) {
                guard isTyping else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    proxy.scrollTo("typing", anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Обои чата

struct ChatWallpaper: View {
    @Environment(AppModel.self) private var model

    private let symbols = ["cat", "cup.and.saucer", "gamecontroller", "music.note", "camera",
                           "leaf", "star", "gift", "airplane", "heart", "paintbrush", "fish",
                           "umbrella", "balloon", "moon", "bicycle"]

    /// Своя картинка обоев: файл Backgrounds.png в папке ReplyFromPreview.
    private static let customImage = UIImage(named: "Backgrounds")

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xCFE0A4), Color(hex: 0x97BD7E), Color(hex: 0xB9D08F)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            if model.useCustomWallpaper, let image = Self.customImage {
                Color.clear
                    .overlay(
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    )
                    .clipped()
            } else {
                doodles
            }
        }
    }

    private var doodles: some View {
        Canvas { context, size in
            context.opacity = 0.17
            let step: CGFloat = 56
            var index = 0
            var row = 0
            var y: CGFloat = 14
            while y < size.height + step {
                var x: CGFloat = row.isMultiple(of: 2) ? 14 : 14 + step / 2
                while x < size.width + step {
                    let name = symbols[(index * 7 + row * 3) % symbols.count]
                    let text = Text(Image(systemName: name))
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(Color(hex: 0x2C5A26))
                    context.draw(text, at: CGPoint(x: x, y: y))
                    x += step
                    index += 1
                }
                y += step
                row += 1
            }
        }
    }
}

// MARK: - Поле ввода (Write Bar)

struct InputBar: View {
    @Binding var draft: String
    var focused: FocusState<Bool>.Binding
    var replyAuthor: String? = nil
    var replyText: String? = nil
    var onCancelReply: () -> Void = {}
    var onSend: () -> Void

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            if let replyAuthor, let replyText {
                HStack(spacing: 10) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .foregroundStyle(Color.tgBlue)
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.tgBlue).frame(width: 3, height: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Reply to \(replyAuthor)").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.tgBlue)
                        Text(replyText).font(.system(size: 14)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button(action: onCancelReply) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.tgGray)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .glass(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            GlassGroup(spacing: 8) {
                HStack(spacing: 7) {
                    CircleButton(systemName: "paperclip", size: 42)

                    HStack {
                        TextField("Message", text: $draft)
                            .font(.system(size: 17))
                            .focused(focused)
                            .submitLabel(.send)
                            .onSubmit(onSend)
                        Image(systemName: "keyboard")
                            .font(.system(size: 19))
                            .foregroundStyle(Color(hex: 0x6D6D72))
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 12)
                    .frame(height: 42)
                    .glass(Capsule())

                    ZStack {
                        if canSend {
                            Button(action: onSend) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .contentShape(Circle())
                                    .glass(Circle(), tint: Color.tgBlue, interactive: true)
                            }
                            .buttonStyle(.plain)
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            CircleButton(systemName: "mic", size: 42)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canSend)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: replyText)
    }
}

// MARK: - Сгруппированные строки (настройки, профиль)

struct GroupCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white))
    }
}

struct IconSquare: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color))
    }
}

struct SettingsRow<Leading: View>: View {
    let title: String
    var value: String? = nil
    var titleColor: Color = .black
    var showsChevron = true
    var isLast = false
    @ViewBuilder var leading: Leading
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                leading
                VStack(spacing: 0) {
                    HStack {
                        Text(title).font(.system(size: 17)).foregroundStyle(titleColor)
                        Spacer()
                        if let value {
                            Text(value).font(.system(size: 17)).foregroundStyle(Color.tgGray)
                        }
                        if showsChevron {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(hex: 0xC4C4C7))
                        }
                    }
                    .frame(maxHeight: .infinity)
                    if !isLast {
                        Rectangle().fill(Color.tgSeparator).frame(height: 0.5)
                    }
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var isLast = false

    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $isOn) {
                Text(title).font(.system(size: 17))
            }
            .tint(Color(hex: 0x34C759))
            .frame(maxHeight: .infinity)
            if !isLast {
                Rectangle().fill(Color.tgSeparator).frame(height: 0.5)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13))
            .foregroundStyle(Color.tgGray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }
}

struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(Color.black.opacity(configuration.isPressed ? 0.05 : 0))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// Шапка вкладки: левая кнопка, центр, правая кнопка — всё на стекле.
struct TabHeader<Leading: View, Center: View, Trailing: View>: View {
    var fade: Color = .white
    @ViewBuilder var leading: Leading
    @ViewBuilder var center: Center
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            HStack {
                leading
                Spacer()
                trailing
            }
            center
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(alignment: .top) {
            LinearGradient(colors: [fade, fade.opacity(0.85), fade.opacity(0)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
    }
}
