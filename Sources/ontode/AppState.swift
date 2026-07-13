import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var workspaceFolders: [WorkspaceFolder] = []
    @Published var mdFiles: [URL] = []
    @Published var openTabs: [URL] = []
    @Published var selectedFile: URL?
    @Published var fileContent: String = ""
    @Published var blocks: [MDBlock] = []
    @Published var searchResults: [SearchResult] = []
    @Published var quickOpenPresented = false
    @Published var showSource = false
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
    private static let foldersKey = "ontode.folders"
    private static let tabsKey = "ontode.openTabs"
    private static let selectionKey = "ontode.selectedFile"

    private let searchIndex: SearchIndex = FTS5SearchIndex()
    private var watchers: [URL: FolderWatcher] = [:]
    private var editingLineRange: ClosedRange<Int>?
    private var scanGeneration = 0
    private var scanTask: Task<Void, Never>?

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.themeKey) ?? ""
        theme = stored.lowercased().contains("light") ? .light : .dark
        restoreSession()
    }

    var hasFolders: Bool {
        !workspaceFolders.isEmpty
    }

    var wordCount: Int {
        fileContent.split(whereSeparator: \.isWhitespace).count
    }

    func toggleTheme() {
        theme = theme == .dark ? .light : .dark
    }

    func toggleSource() {
        commitEditing()
        showSource.toggle()
    }

    func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = "Add"

        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            addFolder(url)
        }
    }

    func addFolder(_ url: URL) {
        guard folderRoot(for: url) == nil else { return }
        guard !workspaceFolders.contains(where: { $0.url.path.hasPrefix(url.path + "/") }) else { return }
        commitEditing()
        attachFolder(url)
        persistFolders()
        rescan()
    }

    func removeFolder(_ url: URL) {
        commitEditing()
        watchers[url]?.stop()
        watchers[url] = nil
        workspaceFolders.removeAll { $0.url == url }
        persistFolders()
        openTabs.removeAll { folderRoot(for: $0) == nil }
        if let selectedFile, !openTabs.contains(selectedFile) {
            showFile(openTabs.first)
        }
        persistSession()
        rescan()
    }

    func folderRoot(for url: URL) -> URL? {
        workspaceFolders
            .map(\.url)
            .filter { url.path == $0.path || url.path.hasPrefix($0.path + "/") }
            .max { $0.path.count < $1.path.count }
    }

    func selectFile(_ url: URL) {
        commitEditing()
        if !openTabs.contains(url) {
            openTabs.append(url)
        }
        focusedBlockID = nil
        selectedFile = url
        loadContent(from: url)
        persistSession()
    }

    func closeTab(_ url: URL) {
        guard let index = openTabs.firstIndex(of: url) else { return }
        commitEditing()
        openTabs.remove(at: index)
        if selectedFile == url {
            let fallback = openTabs.indices.contains(index) ? openTabs[index] : openTabs.last
            showFile(fallback)
        }
        persistSession()
    }

    func closeCurrentTab() {
        if let selectedFile {
            closeTab(selectedFile)
        } else {
            NSApp.keyWindow?.performClose(nil)
        }
    }

    func selectAdjacentTab(_ delta: Int) {
        guard !openTabs.isEmpty else { return }
        guard let selectedFile, let index = openTabs.firstIndex(of: selectedFile) else {
            selectFile(delta > 0 ? openTabs[0] : openTabs[openTabs.count - 1])
            return
        }
        let next = (index + delta + openTabs.count) % openTabs.count
        selectFile(openTabs[next])
    }

    func createNewFile() {
        let root = selectedFile.flatMap { folderRoot(for: $0) } ?? workspaceFolders.first?.url
        guard let root else { return }
        createNewFile(in: root)
    }

    func createNewFile(in root: URL) {
        commitEditing()
        var name = "Untitled.md"
        var counter = 2
        while FileManager.default.fileExists(atPath: root.appendingPathComponent(name).path) {
            name = "Untitled \(counter).md"
            counter += 1
        }
        let url = root.appendingPathComponent(name)
        guard FileManager.default.createFile(atPath: url.path, contents: Data()) else { return }
        rescan()
        selectFile(url)
        showSource = false
        beginEditingWholeFile()
    }

    func moveToTrash(_ url: URL) {
        commitEditing()
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch {
            return
        }
        if openTabs.contains(url) {
            closeTab(url)
        }
        rescan()
    }

    func relativePath(for url: URL) -> String {
        guard let base = folderRoot(for: url) else { return url.lastPathComponent }
        return String(url.path.dropFirst(base.path.count + 1))
    }

    func displayPath(for url: URL) -> String {
        guard let base = folderRoot(for: url) else { return url.lastPathComponent }
        let relative = String(url.path.dropFirst(base.path.count + 1))
        return workspaceFolders.count > 1 ? base.lastPathComponent + "/" + relative : relative
    }

    func breadcrumb(for url: URL) -> [String] {
        var parts = relativePath(for: url).split(separator: "/").map(String.init)
        if workspaceFolders.count > 1, let base = folderRoot(for: url) {
            parts.insert(base.lastPathComponent, at: 0)
        }
        if let last = parts.last {
            parts[parts.count - 1] = (last as NSString).deletingPathExtension
        }
        return parts
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
        reindexSearch()
        runSearch()
    }

    func quickOpenMatches(for query: String) -> [URL] {
        let needle = query.lowercased().filter { !$0.isWhitespace }
        guard !needle.isEmpty else { return mdFiles }
        return mdFiles
            .compactMap { url -> (URL, Int)? in
                guard let score = Self.fuzzyScore(needle, in: displayPath(for: url).lowercased()) else {
                    return nil
                }
                return (url, score)
            }
            .sorted { $0.1 == $1.1 ? $0.0.path < $1.0.path : $0.1 < $1.1 }
            .map(\.0)
    }

    private func attachFolder(_ url: URL) {
        workspaceFolders.append(WorkspaceFolder(url: url))
        let watcher = FolderWatcher(url: url) { [weak self] in
            self?.folderDidChange()
        }
        watchers[url] = watcher
        watcher.start()
    }

    private func restoreSession() {
        let defaults = UserDefaults.standard
        var isDirectory: ObjCBool = false
        for path in defaults.stringArray(forKey: Self.foldersKey) ?? [] {
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            let url = URL(fileURLWithPath: path)
            guard folderRoot(for: url) == nil else { continue }
            attachFolder(url)
        }
        guard hasFolders else { return }
        openTabs = (defaults.stringArray(forKey: Self.tabsKey) ?? [])
            .map { URL(fileURLWithPath: $0) }
            .filter { folderRoot(for: $0) != nil && FileManager.default.fileExists(atPath: $0.path) }
        if let selectedPath = defaults.string(forKey: Self.selectionKey) {
            let url = URL(fileURLWithPath: selectedPath)
            if openTabs.contains(url) {
                selectedFile = url
                loadContent(from: url)
            }
        }
        if selectedFile == nil, let first = openTabs.first {
            selectedFile = first
            loadContent(from: first)
        }
        rescan()
    }

    private func persistFolders() {
        UserDefaults.standard.set(workspaceFolders.map(\.url.path), forKey: Self.foldersKey)
    }

    private func persistSession() {
        let defaults = UserDefaults.standard
        defaults.set(openTabs.map(\.path), forKey: Self.tabsKey)
        defaults.set(selectedFile?.path, forKey: Self.selectionKey)
    }

    private func showFile(_ url: URL?) {
        editingBlockID = nil
        editingLineRange = nil
        focusedBlockID = nil
        selectedFile = url
        if let url {
            loadContent(from: url)
        } else {
            fileContent = ""
            blocks = []
        }
    }

    private func rescan() {
        scanGeneration += 1
        let generation = scanGeneration
        let roots = workspaceFolders.map(\.url)
        scanTask?.cancel()
        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            var scanned: [(root: URL, files: [URL], tree: [FileNode])] = []
            for root in roots {
                if Task.isCancelled { return }
                let files = FolderScanner.scan(folder: root)
                scanned.append((root, files, FileNode.tree(for: files, in: root)))
            }
            guard !Task.isCancelled, let self else { return }
            let results = scanned
            await MainActor.run {
                guard generation == self.scanGeneration else { return }
                self.applyScan(results)
            }
        }
    }

    private func applyScan(_ scanned: [(root: URL, files: [URL], tree: [FileNode])]) {
        for entry in scanned {
            guard let index = workspaceFolders.firstIndex(where: { $0.url == entry.root }) else { continue }
            workspaceFolders[index].files = entry.files
            workspaceFolders[index].tree = entry.tree
        }
        mdFiles = workspaceFolders.flatMap(\.files)

        let known = Set(mdFiles)
        openTabs.removeAll { !known.contains($0) && !FileManager.default.fileExists(atPath: $0.path) }
        if let selectedFile, !openTabs.contains(selectedFile) {
            showFile(openTabs.first)
            persistSession()
        } else if let selectedFile, editingBlockID == nil,
                  let content = try? String(contentsOf: selectedFile, encoding: .utf8),
                  content != fileContent {
            fileContent = content
            blocks = MarkdownBuilder.blocks(from: content)
            focusedBlockID = nil
        } else if selectedFile == nil, openTabs.isEmpty, let first = mdFiles.first {
            selectFile(first)
        }

        reindexSearch()
        runSearch()
    }

    private func reindexSearch() {
        searchIndex.reindex(mdFiles.map { SearchEntry(url: $0, displayPath: displayPath(for: $0)) })
    }

    private func folderDidChange() {
        guard hasFolders else { return }
        rescan()
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
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        searchIndex.search(trimmed) { [weak self] results in
            guard let self, self.searchQuery.trimmingCharacters(in: .whitespaces) == trimmed else { return }
            self.searchResults = results
        }
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
