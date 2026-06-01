//  Unified render state — single source of truth, all mutations on main actor
//  ticiqi
//

import SwiftUI

enum ScrollDirection: String, CaseIterable, Codable {
    case up
    case down
}

@MainActor
@Observable final class RenderState {
    var isPlaying: Bool = false
    var scrollSpeed: CGFloat = 30.0
    var fontSize: CGFloat = 48.0
    var currentOffset: CGFloat = 0.0
    var scrollProgress: Double = 0.0
    var scrollDirection: ScrollDirection = .up
    var mirrorEnabled: Bool = false
    var focusLineEnabled: Bool = true
    var textColor: Color = .white
    var backgroundColor: Color = .black
    var topPadding: CGFloat = 0.0
    var totalContentHeight: CGFloat = 0.0
    var viewHeight: CGFloat = 0.0
    var viewWidth: CGFloat = 0.0
}
