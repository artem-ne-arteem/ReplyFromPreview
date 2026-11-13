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
                .overlay(shape.stroke(Color.white.opacity(0.45), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
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
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
                .glass(Circle(), interactive: true)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Аватар

struct Avatar: View {
    let chat: Chat
    var size: CGFloat = 56

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [chat.color.opacity(0.7), chat.color], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay(Text(chat.emoji).font(.system(size: size * 0.5)))
    }
}

// MARK: - Пузырь сообщения с хвостиком

struct BubbleShape: Shape {
    var isOutgoing: Bool
    var showTail: Bool

    func path(in rect: CGRect) -> Path {
        let body = Path(roundedRect: rect, cornerRadius: 17, style: .continuous)
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
    var body: some View {
        ZStack {
            Image(systemName: "checkmark")
            Image(systemName: "checkmark").offset(x: 4)
        }
        .font(.system(size: 9, weight: .bold))
        .padding(.trailing, 4)
    }
}

struct MessageBubble: View {
    let message: Message
    var showTail: Bool

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 60) }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(message.text)
                    .font(.system(size: 16))
                    .foregroundStyle(.black)
                HStack(spacing: 2) {
                    Text(message.time)
                    if message.isOutgoing { DoubleCheck() }
                }
                .font(.system(size: 11))
                .foregroundStyle(message.isOutgoing ? Color(hex: 0x3FA33F) : Color.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                BubbleShape(isOutgoing: message.isOutgoing, showTail: showTail)
                    .fill(message.isOutgoing ? Color(hex: 0xE1FEC6) : Color.white)
            )

            if !message.isOutgoing { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Лента сообщений

struct MessagesList: View {
    let messages: [Message]
    var topInset: CGFloat = 8

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        let next: Message? = index + 1 < messages.count ? messages[index + 1] : nil
                        let startsGroup = index > 0 && messages[index - 1].isOutgoing != message.isOutgoing
                        MessageBubble(message: message, showTail: next?.isOutgoing != message.isOutgoing)
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
                .padding(.bottom, 10)
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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xCFE0A4), Color(hex: 0x97BD7E), Color(hex: 0xB9D08F)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
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
}

// MARK: - Поле ввода

struct InputBar: View {
    @Binding var draft: String
    var focused: FocusState<Bool>.Binding
    var onSend: () -> Void

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GlassGroup(spacing: 8) {
            HStack(spacing: 8) {
                CircleButton(systemName: "paperclip")

                HStack {
                    TextField("Message", text: $draft)
                        .font(.system(size: 17))
                        .focused(focused)
                        .submitLabel(.send)
                        .onSubmit(onSend)
                    Image(systemName: "face.smiling")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .glass(Capsule())

                ZStack {
                    if canSend {
                        Button(action: onSend) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .contentShape(Circle())
                                .glass(Circle(), tint: Color(hex: 0x2AABEE), interactive: true)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        CircleButton(systemName: "mic")
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canSend)
    }
}
