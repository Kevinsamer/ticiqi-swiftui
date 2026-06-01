//  Paragraph indexer — O(P) position estimation using pre-computed character offsets
//  ticiqi
//

import Foundation

struct ParagraphPosition: Identifiable {
    let id: Int
    let paragraphIndex: Int
    let paragraph: Paragraph
    let estimatedProgress: Double

    var displayLabel: String {
        let prefix = paragraph.markerType == .heading ? "" : "  "
        let text = paragraph.text.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        return "\(prefix)\(text)"
    }
}

enum ParagraphIndexer {

    /// Builds paragraph positions using pre-computed character offsets (O(P)).
    /// `fontSize` and `width` are accepted for future pixel-accurate indexing;
    /// currently position estimation is character-count-based.
    static func index(
        document: ScriptDocument,
        fontSize: CGFloat,
        width: CGFloat
    ) -> [ParagraphPosition] {
        guard !document.rawContent.isEmpty else { return [] }

        let totalChars = Double(document.totalCharacterCount)
        guard totalChars > 0 else { return [] }

        return document.paragraphs.enumerated().map { index, paragraph in
            let progress = Double(paragraph.characterOffset) / totalChars

            return ParagraphPosition(
                id: index,
                paragraphIndex: index,
                paragraph: paragraph,
                estimatedProgress: min(progress, 1.0)
            )
        }
    }

    static func headingPositions(from positions: [ParagraphPosition]) -> [ParagraphPosition] {
        positions.filter { $0.paragraph.markerType == .heading }
    }
}
