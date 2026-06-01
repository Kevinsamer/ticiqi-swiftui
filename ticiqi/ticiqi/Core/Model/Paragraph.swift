//  Paragraph model with marker type — character offset pre-computed for O(1) indexing
//  ticiqi
//

import Foundation

enum ParagraphMarker: String, CaseIterable {
    case heading
    case normal
}

struct Paragraph: Identifiable {
    let id: UUID = UUID()
    let text: String
    let characterRange: Range<String.Index>
    let characterOffset: Int
    let markerType: ParagraphMarker

    static func classify(_ line: String) -> ParagraphMarker {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("# ") || trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") {
            return .heading
        }
        return .normal
    }
}
