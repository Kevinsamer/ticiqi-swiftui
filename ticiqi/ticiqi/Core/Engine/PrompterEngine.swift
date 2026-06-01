//  Core teleprompter engine — coordinates state, display link, scroll, and layout metrics
//  ticiqi
//

import Foundation
import UIKit

@MainActor
@Observable final class PrompterEngine {
    let state = RenderState()
    private let displayLink = DisplayLinkController()
    private var document: ScriptDocument?
    private var contentHash: Int?

    // High-frequency callback for scroll view (every frame, bypasses @Observable)
    var onOffsetChange: ((CGFloat) -> Void)?

    // Network broadcast callback — throttled to reduce WebSocket overhead
    var onStateBroadcast: ((StateSnapshot) -> Void)?

    // Throttle progress updates to reduce SwiftUI Slider re-evaluation overhead
    private var frameCount: Int = 0
    private let progressUpdateInterval: Int = 10
    private let broadcastInterval: Int = 30

    // MARK: - Lifecycle

    init() {
        displayLink.onTick = { [weak self] deltaTime in
            guard let self else { return }
            self.handleTick(deltaTime: deltaTime)
        }
    }

    func shutdown() {
        displayLink.shutdown()
    }

    // MARK: - Document

    func load(document: ScriptDocument) {
        self.document = document
        state.currentOffset = 0
        state.scrollProgress = 0
        contentHash = nil
        frameCount = 0
        recomputeLayoutIfNeeded(content: document.rawContent)
        applyOffsetClamp()
        syncOffsetToView()
        notifyStateChange()
    }

    func hotReload(document: ScriptDocument) {
        let savedProgress = state.scrollProgress

        self.document = document
        contentHash = nil
        recomputeLayoutIfNeeded(content: document.rawContent)

        // Progress ratio restoration per white paper spec; clamp ensures safety
        state.currentOffset = CGFloat(savedProgress) * scrollRange
        applyOffsetClamp()
        updateProgress()
        syncOffsetToView()
        notifyStateChange()
    }

    // MARK: - Playback

    func play() {
        state.isPlaying = true
        displayLink.start()
        notifyStateChange()
    }

    func pause() {
        state.isPlaying = false
        displayLink.stop()
        notifyStateChange()
    }

    func togglePlay() {
        if state.isPlaying { pause() } else { play() }
    }

    func toggleMirror() {
        state.mirrorEnabled.toggle()
        notifyStateChange()
    }

    func toggleFocusLine() {
        state.focusLineEnabled.toggle()
        notifyStateChange()
    }

    func toggleScrollDirection() {
        state.scrollDirection = state.scrollDirection == .up ? .down : .up
        notifyStateChange()
    }

    func seek(to progress: Double) {
        let clampedProgress = max(0, min(1, progress))
        state.currentOffset = CGFloat(clampedProgress) * scrollRange
        applyOffsetClamp()
        updateProgress()
        syncOffsetToView()
        notifyStateChange()
    }

    // MARK: - Parameters

    func updateSpeed(_ speed: CGFloat) {
        state.scrollSpeed = max(1, min(200, speed))
        notifyStateChange()
    }

    func updateFontSize(_ size: CGFloat) {
        state.fontSize = max(16, min(160, size))
        if let doc = document {
            contentHash = nil
            recomputeLayoutIfNeeded(content: doc.rawContent)
        }
        frameCount = 0
        applyOffsetClamp()
        syncOffsetToView()
        notifyStateChange()
    }

    func updateViewSize(height: CGFloat, width: CGFloat) {
        let widthChanged = state.viewWidth != width
        state.viewHeight = height
        state.viewWidth = width
        state.topPadding = height / 2
        if widthChanged, let doc = document {
            contentHash = nil
            recomputeLayoutIfNeeded(content: doc.rawContent)
        }
        applyOffsetClamp()
        syncOffsetToView()
    }

    // MARK: - Scroll tick

    private func handleTick(deltaTime: CFTimeInterval) {
        state.currentOffset += state.scrollSpeed * CGFloat(deltaTime)
        applyOffsetClamp()

        frameCount += 1
        if frameCount % progressUpdateInterval == 0 {
            updateProgress()
        }
        if frameCount % broadcastInterval == 0 {
            notifyStateChange()
        }

        syncOffsetToView()
    }
    
    private func syncOffsetToView() {
        let scale = UIScreen.main.scale
        let alignedOffset = round(state.currentOffset * scale) / scale
        onOffsetChange?(alignedOffset)
    }

    private var scrollRange: CGFloat {
        let raw = state.totalContentHeight
        guard raw > 0 else { return 0 }
        let font = UIFont.monospacedSystemFont(ofSize: state.fontSize, weight: .medium)
        let lineH = font.lineHeight + state.fontSize * 0.3
        return state.topPadding + max(0, raw - lineH)
    }

    private func applyOffsetClamp() {
        let maxOffset = scrollRange
        state.currentOffset = max(0, min(state.currentOffset, maxOffset))
    }

    private func updateProgress() {
        let maxOffset = scrollRange
        guard maxOffset > 0 else {
            state.scrollProgress = 0
            return
        }
        state.scrollProgress = Double(state.currentOffset / maxOffset)
    }

    private func recomputeLayoutIfNeeded(content: String) {
        let newHash = content.hashValue ^ state.fontSize.hashValue ^ state.viewWidth.hashValue
        guard newHash != contentHash else { return }
        contentHash = newHash
        state.totalContentHeight = CoreTextMetrics.totalHeight(
            content: content,
            fontSize: state.fontSize,
            width: state.viewWidth
        )
    }

    // MARK: - State broadcast

    func buildSnapshot() -> StateSnapshot {
        StateSnapshot(
            isPlaying: state.isPlaying,
            scrollSpeed: Double(state.scrollSpeed),
            fontSize: Double(state.fontSize),
            scrollProgress: state.scrollProgress,
            mirrorEnabled: state.mirrorEnabled,
            focusLineEnabled: state.focusLineEnabled,
            scrollDirection: state.scrollDirection.rawValue,
            content: document?.rawContent ?? ""
        )
    }

    private func notifyStateChange() {
        onStateBroadcast?(buildSnapshot())
    }
}

// MARK: - State snapshot for network broadcast

struct StateSnapshot: Codable {
    let isPlaying: Bool
    let scrollSpeed: Double
    let fontSize: Double
    let scrollProgress: Double
    let mirrorEnabled: Bool
    let focusLineEnabled: Bool
    let scrollDirection: String
    var content: String
    var clientCount: Int = 0
    var currentPage: String = "library"
}

// MARK: - Layout metrics (pure, no side effects)

enum CoreTextMetrics {
    static func totalHeight(content: String, fontSize: CGFloat, width: CGFloat) -> CGFloat {
        guard !content.isEmpty, width > 0 else { return 0 }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = fontSize * 0.3
        paragraphStyle.alignment = .center
        let attrString = NSAttributedString(
            string: content,
            attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .medium),
                .paragraphStyle: paragraphStyle
            ]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attrString)
        let constraint = CGSize(width: width, height: .greatestFiniteMagnitude)
        return CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: 0),
            nil,
            constraint,
            nil
        ).height
    }
}
