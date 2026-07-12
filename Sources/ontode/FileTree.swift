import Foundation

struct WorkspaceFolder: Identifiable {
    let url: URL
    var files: [URL] = []
    var tree: [FileNode] = []

    var id: URL { url }
}

struct FileNode: Identifiable {
    let url: URL
    let name: String
    let children: [FileNode]?

    var id: URL { url }

    static func tree(for files: [URL], in folder: URL) -> [FileNode] {
        let root = DirectoryBuilder(url: folder)
        for file in files {
            let relative = String(file.path.dropFirst(folder.path.count + 1))
            root.insert(file: file, parts: relative.split(separator: "/").map(String.init))
        }
        return root.nodes()
    }
}

private final class DirectoryBuilder {
    let url: URL
    var subdirectories: [String: DirectoryBuilder] = [:]
    var files: [(name: String, url: URL)] = []

    init(url: URL) {
        self.url = url
    }

    func insert(file: URL, parts: [String]) {
        guard let first = parts.first else { return }
        if parts.count == 1 {
            files.append((first, file))
        } else {
            let child = subdirectories[first]
                ?? DirectoryBuilder(url: url.appendingPathComponent(first, isDirectory: true))
            subdirectories[first] = child
            child.insert(file: file, parts: Array(parts.dropFirst()))
        }
    }

    func nodes() -> [FileNode] {
        let directories = subdirectories.keys
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { FileNode(url: subdirectories[$0]!.url, name: $0, children: subdirectories[$0]!.nodes()) }
        let leaves = files
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { FileNode(url: $0.url, name: $0.name, children: nil) }
        return directories + leaves
    }
}
