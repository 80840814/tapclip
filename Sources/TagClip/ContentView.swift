import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: TagStore
    @State private var showingEditor = false
    @State private var editingTag: TagItem?
    @State private var alertMessage: String?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            if store.tags.isEmpty {
                emptyState
            } else {
                tagList
            }
        }
        .frame(minWidth: 420, minHeight: 520)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    exportTags()
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .help("把标签数据导出为 JSON 文件")
                Button {
                    importTags()
                } label: {
                    Label("导入", systemImage: "square.and.arrow.down")
                }
                .help("从 JSON 文件导入标签数据（覆盖当前数据）")
                Button {
                    editingTag = nil
                    showingEditor = true
                } label: {
                    Label("新建标签", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            TagEditorView(tag: editingTag)
        }
        .alert("提示", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var tagList: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                ForEach(store.tags) { tag in
                    TagCardView(tag: tag) { result in
                        handleCopyResult(result, for: tag)
                    }
                    .contextMenu {
                        Button("编辑") {
                            editingTag = tag
                            showingEditor = true
                        }
                        Button("删除", role: .destructive) {
                            store.deleteTag(id: tag.id)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tag")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("还没有标签")
                .font(.title2)
                .fontWeight(.semibold)
            Text("点击右上角 + 新建一个标签，\n绑定你要发送的文件。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                editingTag = nil
                showingEditor = true
            } label: {
                Label("新建标签", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func exportTags() {
        let panel = NSSavePanel()
        panel.title = "导出标签数据"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "TagClip-tags-\(Self.dateFormatter.string(from: Date())).json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            alertMessage = store.exportTags(to: url) ? "已导出 \(store.tags.count) 个标签。" : "导出失败，请检查保存位置后重试。"
        }
    }

    private func importTags() {
        let panel = NSOpenPanel()
        panel.title = "导入标签数据"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "选择要导入的标签 JSON 文件（将覆盖当前数据）"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if store.importTags(from: url) {
                alertMessage = "导入成功，共 \(store.tags.count) 个标签。"
            } else {
                alertMessage = "导入失败：文件格式无法识别。"
            }
        }
    }

    private func handleCopyResult(_ result: TagStore.CopyResult, for tag: TagItem) {
        switch result {
        case .noFiles:
            alertMessage = "标签「\(tag.name)」绑定的文件都不存在了。\n请编辑标签重新绑定，或检查文件是否被移动 / 删除。"
        case .success(let copied, let skipped):
            if skipped > 0 {
                alertMessage = "已复制 \(copied) 个文件，\(skipped) 个文件不存在已被跳过。\n可在聊天窗口直接 Cmd+V 发送。"
            }
            // 全部成功时静默，只播提示音
        }
    }
}

struct TagCardView: View {
    @EnvironmentObject var store: TagStore
    let tag: TagItem
    var onCopied: (TagStore.CopyResult) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .foregroundStyle(Color.accentColor)
                Text(tag.name)
                    .font(.headline)
                    .lineLimit(1)
            }
            if tag.filePaths.isEmpty {
                Text("未绑定文件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(tag.filePaths.count) 个文件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    store.copiedTagID == tag.id ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            onCopied(store.copyFiles(for: tag))
        }
    }
}
