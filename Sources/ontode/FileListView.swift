import AppKit
import SwiftUI

struct FileListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appTheme) private var theme

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
            } else {
                treeList
            }
        }
        .searchable(text: $appState.searchQuery, placement: .sidebar, prompt: "Search")
        .navigationTitle(title)
        .navigationSubtitle(subtitle)
        .toolbar {
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
            ForEach(appState.workspaceFolders) { folder in
                Section {
                    OutlineGroup(folder.tree, children: \.children) { node in
                        Label(node.name, systemImage: node.children == nil ? "doc.text" : "folder.fill")
                            .help(node.url.path)
                            .tag(node.url)
                            .selectionDisabled(node.children != nil)
                            .contextMenu {
                                if node.children == nil {
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
                                } else {
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
                        Text("\(folder.files.count)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
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
        return "\(appState.mdFiles.count) file\(appState.mdFiles.count == 1 ? "" : "s")"
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
