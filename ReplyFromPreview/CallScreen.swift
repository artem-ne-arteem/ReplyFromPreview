import SwiftUI
import Combine

/// Экран звонка: запрос → гудки → таймер, стеклянные кнопки.
struct CallScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let call: ActiveCall

    @State private var elapsed: Double = 0
    @State private var muted = false
    @State private var speaker = false
    @State private var videoOn: Bool
    @State private var pulse = false

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    init(call: ActiveCall) {
        self.call = call
        _videoOn = State(initialValue: call.video)
    }

    private var connected: Bool { elapsed >= 4 }

    private var statusText: String {
        if elapsed < 2 { return "Requesting…" }
        if !connected { return "Ringing…" }
        let seconds = Int(elapsed - 4)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 12) {
                Spacer().frame(height: 70)

                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 140, height: 140)
                            .scaleEffect(pulse ? 1 + Double(index + 1) * 0.28 : 1)
                            .opacity(pulse ? 0 : 0.8)
                            .animation(
                                .easeOut(duration: 2.2).repeatForever(autoreverses: false).delay(Double(index) * 0.6),
                                value: pulse
                            )
                    }
                    Avatar(chat: call.chat, size: 140)
                }
                .opacity(connected ? 1 : 0.95)

                Text(call.chat.name)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 18)

                Text(statusText)
                    .font(.system(size: 17))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.8))
                    .contentTransition(.numericText())

                if connected {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                        Text("🐱 🍕 🎸 🚀")
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .glass(Capsule())
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                GlassGroup(spacing: 20) {
                    HStack(spacing: 20) {
                        callButton(speaker ? "speaker.wave.3.fill" : "speaker.wave.2.fill", "Speaker", active: speaker) {
                            speaker.toggle()
                        }
                        callButton(videoOn ? "video.fill" : "video.slash.fill", "Video", active: videoOn) {
                            videoOn.toggle()
                        }
                        callButton(muted ? "mic.slash.fill" : "mic.fill", "Mute", active: muted) {
                            muted.toggle()
                        }
                        VStack(spacing: 6) {
                            Button {
                                model.finishCall(call)
                                dismiss()
                            } label: {
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 66, height: 66)
                                    .contentShape(Circle())
                                    .glass(Circle(), tint: Color(hex: 0xFF3B30), interactive: true)
                            }
                            .buttonStyle(.plain)
                            Text("End").font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear { pulse = true }
        .onReceive(timer) { _ in
            withAnimation(.easeOut(duration: 0.3)) { elapsed += 0.5 }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: connected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: muted)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: speaker)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: videoOn)
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [call.chat.color, Color(hex: 0x1B2A3A)], startPoint: .top, endPoint: .bottom)
            if let avatar = call.chat.avatar {
                AssetImage(name: avatar, fill: true)
                    .scaleEffect(2.4)
                    .blur(radius: 60)
                    .opacity(0.9)
            }
            Color.black.opacity(0.25)
        }
        .ignoresSafeArea()
    }

    private func callButton(_ icon: String, _ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(active ? Color.black : Color.white)
                    .frame(width: 66, height: 66)
                    .contentShape(Circle())
                    .glass(Circle(), tint: active ? Color.white : nil, interactive: true)
            }
            .buttonStyle(.plain)
            Text(label).font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
        }
    }
}
