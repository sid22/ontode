# ontode — Implementation Spec (Fable one-shot target)

A lightweight, native macOS Markdown viewer for people who live in `.md` files.
MIT-licensed. Think "Obsidian minus the graph, plugins, and weight."

**Goal of this doc:** be precise enough that a single Fable session can produce a running, buildable
macOS SwiftUI app for **M0** (open folder → index `.md` files → render selected file as raw text).
Every decision below is final — no open questions remain.

---

## Why this exists (short version)

Coding context lives in Markdown (`CLAUDE.md`, design docs, task notes). Managing dozens of these
files today means Obsidian (too heavy, wrong mental model) or paying tokens to read them via an AI
agent. ontode is the free, instant layer: point it at a folder, browse and search your `.md` files,
watch them update live as an agent edits them.

---

## Non-goals for M0 (do not implement)

- No Markdown rendering — raw monospaced text only (M1 adds rendering)
- No live file watching (M3)
- No search (M2)
- No wikilinks (M3)
- No editing
- No sandbox / security-scoped bookmarks (direct file access, no entitlements file needed)
- No app icon, no Info.plist customisation beyond defaults
- No Mac App Store compatibility

---

## Deliverable: M0

A buildable Swift Package (`Package.swift`) that Xcode can open directly (File → Open on the
directory). When run:

1. App opens to a welcome screen with an "Open Folder…" button (also ⌘O).
2. User picks a directory via `NSOpenPanel`.
3. Sidebar shows every `.md` / `.markdown` file found recursively, listed by **relative path** from
   the chosen folder root, sorted alphabetically. Hidden files and non-md files are excluded.
4. Clicking a file shows its **raw text content** in a monospaced `ScrollView` on the right.
5. Window title bar shows the folder name; subtitle shows file count.
6. ⌘O at any time re-opens the folder picker.

---

## Exact project layout

```
ontode/                          ← repo root (this directory)
├── Package.swift
├── PLAN.md
└── Sources/
    └── ontode/
        ├── OntodeApp.swift      ← @main App struct + Commands
        ├── AppState.swift       ← ObservableObject: folder, files, selection, content
        ├── FolderScanner.swift  ← static func scan(folder:) → [URL]
        ├── ContentView.swift    ← switches between WelcomeView and SplitView
        ├── WelcomeView.swift    ← empty state UI
        ├── FileListView.swift   ← NavigationSplitView sidebar
        └── FileReaderView.swift ← raw text detail pane
```

No other files. Do not create an `Info.plist`, `.entitlements`, or Xcode project.

---

## Package.swift (exact content)

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ontode",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ontode",
            path: "Sources/ontode"
        )
    ]
)
```

No external dependencies for M0.

---

## File-by-file specification

### OntodeApp.swift

- `@main struct OntodeApp: App`
- `@StateObject private var appState = AppState()`
- `body`: single `WindowGroup` containing `ContentView().environmentObject(appState)`
- `.commands`: replace `.newItem` group with one `Button("Open Folder…")` calling
  `appState.openFolderPicker()`, keyboard shortcut `⌘O`
- Window minimum size: `.frame(minWidth: 860, minHeight: 520)` on `ContentView`

### AppState.swift

```swift
import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var folderURL: URL?
    @Published var mdFiles: [URL] = []
    @Published var selectedFile: URL?
    @Published var fileContent: String = ""

    func openFolderPicker() { ... }   // NSOpenPanel, canChooseDirectories=true, canChooseFiles=false
    func selectFile(_ url: URL) { ... }  // sets selectedFile, loads content
    private func loadContent(from url: URL) { ... }  // String(contentsOf:encoding:.utf8), catch → error message
}
```

`openFolderPicker` implementation:
- `NSOpenPanel`, `canChooseFiles = false`, `canChooseDirectories = true`,
  `allowsMultipleSelection = false`, `canCreateDirectories = false`
- On `.OK`: set `folderURL`, call `FolderScanner.scan(folder:)` to populate `mdFiles`
- Auto-select `mdFiles.first` if not nil and call `selectFile(_:)`

### FolderScanner.swift

```swift
import Foundation

enum FolderScanner {
    static let mdExtensions: Set<String> = ["md", "markdown"]

    static func scan(folder: URL) -> [URL] {
        // FileManager.default.enumerator(at:includingPropertiesForKeys:[.isRegularFileKey],
        //   options: [.skipsHiddenFiles, .skipsPackageDescendants])
        // Filter by pathExtension.lowercased() in mdExtensions
        // Sort by url.path (alphabetical, which gives directory-first ordering)
    }
}
```

Return type: `[URL]` sorted by `.path` ascending.

### ContentView.swift

```swift
struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.folderURL == nil {
            WelcomeView()
        } else {
            NavigationSplitView {
                FileListView()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
            } detail: {
                FileReaderView()
            }
        }
    }
}
```

### WelcomeView.swift

Centered `VStack` with:
- `Image(systemName: "folder.badge.plus")` at font size 56, `.secondary` foreground
- `Text("No folder open")` `.title2` weight `.medium`
- `Text("Open a folder to browse its Markdown files.")` `.secondary`
- `Button("Open Folder…")` calling `appState.openFolderPicker()`, style `.borderedProminent`,
  size `.large`

### FileListView.swift

```swift
struct FileListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(appState.mdFiles, id: \.self, selection: ...) { url in
            Label(relativePath(for: url), systemImage: "doc.text")
                .help(url.path)
        }
        .navigationTitle(appState.folderURL?.lastPathComponent ?? "")
        .navigationSubtitle("\(appState.mdFiles.count) file\(appState.mdFiles.count == 1 ? "" : "s")")
        .toolbar {
            ToolbarItem {
                Button(action: { appState.openFolderPicker() }) {
                    Label("Open Folder", systemImage: "folder")
                }
            }
        }
    }

    private func relativePath(for url: URL) -> String {
        guard let base = appState.folderURL else { return url.lastPathComponent }
        return String(url.path.dropFirst(base.path.count + 1))
    }
}
```

`List` selection binding: a `Binding<URL?>` that gets `appState.selectedFile` and on set calls
`appState.selectFile(_:)` (guard against nil).

### FileReaderView.swift

```swift
struct FileReaderView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if let file = appState.selectedFile {
            ScrollView([.vertical, .horizontal]) {
                Text(appState.fileContent)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .navigationTitle(file.lastPathComponent)
        } else {
            ContentUnavailableView(
                "No file selected",
                systemImage: "doc.text",
                description: Text("Pick a file from the sidebar.")
            )
        }
    }
}
```

---

## What Fable should NOT do

- Do not add Combine, async/await, actors, or any concurrency beyond `@MainActor` on `AppState`.
- Do not add error alert sheets — on file read failure just show the error string inline.
- Do not add preferences, settings, or persistence.
- Do not create any test targets.
- Do not add comments explaining what the code does.
- Do not import `swift-markdown` or any third-party package.
- Do not create a `.xcodeproj` — the Swift Package is the deliverable.

---

## How to open and run

1. `File → Open…` in Xcode, select the `ontode/` directory.
2. Xcode resolves the Swift Package. Select the `ontode` scheme, destination "My Mac".
3. ⌘R to build and run.

---

## Next milestones (not part of this session)

- **M1 — Reader:** swap raw text for real GFM rendering using `swift-markdown` → SwiftUI views +
  `Splash` for syntax highlighting; nested file tree grouped by directory.
- **M2 — Search:** SQLite FTS5 full-text search behind a `SearchIndex` protocol.
- **M3 — Live + links:** FSEvents file watcher, debounced re-render, `[[wikilink]]` resolution.
- **M4 — Polish:** ⌘P quick-open, keyboard nav, app icon, LICENSE, README, first release.
