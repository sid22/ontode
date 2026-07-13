import AppKit
import SwiftUI

struct FileListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appTheme) private var theme
    @AppStorage("ontode.tagsExpanded") private var tagsExpanded = true
    @State private var savingQuery = false
    @State private var queryName = ""

    private var selection: Binding<URL?> {
        Binding(
            get: { appState.selectedFile },
            set: { url in
                guard let url else { return }
                appState.selectFile(url)
            }
        )
    }

    private var isSearching: Bool {
        !appState.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Group {
            if isSearching {
                resultsList
            } else if appState.hasSidebarFilter {
                filteredList
            } else {
                treeList
            }
        }
        .searchable(text: $appState.searchQuery, placement: .sidebar, prompt: "Search")
        .alert("Save Query", isPresented: $savingQuery) {
            TextField("Name", text: $queryName)
            Button("Save") { appState.saveCurrentFilter(named: queryName) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save the current tag filter as a reusable query.")
        }
        .navigationTitle(title)
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItem {
                Button(action: { appState.createNewFile() }) {
                    Label("New File", systemImage: "doc.badge.plus")
                }
                .help("New File")
                .disabled(!appState.hasFolders)
            }
            ToolbarItem {
                Button(action: { appState.openFolderPicker() }) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                .help("Add a folder (⌘O)")
            }
        }
    }

    private var treeList: some View {
        List(selection: selection) {
            if !appState.noteIndex.tagCounts.isEmpty {
                Section(isExpanded: $tagsExpanded) {
                    ForEach(appState.noteIndex.tagCounts) { entry in
                        HStack {
                            Label(entry.tag, systemImage: "number")
                            Spacer()
                            Text("\(entry.count)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { appState.tagFilter = entry.tag }
                        .selectionDisabled(true)
                    }
                } header: {
                    Text("Tags")
                }
            }
            if !appState.savedQueries.isEmpty {
                Section("Queries") {
                    ForEach(appState.savedQueries) { query in
                        Label(query.name, systemImage: "line.3.horizontal.decrease.circle")
                            .contentShape(Rectangle())
                            .onTapGesture { appState.activeSavedQuery = query }
                            .selectionDisabled(true)
                            .contextMenu {
                                Button("Delete Query", role: .destructive) {
                                    appState.deleteSavedQuery(query)
                                }
                            }
                    }
                }
            }
            ForEach(appState.workspaceFolders) { folder in
                Section {
                    OutlineGroup(folder.tree, children: \.children) { node in
                        if node.children == nil {
                            FileNodeRow(node: node, appState: appState) {
                                appState.moveToTrash(node.url)
                            }
                            .help(node.url.path)
                            .tag(node.url)
                            .selectionDisabled(false)
                            .contextMenu {
                                Button("Open in Default Editor") {
                                    NSWorkspace.shared.open(node.url)
                                }
                                Button("Reveal in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([node.url])
                                }
                                Divider()
                                Button("Copy Path") {
                                    copy(node.url.path)
                                }
                                Button("Copy Wikilink") {
                                    copy("[[" + node.url.deletingPathExtension().lastPathComponent + "]]")
                                }
                                Divider()
                                Button("Move to Trash", role: .destructive) {
                                    appState.moveToTrash(node.url)
                                }
                            }
                        } else {
                            Label(node.name, systemImage: "folder.fill")
                                .help(node.url.path)
                                .tag(node.url)
                                .selectionDisabled(true)
                                .contextMenu {
                                    Button("Reveal in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([node.url])
                                    }
                                }
                        }
                    }
                } header: {
                    HStack {
                        Text(folder.url.lastPathComponent)
                        Spacer()
                        if folder.isScanning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("\(folder.files.count)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button("New File in \(folder.url.lastPathComponent)") {
                            appState.createNewFile(in: folder.url)
                        }
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([folder.url])
                        }
                        Divider()
                        Button("Remove from Sidebar") {
                            appState.removeFolder(folder.url)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.sidebar)
    }

    private var filteredList: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.space2) {
                Label(
                    filterTitle,
                    systemImage: appState.tagFilter != nil ? "number" : "line.3.horizontal.decrease.circle"
                )
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
                Spacer()
                if appState.tagFilter != nil {
                    Button(action: { queryName = ""; savingQuery = true }) {
                        Image(systemName: "bookmark")
                    }
                    .buttonStyle(.plain)
                    .help("Save current filter as query")
                }
                Button(action: { appState.clearSidebarFilter() }) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .help("Clear filter")
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, Metrics.space3)
            .padding(.vertical, Metrics.space2)
            List(appState.filteredFiles, id: \.self, selection: selection) { url in
                Label(appState.displayPath(for: url), systemImage: "doc.text")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(url.path)
                    .tag(url)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(theme.sidebar)
    }

    private var filterTitle: String {
        if let tag = appState.tagFilter {
            return "#" + tag
        }
        return appState.activeSavedQuery?.name ?? ""
    }

    private var resultsList: some View {
        List(appState.searchResults, selection: selection) { result in
            VStack(alignment: .leading, spacing: 3) {
                Label(result.displayPath, systemImage: "doc.text")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(result.snippet)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.vertical, 3)
            .tag(result.url)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.sidebar)
    }

    private var title: String {
        switch appState.workspaceFolders.count {
        case 0: return ""
        case 1: return appState.workspaceFolders[0].url.lastPathComponent
        default: return "\(appState.workspaceFolders.count) Folders"
        }
    }

    private var subtitle: String {
        if isSearching {
            return "\(appState.searchResults.count) match\(appState.searchResults.count == 1 ? "" : "es")"
        }
        if appState.hasSidebarFilter {
            return "\(appState.filteredFiles.count) match\(appState.filteredFiles.count == 1 ? "" : "es")"
        }
        return "\(appState.mdFiles.count) file\(appState.mdFiles.count == 1 ? "" : "s")"
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    // MARK: - FileNodeRow

    private struct FileNodeRow: View {
        let node: FileNode
        let appState: AppState
        let deleteAction: () -> Void

        @State private var isHovered = false

        var body: some View {
            HStack {
                Label(node.name, systemImage: "doc.text")
                Spacer()
                Button(action: deleteAction) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(isHovered ? .red : .clear)
            }
            .onHover { isHovered = $0 }
        }
    }
}
