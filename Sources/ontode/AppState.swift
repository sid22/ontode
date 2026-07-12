import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var folderURL: URL?
    @Published var mdFiles: [URL] = []
    @Published var fileTree: [FileNode] = []
    @Published var selectedFile: URL?
    @Published var fileContent: String = ""
    @Published var blocks: [MDBlock] = []
    @Published var searchResults: [SearchResult] = []
    @Published var quickOpenPresented = false
    @Published var focusedBlockID: UUID?
    @Published var editingBlockID: UUID?
    @Published var editingDraft: String = ""
    @Published var searchQuery: String = "" {
        didSet { runSearch() }
    }
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey) }
    }

    static let wholeFileEditID = UUID()
    private static let themeKey = "ontode.theme"

    private let searchIndex: SearchIndex = FTS5SearchIndex()
    private var watcher: FolderWatcher?
    private var editingLineRange: ClosedRange<Int>?

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.themeKey)
        theme = stored.flatMap(AppTheme.init(rawValue:)) ?? .solarizedDark
    }

    func toggleTheme() {
        theme = theme == .solarizedDark ? .solarizedLight : .solarizedDark
    }

    func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openFolder(url)
    }

    func openFolder(_ url: URL) {
        commitEditing()
        folderURL = url
        selectedFile = nil
        fileContent = ""
        blocks = []
        focusedBlockID = nil
        searchQuery = ""
        rescan()

        watcher?.stop()
        watcher = FolderWatcher(url: url) { [weak self] in
            self?.folderDidChange()
        }
        watcher?.start()

        if let first = mdFiles.first {
            selectFile(first)
        }
    }

    func selectFile(_ url: URL) {
        commitEditing()
        focusedBlockID = nil
        selectedFile = url
        loadContent(from: url)
    }

    func relativePath(for url: URL) -> String {
        guard let base = folderURL else { return url.lastPathComponent }
        return String(url.path.dropFirst(base.path.count + 1))
    }

    func openWikilink(_ target: String) {
        let wanted = target.lowercased()
        guard !wanted.isEmpty else { return }
        let match = mdFiles.first { url in
            let relative = relativePath(for: url).lowercased()
            let relativeNoExtension = (relative as NSString).deletingPathExtension
            let name = url.deletingPathExtension().lastPathComponent.lowercased()
            return name == wanted || relative == wanted || relativeNoExtension == wanted
        }
        if let match {
            selectFile(match)
        }
    }

    func selectAdjacentFile(_ delta: Int) {
        guard !mdFiles.isEmpty else { return }
        guard let selectedFile, let index = mdFiles.firstIndex(of: selectedFile) else {
            selectFile(delta > 0 ? mdFiles[0] : mdFiles[mdFiles.count - 1])
            return
        }
        let next = index + delta
        guard mdFiles.indices.contains(next) else { return }
        selectFile(mdFiles[next])
    }

    func moveFocus(_ delta: Int) {
        guard !blocks.isEmpty else { return }
        guard let focusedBlockID, let index = blocks.firstIndex(where: { $0.id == focusedBlockID }) else {
            self.focusedBlockID = delta > 0 ? blocks.first?.id : blocks.last?.id
            return
        }
        let next = index + delta
        guard blocks.indices.contains(next) else { return }
        self.focusedBlockID = blocks[next].id
    }

    func beginEditing(_ block: MDBlock) {
        guard editingBlockID == nil, selectedFile != nil, let lineRange = block.lineRange else { return }
        let lines = fileContent.components(separatedBy: "\n")
        let start = max(1, min(lineRange.lowerBound, lines.count))
        let end = max(start, min(lineRange.upperBound, lines.count))
        editingLineRange = start...end
        editingDraft = lines[(start - 1)...(end - 1)].joined(separator: "\n")
        editingBlockID = block.id
        focusedBlockID = block.id
    }

    func beginEditingWholeFile() {
        guard editingBlockID == nil, selectedFile != nil else { return }
        editingDraft = fileContent
        editingLineRange = nil
        editingBlockID = Self.wholeFileEditID
    }

    func beginEditingFocusedBlock() {
        guard editingBlockID == nil, selectedFile != nil else { return }
        if blocks.isEmpty {
            beginEditingWholeFile()
            return
        }
        guard let block = blocks.first(where: { $0.id == focusedBlockID }) ?? blocks.first else { return }
        beginEditing(block)
    }

    func commitEditing() {
        guard editingBlockID != nil else { return }
        guard let selectedFile else {
            editingBlockID = nil
            editingLineRange = nil
            return
        }
        let newText: String
        if let range = editingLineRange {
            var lines = fileContent.components(separatedBy: "\n")
            lines.replaceSubrange(
                (range.lowerBound - 1)...(range.upperBound - 1),
                with: editingDraft.components(separatedBy: "\n")
            )
            newText = lines.joined(separator: "\n")
        } else {
            newText = editingDraft
        }
        let editedLine = editingLineRange?.lowerBound
        if newText == fileContent {
            editingBlockID = nil
            editingLineRange = nil
            return
        }
        do {
            try newText.write(to: selectedFile, atomically: true, encoding: .utf8)
        } catch {
            return
        }
        editingBlockID = nil
        editingLineRange = nil
        fileContent = newText
        blocks = MarkdownBuilder.blocks(from: newText)
        if let editedLine {
            focusedBlockID = blocks.first { block in
                guard let range = block.lineRange else { return false }
                return range.contains(editedLine) || range.lowerBound >= editedLine
            }?.id
        }
        if let folderURL {
            searchIndex.reindex(folder: folderURL, files: mdFiles)
            runSearch()
        }
    }

    func quickOpenMatches(for query: String) -> [URL] {
        let needle = query.lowercased().filter { !$0.isWhitespace }
        guard !needle.isEmpty else { return mdFiles }
        return mdFiles
            .compactMap { url -> (URL, Int)? in
                guard let score = Self.fuzzyScore(needle, in: relativePath(for: url).lowercased()) else {
                    return nil
                }
                return (url, score)
            }
            .sorted { $0.1 == $1.1 ? $0.0.path < $1.0.path : $0.1 < $1.1 }
            .map(\.0)
    }

    private func rescan() {
        guard let folderURL else { return }
        mdFiles = FolderScanner.scan(folder: folderURL)
        fileTree = FileNode.tree(for: mdFiles, in: folderURL)
        searchIndex.reindex(folder: folderURL, files: mdFiles)
    }

    private func folderDidChange() {
        guard folderURL != nil else { return }
        rescan()
        if let selectedFile {
            if mdFiles.contains(selectedFile) {
                if editingBlockID == nil {
                    loadContent(from: selectedFile)
                }
            } else {
                self.selectedFile = nil
                editingBlockID = nil
                editingLineRange = nil
                focusedBlockID = nil
                fileContent = ""
                blocks = []
            }
        }
        runSearch()
    }

    private func loadContent(from url: URL) {
        do {
            fileContent = try String(contentsOf: url, encoding: .utf8)
            blocks = MarkdownBuilder.blocks(from: fileContent)
        } catch {
            fileContent = "Could not read file: \(error.localizedDescription)"
            blocks = [MDBlock(kind: .paragraph(AttributedString(fileContent)))]
        }
    }

    private func runSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        searchResults = trimmed.isEmpty ? [] : searchIndex.search(trimmed)
    }

    private static func fuzzyScore(_ query: String, in candidate: String) -> Int? {
        if let range = candidate.range(of: query) {
            return candidate.distance(from: candidate.startIndex, to: range.lowerBound)
        }
        var queryIndex = query.startIndex
        for character in candidate {
            if queryIndex < query.endIndex, character == query[queryIndex] {
                queryIndex = query.index(after: queryIndex)
            }
        }
        return queryIndex == query.endIndex ? 1000 + candidate.count : nil
    }
}
