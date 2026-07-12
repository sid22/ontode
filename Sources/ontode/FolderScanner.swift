import Foundation

enum FolderScanner {
    static let mdExtensions: Set<String> = ["md", "markdown"]

    static func scan(folder: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [URL] = []
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            guard mdExtensions.contains(url.pathExtension.lowercased()) else { continue }
            results.append(url)
        }
        return results.sorted { $0.path < $1.path }
    }
}
