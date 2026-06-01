//  Teleprompter host — pure display view, all controls via web console
//  ticiqi
//

import SwiftUI

struct PrompterHostView: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var wasPlayingBeforeBackground = false
    @State private var showBackButton = true
    @State private var hideTimer: Timer?

    let engine: PrompterEngine
    let serverManager: PrompterServerManager
    let document: ScriptDocument
    let settings: PrompterSettings

    private let autoHideDelay: TimeInterval = 3

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PrompterRenderView(
                    engine: engine,
                    content: document.rawContent
                )
                .ignoresSafeArea()

                // Edge swipe to dismiss (left 24px strip)
                Color.clear
                    .frame(width: 24)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 30)
                            .onEnded { value in
                                if value.translation.width > 50 {
                                    engine.pause()
                                    dismiss()
                                }
                            }
                    )

                // Tap anywhere to show back button
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { flashBackButton() }

                VStack {
                    HStack {
                        Button {
                            engine.pause()
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(.leading, 12)
                        .padding(.top, 8)
                        .opacity(showBackButton ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: showBackButton)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .onAppear {
                serverManager.currentPage = "teleprompter"
                applySettings()
                engine.load(document: document)
                engine.updateViewSize(height: geometry.size.height, width: geometry.size.width)
                scheduleAutoHide()
            }
            .onDisappear {
                hideTimer?.invalidate()
                serverManager.currentPage = "library"
            }
            .onChange(of: geometry.size) { _, newSize in
                engine.updateViewSize(height: newSize.height, width: newSize.width)
            }
            .onChange(of: document.id) { _, _ in
                engine.load(document: document)
                engine.updateViewSize(height: geometry.size.height, width: geometry.size.width)
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background, .inactive:
                    wasPlayingBeforeBackground = engine.state.isPlaying
                    engine.pause()
                case .active:
                    if wasPlayingBeforeBackground { engine.play() }
                @unknown default:
                    break
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func applySettings() {
        engine.updateSpeed(settings.defaultSpeed)
        engine.updateFontSize(settings.fontSize)
        engine.state.scrollDirection = settings.scrollDirection
        engine.state.textColor = settings.textColor
        engine.state.backgroundColor = settings.backgroundColor.color
        engine.state.mirrorEnabled = settings.mirrorEnabled
        engine.state.focusLineEnabled = settings.focusLineEnabled
    }

    private func flashBackButton() {
        showBackButton = true
        scheduleAutoHide()
    }

    private func scheduleAutoHide() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: autoHideDelay, repeats: false) { _ in
            showBackButton = false
        }
    }
}
