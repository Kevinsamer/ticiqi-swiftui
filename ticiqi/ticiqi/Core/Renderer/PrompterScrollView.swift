//  GPU-accelerated ScrollView wrapper for teleprompter 
//  ticiqi
//

import UIKit

final class PrompterScrollView: UIView {
    private let scrollView = UIScrollView()
    private let contentView = PrompterContentView()
    private let focusLineLayer = CAShapeLayer()
    
    private var cachedViewWidth: CGFloat = 0
    private var cachedTotalHeight: CGFloat = 0
    private var cachedLineHeight: CGFloat = 0
    private var cachedTopPadding: CGFloat = 0
    private var isMirrored: Bool = false
    private var cachedDirection: ScrollDirection = .up
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        // Configure ScrollView
        scrollView.isScrollEnabled = false // Engine drives scroll, not user touches
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Configure focus line
        focusLineLayer.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        focusLineLayer.lineWidth = 1
        layer.addSublayer(focusLineLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds

        let textHeight = max(bounds.height, cachedTotalHeight)
        contentView.frame = CGRect(x: 0, y: cachedTopPadding / 2, width: bounds.width, height: textHeight)
        scrollView.contentSize = CGSize(width: bounds.width, height: cachedTopPadding + textHeight + bounds.height)

        updateFocusLine()
    }
    
    func update(content: String, state: RenderState) {
        // Handle transforms
        if isMirrored != state.mirrorEnabled {
            isMirrored = state.mirrorEnabled
            let transform = isMirrored ? CGAffineTransform(scaleX: -1.0, y: 1.0) : .identity
            scrollView.transform = transform
        }
        
        // Handle focus line
        focusLineLayer.isHidden = !state.focusLineEnabled
        
        // Handle size changes
        let font = UIFont.monospacedSystemFont(ofSize: state.fontSize, weight: .medium)
        let lineHeight = font.lineHeight + state.fontSize * 0.3
        let forceLayout = bounds.width != cachedViewWidth || state.totalContentHeight != cachedTotalHeight || lineHeight != cachedLineHeight || state.topPadding != cachedTopPadding
        cachedViewWidth = bounds.width
        cachedTotalHeight = state.totalContentHeight
        cachedLineHeight = lineHeight
        cachedTopPadding = state.topPadding

        if forceLayout {
            let textHeight = max(bounds.height, cachedTotalHeight)
            contentView.frame = CGRect(x: 0, y: cachedTopPadding / 2, width: bounds.width, height: textHeight)
            scrollView.contentSize = CGSize(width: bounds.width, height: cachedTopPadding + textHeight + bounds.height)
        }
        
        cachedDirection = state.scrollDirection
        contentView.update(content: content, state: state)
    }
    
    func updateOffset(_ offset: CGFloat) {
        let rawMax = max(0, scrollView.contentSize.height - bounds.height)
        let maxOffset = max(0, rawMax - cachedLineHeight)
        let clamped = max(0, min(offset, maxOffset))
        
        switch cachedDirection {
        case .up:
            scrollView.contentOffset = CGPoint(x: 0, y: clamped)
        case .down:
            scrollView.contentOffset = CGPoint(x: 0, y: maxOffset - clamped)
        }
    }
    
    private func updateFocusLine() {
        let y = bounds.height / 2
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: bounds.width, y: y))
        focusLineLayer.path = path.cgPath
    }
}
