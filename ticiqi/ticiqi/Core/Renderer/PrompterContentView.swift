//  Tiled layer view — renders extremely long text off main thread
//  ticiqi
//

import UIKit
import SwiftUI

final class PrompterContentView: UIView {
    private var cachedContent: String = ""
    private var cachedFontSize: CGFloat = 0
    private var cachedTextColor: UIColor = .white
    private var cachedWidth: CGFloat = 0
    private var cachedHeight: CGFloat = 0
    private var framesetter: CTFramesetter?
    private var cachedAttrStringLength: Int = 0
    private var cachedFrame: CTFrame?
    
    override class var layerClass: AnyClass {
        return CATiledLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .clear
        isOpaque = false
        if let tiledLayer = layer as? CATiledLayer {
            let scale = UIScreen.main.scale
            tiledLayer.tileSize = CGSize(width: 512 * scale, height: 512 * scale)
        }
    }
    
    func update(content: String, state: RenderState) {
        let newTextColor = UIColor(state.textColor)
        
        if content != cachedContent || state.fontSize != cachedFontSize || newTextColor != cachedTextColor || bounds.width != cachedWidth || bounds.height != cachedHeight {
            cachedContent = content
            cachedFontSize = state.fontSize
            cachedTextColor = newTextColor
            cachedWidth = bounds.width
            cachedHeight = bounds.height
            
            let attrString = CoreTextRenderer.buildAttributedString(content: content, state: state)
            framesetter = CTFramesetterCreateWithAttributedString(attrString)
            cachedAttrStringLength = attrString.length

            if let framesetter = framesetter, bounds.width > 0, bounds.height > 0 {
                let path = CGPath(rect: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height), transform: nil)
                cachedFrame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attrString.length), path, nil)
            } else {
                cachedFrame = nil
            }
            
            layer.setNeedsDisplay()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure frame gets rebuilt if bounds change without an explicit update call
        if bounds.width != cachedWidth || bounds.height != cachedHeight {
            guard let framesetter = framesetter, bounds.width > 0, bounds.height > 0 else { return }
            cachedWidth = bounds.width
            cachedHeight = bounds.height
            let path = CGPath(rect: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height), transform: nil)
            cachedFrame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: cachedAttrStringLength), path, nil)
            layer.setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        guard let cachedFrame = cachedFrame, let ctx = UIGraphicsGetCurrentContext() else {
            return
        }
        
        CoreTextRenderer.drawStatic(
            frame: cachedFrame,
            context: ctx,
            viewSize: bounds.size
        )
    }
}
