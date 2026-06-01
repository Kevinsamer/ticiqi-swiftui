//  Control panel — play/pause, progress slider, and speed adjustment
//  ticiqi
//

import SwiftUI

struct ControlPanelView: View {
    let engine: PrompterEngine
    @State private var panelExpanded: Bool = false
    @State private var wasPlayingBeforeSeek: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if panelExpanded {
                expandedContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            collapsedBar
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Collapsed bar

    private var collapsedBar: some View {
        HStack(spacing: 16) {
            Button {
                engine.togglePlay()
            } label: {
                Image(systemName: engine.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }

            Slider(value: Binding(
                get: { engine.state.scrollProgress },
                set: { engine.seek(to: $0) }
            ), onEditingChanged: { editing in
                if editing {
                    wasPlayingBeforeSeek = engine.state.isPlaying
                    engine.pause()
                } else if wasPlayingBeforeSeek {
                    engine.play()
                }
            })
            .tint(.white)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    panelExpanded.toggle()
                }
            } label: {
                Image(systemName: panelExpanded ? "chevron.down" : "slider.horizontal.3")
                    .font(.title3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Expanded content

    private var expandedContent: some View {
        VStack(spacing: 14) {
            HStack {
                Text("速度: \(Int(engine.state.scrollSpeed))")
                    .font(.caption)
                    .monospacedDigit()
                Slider(value: Binding(
                    get: { engine.state.scrollSpeed },
                    set: { engine.updateSpeed($0) }
                ), in: 1...200, step: 1)
            }

            HStack(spacing: 20) {
                speedPresetButton(15, label: "慢")
                speedPresetButton(30, label: "中")
                speedPresetButton(60, label: "快")
                speedPresetButton(200, label: "极速")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func speedPresetButton(_ speed: CGFloat, label: String) -> some View {
        Button {
            engine.updateSpeed(speed)
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(engine.state.scrollSpeed == speed
                    ? Color.white.opacity(0.2) : Color.clear)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
        }
    }
}
