import SwiftUI

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
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
                .contentShape(Circle())
                .glass(Circle(), interactive: true)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Картинки и аватары

struct AssetImage: View {
    let name: String

    var body: some View {
        if let image = UIImage(named: name) {
            Image(uiImage: image).resizable().scaledToFit()
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
            Circle()
                .fill(LinearGradient(colors: [chat.color.opacity(0.7), chat.color], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Text(chat.initials)
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .padding(size * 0.03)
                .frame(width: size, height: size)
        }
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

// MARK: - Пузырь сообщения с хвостиком

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

struct MessageBubble: View {
    let message: Message
    var showTail: Bool

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 56) }

            if let video = message.video {
                VideoBubble(image: video, duration: message.duration ?? "", time: message.time)
            } else {
                textBubble
            }

            if !message.isOutgoing { Spacer(minLength: 56) }
        }
    }

    private var textBubble: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(message.text)
                .font(.system(size: 17))
                .foregroundStyle(.black)
            HStack(spacing: 2) {
                Text(message.time)
                if message.isOutgoing { DoubleCheck(size: 9) }
            }
            .font(.system(size: 12))
            .foregroundStyle(message.isOutgoing ? Color(hex: 0x4CAF50) : Color.tgGray)
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

// MARK: - Лента сообщений

struct MessagesList: View {
    let messages: [Message]
    var topInset: CGFloat = 8

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        let next: Message? = index + 1 < messages.count ? messages[index + 1] : nil
                        let startsGroup = index > 0 && messages[index - 1].isOutgoing != message.isOutgoing
                        MessageBubble(
                            message: message,
                            showTail: message.video == nil && next?.isOutgoing != message.isOutgoing
                        )
                        .padding(.top, startsGroup ? 6 : 0)
                        .id(message.id)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom)
                                    .combined(with: .scale(scale: 0.5, anchor: .bottomTrailing))
                                    .combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, topInset)
                .padding(.bottom, 12)
            }
            .defaultScrollAnchor(.bottom)
            .scrollIndicators(.hidden)
            .onChange(of: messages.count) {
                guard let last = messages.last else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Обои чата

struct ChatWallpaper: View {
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
            if let image = Self.customImage {
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
    var onSend: () -> Void

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canSend)
    }
}
