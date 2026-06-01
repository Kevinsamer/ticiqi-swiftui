//  UIKit bridge — renders CoreText output inside SwiftUI, caches framesetter and frame
//  ticiqi
//

import SwiftUI
import Observation

struct PrompterRenderView: UIViewRepresentable {
    let engine: PrompterEngine
    let content: String

    func makeUIView(context: Context) -> PrompterScrollView {
        let scrollView = PrompterScrollView()
        scrollView.backgroundColor = UIColor(engine.state.backgroundColor)
        
        // Pass offset updates directly from engine to the scroll view
        engine.onOffsetChange = { [weak scrollView] offset in
            scrollView?.updateOffset(offset)
        }
        
        return scrollView
    }

    func updateUIView(_ scrollView: PrompterScrollView, context: Context) {
        scrollView.backgroundColor = UIColor(engine.state.backgroundColor)
        scrollView.update(content: content, state: engine.state)
    }
}

