//  CoreText rendering engine — pure draw pass, no layout side effects
//  ticiqi
//

import SwiftUI
import UIKit
import CoreText

enum CoreTextRenderer {

    // MARK: - Static Draw (For Tiled Layer)

    static func drawStatic(
        frame: CTFrame,
        context: CGContext,
        viewSize: CGSize
    ) {
        context.saveGState()
        
        // Flip coordinate system for CoreText
        context.textMatrix = .identity
        context.translateBy(x: 0, y: viewSize.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    // MARK: - Attributed string & framesetter factory

    static func makeFramesetter(content: String, state: RenderState) -> CTFramesetter {
        let attrString = buildAttributedString(content: content, state: state)
        return CTFramesetterCreateWithAttributedString(attrString)
    }

    // MARK: - Attributed string builder

    static func buildAttributedString(content: String, state: RenderState) -> NSAttributedString {
        let uiColor = UIColor(state.textColor)
        let font = UIFont.monospacedSystemFont(ofSize: state.fontSize, weight: .medium)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = state.fontSize * 0.3
        paragraphStyle.alignment = .center

        return NSAttributedString(
            string: content,
            attributes: [
                .font: font,
                .foregroundColor: uiColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }
}
