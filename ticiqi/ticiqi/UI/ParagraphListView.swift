//  Paragraph list sheet — displays heading markers for quick navigation
//  ticiqi
//

import SwiftUI

struct ParagraphListView: View {
    let headings: [ParagraphPosition]
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if headings.isEmpty {
                    ContentUnavailableView(
                        "无标题段落",
                        systemImage: "text.alignleft",
                        description: Text("文稿中未找到 Markdown 标题（# 开头），请添加标题后重试。")
                    )
                } else {
                    ForEach(headings) { position in
                        Button {
                            onSelect(position.paragraphIndex)
                            dismiss()
                        } label: {
                            HStack {
                                Text(position.displayLabel)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(Int(position.estimatedProgress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .navigationTitle("段落导航")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
