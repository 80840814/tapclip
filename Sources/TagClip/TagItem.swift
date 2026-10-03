import Foundation

struct TagItem: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var filePaths: [String]

    init(id: UUID = UUID(), name: String, filePaths: [String] = []) {
        self.id = id
        self.name = name
        self.filePaths = filePaths
    }
}
