//  Script card — grid tile displaying script title, preview, and metadata
//  ticiqi
//

import SwiftUI

struct ScriptCardView: View {
    let script: StoredScript
    var onRename: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(script.title)
                .font(.headline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider().padding(.vertical, 6)

            Text(script.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Text("\(script.content.count)字 · \(script.paragraphCount)段")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .bottomTrailing) {
            if onRename != nil || onDelete != nil {
                cardMenu
            }
        }
    }

    private var cardMenu: some View {
        Menu {
            if let onRename {
                Button(action: onRename) {
                    Label("重命名", systemImage: "pencil")
                }
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .frame(width: 44, height: 44)
        .padding(6)
    }
}

// MARK: - Add new card

struct AddScriptCardView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("导入新文稿")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(.tertiary)
        )
    }
}
