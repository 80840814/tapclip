import SwiftUI
import UniformTypeIdentifiers

struct TagEditorView: View {
    @EnvironmentObject var store: TagStore
    @Environment(\.dismiss) private var dismiss

    let tag: TagItem?

    @State private var name: String = ""
    @State private var filePaths: [String] = []

    init(tag: TagItem?) {
        self.tag = tag
        _name = State(initialValue: tag?.name ?? "")
        _filePaths = State(initialValue: tag?.filePaths ?? [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tag == nil ? "新建标签" : "编辑标签")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("标签名称", text: $name)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("绑定的文件（\(filePaths.count) 个）")
                        .font(.headline)
                    Spacer()
                    Button {
                        openFilePicker()
                    } label: {
                        Label("添加文件", systemImage: "plus")
                    }
                }

                if filePaths.isEmpty {
                    Text("还没有文件，点击\"添加文件\"选择。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(Array(filePaths.enumerated()), id: \.offset) { index, path in
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .foregroundStyle(.secondary)
                                    Text(URL(fileURLWithPath: path).lastPathComponent)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button {
                                        filePaths.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460, height: 480)
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.message = "选择要绑定到这个标签的文件或文件夹"
        panel.begin { response in
            if response == .OK {
                filePaths.append(contentsOf: panel.urls.map { $0.path })
            }
        }
    }

    private func save() {
        if let tag {
            store.updateTag(id: tag.id, name: name, filePaths: filePaths)
        } else {
            store.addTag(named: name, filePaths: filePaths)
        }
        dismiss()
    }
}
