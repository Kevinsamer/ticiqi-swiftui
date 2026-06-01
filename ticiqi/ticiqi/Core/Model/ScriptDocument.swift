//  Script document — holds full text and paragraph index with pre-computed character offsets
//  ticiqi
//

import Foundation

struct ScriptDocument {
    let id: UUID = UUID()
    var title: String
    var rawContent: String
    var paragraphs: [Paragraph]
    private(set) var totalCharacterCount: Int
    var createdAt: Date
    var updatedAt: Date

    var paragraphCount: Int {
        paragraphs.count
    }

    init(title: String = "", content: String = "") {
        let normalized = ScriptDocument.normalizeLineEndings(content)
        self.title = title
        self.rawContent = normalized
        self.paragraphs = ScriptDocument.parseParagraphs(from: normalized)
        self.totalCharacterCount = normalized.count
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    init(id: UUID, title: String, content: String, createdAt: Date, updatedAt: Date) {
        let normalized = ScriptDocument.normalizeLineEndings(content)
        self.title = title
        self.rawContent = normalized
        self.paragraphs = ScriptDocument.parseParagraphs(from: normalized)
        self.totalCharacterCount = normalized.count
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    mutating func updateContent(_ newContent: String) {
        let normalized = ScriptDocument.normalizeLineEndings(newContent)
        rawContent = normalized
        paragraphs = ScriptDocument.parseParagraphs(from: normalized)
        totalCharacterCount = normalized.count
        updatedAt = Date()
    }

    private static func normalizeLineEndings(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func parseParagraphs(from text: String) -> [Paragraph] {
        guard !text.isEmpty else { return [] }

        var paragraphs: [Paragraph] = []
        var offset = text.startIndex
        var runningCharOffset = 0

        while offset < text.endIndex {
            guard let lineEnd = text[offset...].firstIndex(of: "\n") else {
                let line = String(text[offset...])
                if !line.isEmpty {
                    paragraphs.append(Paragraph(
                        text: line,
                        characterRange: offset..<text.endIndex,
                        characterOffset: runningCharOffset,
                        markerType: Paragraph.classify(line)
                    ))
                }
                break
            }

            let line = String(text[offset..<lineEnd])
            if !line.isEmpty {
                paragraphs.append(Paragraph(
                    text: line,
                    characterRange: offset..<lineEnd,
                    characterOffset: runningCharOffset,
                    markerType: Paragraph.classify(line)
                ))
            }

            let lineLength = text.distance(from: offset, to: lineEnd) + 1 // +1 for \n
            runningCharOffset += lineLength
            offset = text.index(after: lineEnd)
        }

        return paragraphs
    }
}
