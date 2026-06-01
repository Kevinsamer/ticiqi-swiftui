//  Script persistence store — manages script CRUD operations with JSON file storage
//  ticiqi
//

import Foundation

struct StoredScript: Codable, Hashable, Identifiable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    var paragraphCount: Int {
        content.components(separatedBy: "\n").filter { !$0.isEmpty }.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: StoredScript, rhs: StoredScript) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
@Observable final class ScriptStore {
    private(set) var scripts: [StoredScript] = []

    private var storageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("scripts.json")
    }

    // MARK: - Load

    func loadAll() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([StoredScript].self, from: data)
        else {
            scripts = []
            return
        }
        scripts = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Save

    func save(_ script: StoredScript) {
        var updated = scripts
        if let index = updated.firstIndex(where: { $0.id == script.id }) {
            updated[index] = script
        } else {
            updated.insert(script, at: 0)
        }
        updated.sort { $0.updatedAt > $1.updatedAt }
        scripts = updated
        persist()
    }

    // MARK: - Import

    func importFromURL(_ url: URL) async throws -> StoredScript {
        let (title, content) = try await ScriptImporter.importRaw(from: url)
        let script = StoredScript(
            id: UUID(),
            title: title,
            content: content,
            createdAt: Date(),
            updatedAt: Date()
        )
        save(script)
        return script
    }

    func importFromContent(_ content: String, title: String = "未命名文稿") -> StoredScript {
        let script = StoredScript(
            id: UUID(),
            title: title,
            content: content,
            createdAt: Date(),
            updatedAt: Date()
        )
        save(script)
        return script
    }

    // MARK: - Update

    func updateTitle(id: UUID, newTitle: String) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        var updated = scripts
        updated[index].title = newTitle
        updated[index].updatedAt = Date()
        updated.sort { $0.updatedAt > $1.updatedAt }
        scripts = updated
        persist()
    }

    func updateContent(id: UUID, newContent: String) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        var updated = scripts
        updated[index].content = newContent
        updated[index].updatedAt = Date()
        updated.sort { $0.updatedAt > $1.updatedAt }
        scripts = updated
        persist()
    }

    // MARK: - Delete

    func delete(id: UUID) {
        scripts = scripts.filter { $0.id != id }
        persist()
    }

    // MARK: - Convert

    func toDocument(_ script: StoredScript) -> ScriptDocument {
        ScriptDocument(id: script.id, title: script.title, content: script.content,
                       createdAt: script.createdAt, updatedAt: script.updatedAt)
    }

    // MARK: - Private

    private func persist() {
        guard let data = try? JSONEncoder().encode(scripts) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
