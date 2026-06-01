//  CADisplayLink lifecycle manager with trampoline proxy to break retain cycle
//  ticiqi
//

import UIKit

/// Bridge object that holds a weak reference to the real tick handler,
/// breaking the CADisplayLink → target strong-reference cycle.
private final class DisplayLinkProxy {
    weak var target: DisplayLinkController?

    init(target: DisplayLinkController) {
        self.target = target
    }

    @objc func tick(_ link: CADisplayLink) {
        MainActor.assumeIsolated {
            target?.handleTick(link)
        }
    }
}

// MARK: - Controller

@MainActor
final class DisplayLinkController {
    private var displayLink: CADisplayLink?
    private var proxy: DisplayLinkProxy?
    private var lastTimestamp: CFTimeInterval = 0

    var onTick: ((CFTimeInterval) -> Void)?

    var isRunning: Bool {
        displayLink != nil
    }

    deinit {
        // Synchronous safety net — stop() only invalidates CADisplayLink
        MainActor.assumeIsolated {
            stop()
        }
    }

    func shutdown() {
        stop()
    }

    func start() {
        guard displayLink == nil else { return }
        let proxy = DisplayLinkProxy(target: self)
        self.proxy = proxy
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTimestamp = 0
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        proxy = nil
        lastTimestamp = 0
    }

    fileprivate func handleTick(_ link: CADisplayLink) {
        guard lastTimestamp > 0 else {
            lastTimestamp = link.timestamp
            return
        }
        let delta = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        onTick?(delta)
    }
}
