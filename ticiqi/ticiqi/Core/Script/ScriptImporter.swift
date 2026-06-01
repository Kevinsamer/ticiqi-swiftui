//  Script file importer — reads TXT/Markdown/DOCX from disk on background thread
//  ticiqi
//

import Foundation
import UniformTypeIdentifiers
import Compression

enum ScriptFormat {
    case txt
    case markdown
    case docx
}

enum ScriptImporter {

    // MARK: - Format detection

    static func detectFormat(url: URL) -> ScriptFormat {
        switch url.pathExtension.lowercased() {
        case "md", "markdown":
            return .markdown
        case "docx":
            return .docx
        default:
            return .txt
        }
    }

    static func isSupported(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["txt", "md", "markdown", "docx"].contains(ext)
    }

    // MARK: - Import as ScriptDocument

    static func `import`(url: URL) async throws -> ScriptDocument {
        let (title, content) = try await importRaw(from: url)
        return ScriptDocument(title: title, content: content)
    }

    static func `import`(content: String, title: String = "未命名文稿") -> ScriptDocument {
        ScriptDocument(title: title, content: content)
    }

    // MARK: - Raw import (returns title + content for ScriptStore)

    static func importRaw(from url: URL) async throws -> (String, String) {
        guard url.startAccessingSecurityScopedResource() else {
            throw ScriptImportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let title = url.deletingPathExtension().lastPathComponent
        let format = detectFormat(url: url)

        let content: String = try await Task.detached(priority: .userInitiated) {
            switch format {
            case .docx:
                let data = try Data(contentsOf: url)
                return try DocxParser.extractText(from: data)
            case .txt, .markdown:
                let text = try String(contentsOf: url, encoding: .utf8)
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw ScriptImportError.emptyFile
                }
                return text
            }
        }.value

        return (title, content)
    }
}

// MARK: - DOCX parser (ZIP → word/document.xml → plain text)

private enum DocxParser {

    static func extractText(from data: Data) throws -> String {
        guard let xmlData = try extractDocumentXML(from: data) else {
            throw ScriptImportError.readFailed("无法解析 Word 文档结构")
        }
        let xml = String(data: xmlData, encoding: .utf8) ?? ""
        let text = stripXML(xml)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScriptImportError.emptyFile
        }
        return text
    }

    private static func extractDocumentXML(from data: Data) throws -> Data? {
        let count = data.count

        // Find ZIP End of Central Directory (EOCD) signature: PK\x05\x06
        var eocdOffset = -1
        for i in stride(from: count - 22, through: max(0, count - 66000), by: -1) {
            if data[i] == 0x50 && data[i+1] == 0x4B && data[i+2] == 0x05 && data[i+3] == 0x06 {
                eocdOffset = i
                break
            }
        }
        guard eocdOffset >= 0 else { return nil }

        let cdOffset = Int(data.readUInt32(eocdOffset + 16))
        let cdSize = Int(data.readUInt32(eocdOffset + 12))

        // Scan central directory for word/document.xml
        var pos = cdOffset
        let cdEnd = cdOffset + cdSize
        var foundLocalOffset = -1
        var foundCompMethod: UInt16 = 0
        var foundCompSize = 0

        while pos < cdEnd - 46 {
            guard data[pos] == 0x50 && data[pos+1] == 0x4B && data[pos+2] == 0x01 && data[pos+3] == 0x02 else {
                pos += 1
                continue
            }
            let nameLen = Int(data.readUInt16(pos + 28))
            let extraLen = Int(data.readUInt16(pos + 30))
            let commentLen = Int(data.readUInt16(pos + 32))

            let nameData = data.subdata(in: pos + 46..<pos + 46 + nameLen)
            let name = String(data: nameData, encoding: .utf8) ?? ""

            if name == "word/document.xml" {
                foundCompMethod = data.readUInt16(pos + 10)
                foundCompSize = Int(data.readUInt32(pos + 20))
                foundLocalOffset = Int(data.readUInt32(pos + 42))
                break
            }
            pos += 46 + nameLen + extraLen + commentLen
        }

        guard foundLocalOffset >= 0 else { return nil }

        let localNameLen = Int(data.readUInt16(foundLocalOffset + 26))
        let localExtraLen = Int(data.readUInt16(foundLocalOffset + 28))
        let dataStart = foundLocalOffset + 30 + localNameLen + localExtraLen
        let compressedData = data.subdata(in: dataStart..<dataStart + foundCompSize)

        if foundCompMethod == 0 {
            return compressedData
        } else if foundCompMethod == 8 {
            return try decompressDeflate(compressedData)
        }
        return nil
    }

    private static func decompressDeflate(_ data: Data) throws -> Data {
        let bufferSize = 131072
        var output = Data(count: bufferSize)
        let decompressed = data.withUnsafeBytes { src in
            output.withUnsafeMutableBytes { dst in
                compression_decode_buffer(
                    dst.bindMemory(to: UInt8.self).baseAddress!, bufferSize,
                    src.bindMemory(to: UInt8.self).baseAddress!, data.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard decompressed > 0 else { return Data() }
        return output.prefix(decompressed)
    }

    private static func stripXML(_ xml: String) -> String {
        xml.replacingOccurrences(of: "<w:p[^>]*>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Data {
    func readUInt16(_ offset: Int) -> UInt16 {
        UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func readUInt32(_ offset: Int) -> UInt32 {
        UInt32(self[offset]) | UInt32(self[offset + 1]) << 8
            | UInt32(self[offset + 2]) << 16 | UInt32(self[offset + 3]) << 24
    }
}

// MARK: - Error

enum ScriptImportError: LocalizedError {
    case accessDenied
    case readFailed(String)
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "无法访问所选文件"
        case .readFailed(let detail):
            return "读取文件失败: \(detail)"
        case .emptyFile:
            return "文件内容为空"
        }
    }
}
