import Foundation
import AppKit

@MainActor
final class TagStore: ObservableObject {
    static let shared = TagStore()

    @Published var tags: [TagItem] = []
    @Published var copiedTagID: UUID?

    private let fileURL: URL
    private var copiedTagTimer: Timer?

    private struct TagsFile: Codable {
        var version: Int
        var tags: [TagItem]
    }

    enum CopyResult {
        case success(copied: Int, skipped: Int)
        case noFiles
    }

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TagClip", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("tags.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        // 新格式 {version, tags}（macOS 新版本 / Windows 导出）与旧格式纯数组（历史版本）都兼容
        if let wrapper = try? JSONDecoder().decode(TagsFile.self, from: data) {
            tags = wrapper.tags
        } else if let decoded = try? JSONDecoder().decode([TagItem].self, from: data) {
            tags = decoded
        }
    }

    private func save() {
        let wrapper = TagsFile(version: 1, tags: tags)
        guard let data = try? JSONEncoder().encode(wrapper) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func exportTags(to url: URL) -> Bool {
        let wrapper = TagsFile(version: 1, tags: tags)
        guard let data = try? JSONEncoder().encode(wrapper) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func importTags(from url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        if let wrapper = try? JSONDecoder().decode(TagsFile.self, from: data) {
            tags = wrapper.tags
        } else if let decoded = try? JSONDecoder().decode([TagItem].self, from: data) {
            tags = decoded
        } else {
            return false
        }
        save()
        return true
    }

    func addTag(named name: String, filePaths: [String]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tags.append(TagItem(name: trimmed, filePaths: filePaths))
        save()
    }

    func updateTag(id: UUID, name: String, filePaths: [String]) {
        guard let index = tags.firstIndex(where: { $0.id == id }) else { return }
        tags[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tags[index].filePaths = filePaths
        save()
    }

    func deleteTag(id: UUID) {
        tags.removeAll { $0.id == id }
        if copiedTagID == id { copiedTagID = nil }
        save()
    }

    func copyFiles(for tag: TagItem) -> CopyResult {
        // 只复制仍然存在的文件：路径失效的文件写进剪贴板后目标 App 会"找不到文件"而静默失败
        let existing = tag.filePaths
            .compactMap { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        let skipped = tag.filePaths.count - existing.count
        guard !existing.isEmpty else {
            NSSound.beep()
            return .noFiles
        }
        // 模拟 Finder 的 Cmd+C：writeObjects 会同时注册 public.file-url 和
        // NSFilenamesPboardType，微信 / QQ / 邮件都能识别为"附件"。
        // 注意不要再手动写 NSFilenamesPboardType —— 双写会导致目标 App 粘贴出双倍文件。
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(existing as [NSPasteboardWriting])

        copiedTagID = tag.id
        copiedTagTimer?.invalidate()
        copiedTagTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.copiedTagID = nil
            }
        }
        NSSound(named: "Glass")?.play()
        return .success(copied: existing.count, skipped: skipped)
    }
}
