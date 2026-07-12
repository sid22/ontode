import AppKit
import SwiftUI

struct FileListView: View {
    @EnvironmentObject var appState: AppState

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
        .navigationTitle(appState.folderURL?.lastPathComponent ?? "")
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItem {
                Button(action: { appState.openFolderPicker() }) {
                    Label("Open Folder", systemImage: "folder")
                }
                .help("Open another folder (⌘O)")
            }
        }
    }

    private var treeList: some View {
        List(selection: selection) {
            OutlineGroup(appState.fileTree, children: \.children) { node in
                Label(node.name, systemImage: node.children == nil ? "doc.text" : "folder.fill")
                    .help(node.url.path)
                    .tag(node.url)
                    .selectionDisabled(node.children != nil)
                    .contextMenu {
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([node.url])
                        }
                    }
            }
        }
        .listStyle(.sidebar)
    }

    private var resultsList: some View {
        List(appState.searchResults, selection: selection) { result in
            VStack(alignment: .leading, spacing: 3) {
                Label(result.relativePath, systemImage: "doc.text")
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
    }

    private var subtitle: String {
        if isSearching {
            return "\(appState.searchResults.count) match\(appState.searchResults.count == 1 ? "" : "es")"
        }
        return "\(appState.mdFiles.count) file\(appState.mdFiles.count == 1 ? "" : "s")"
    }
}
