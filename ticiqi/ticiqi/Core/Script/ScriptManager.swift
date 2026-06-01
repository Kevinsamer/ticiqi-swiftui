//  Script lifecycle manager — coordinates import, indexing, hot-reload, and navigation
//  ticiqi
//

import SwiftUI

@MainActor
@Observable final class ScriptManager {
    private(set) var currentDocument: ScriptDocument?
    private(set) var paragraphPositions: [ParagraphPosition] = []

    var headingPositions: [ParagraphPosition] {
        ParagraphIndexer.headingPositions(from: paragraphPositions)
    }

    var isEmpty: Bool {
        currentDocument == nil
    }

    // MARK: - Load

    func loadDocument(from url: URL) async throws -> ScriptDocument {
        let document = try await ScriptImporter.import(url: url)
        currentDocument = document
        return document
    }

    func loadDocument(content: String, title: String = "未命名文稿") -> ScriptDocument {
        let document = ScriptImporter.import(content: content, title: title)
        currentDocument = document
        return document
    }

    // MARK: - Hot reload

    func hotReload(newContent: String, engine: PrompterEngine, title: String? = nil) {
        guard let doc = currentDocument else {
            let newDoc = ScriptImporter.import(content: newContent, title: title ?? "未命名文稿")
            currentDocument = newDoc
            engine.load(document: newDoc)
            rebuildIndex(fontSize: engine.state.fontSize, width: engine.state.viewWidth)
            return
        }

        let updatedTitle = title ?? doc.title
        var updatedDoc = doc
        updatedDoc.updateContent(newContent)
        updatedDoc.title = updatedTitle
        currentDocument = updatedDoc

        engine.hotReload(document: updatedDoc)
        rebuildIndex(fontSize: engine.state.fontSize, width: engine.state.viewWidth)
    }

    // MARK: - Paragraph navigation

    func progressForParagraph(at index: Int) -> Double? {
        guard index >= 0, index < paragraphPositions.count else { return nil }
        return paragraphPositions[index].estimatedProgress
    }

    func progressForHeading(at headingIndex: Int) -> Double? {
        let headings = headingPositions
        guard headingIndex >= 0, headingIndex < headings.count else { return nil }
        return headings[headingIndex].estimatedProgress
    }

    // MARK: - Index

    func rebuildIndex(fontSize: CGFloat, width: CGFloat) {
        guard let doc = currentDocument else {
            paragraphPositions = []
            return
        }
        paragraphPositions = ParagraphIndexer.index(
            document: doc,
            fontSize: fontSize,
            width: width
        )
    }
}
