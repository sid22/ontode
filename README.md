# ontode

A lightweight, native macOS Markdown viewer for people who live in `.md` files.
Think "Obsidian minus the graph, plugins, and weight."

Point it at one or more folders and it indexes every `.md` / `.markdown` file, renders
them as GitHub-flavored Markdown, searches their full text, and updates live as files
change on disk — for example while an AI agent is editing your `CLAUDE.md` and design
docs.

## Features

- **Reader** — GFM rendering (headings, lists, task lists, tables, block quotes, code
  blocks) built on [swift-markdown], with Swift syntax highlighting via [Splash], plus
  a breadcrumb path and a word count badge
- **Tabs** — every file opens in a tab; switch with ⇧⌘] / ⇧⌘[, close with ⌘W
- **Multiple folders** — add any number of folders (⌘O, multi-select, or drag and drop);
  each appears as its own sidebar section with a file count, and search, quick open,
  and wikilinks span all of them; remove one via its section header's context menu
- **Session restore** — folders, open tabs, and the selected file come back on launch
- **File tree** — sidebar nested by directory per folder, hidden files excluded; context
  menu with Open in Default Editor, Reveal in Finder, Copy Path / Wikilink, and Move to
  Trash
- **New files** — ⌘N creates `Untitled.md` in the current folder and drops you straight
  into editing; also per-folder via the section header's context menu
- **Full-text search** — SQLite FTS5 with prefix matching and ranked snippet results,
  indexed in the background so big folders never block the UI
- **Live updates** — FSEvents watcher rescans the folder and re-renders the open file
  when anything changes
- **Wikilinks** — `[[note]]` and `[[note|label]]` resolve to files in the open folder
- **Quick open** — ⌘P fuzzy file switcher
- **In-place editing** — Obsidian-style: click a block to place the cursor, press Return
  or double-click to reveal its raw Markdown and edit it right there; Esc, ⌘⏎, or
  clicking away saves straight back to disk
- **Raw source** — ⌘/ toggles the whole file as plain, selectable Markdown source
- **Themes** — a neutral Obsidian-style dark theme by default, with a one-click toggle
  to light (toolbar sun/moon button or ⇧⌘L); your choice is remembered

## Requirements

macOS 14 (Sonoma) or later. Xcode 15+ to build.

## Building

1. `File → Open…` in Xcode and select this directory (it is a Swift Package — there is
   no `.xcodeproj`).
2. Select the `ontode` scheme, destination "My Mac".
3. ⌘R to build and run.

Or from the command line: `swift run`.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘O | Add folder(s) |
| ⌘N | New file in the current folder |
| ⌘P | Quick open file |
| ⌘W / ⇧⌘W | Close tab / close window |
| ⇧⌘] / ⇧⌘[ | Next / previous tab |
| ⌥⌘↑ / ⌥⌘↓ | Previous / next file |
| ↑ / ↓ | Move through the sidebar, or move the block cursor in the reader |
| Return or double-click | Edit the focused block in place |
| ⌘E | Edit the focused block |
| Esc or ⌘⏎ | Finish editing and save |
| ⌘/ | Toggle raw Markdown source |
| ⇧⌘L | Toggle light / dark theme |

## License

MIT — see [LICENSE](LICENSE).

[swift-markdown]: https://github.com/swiftlang/swift-markdown
[Splash]: https://github.com/JohnSundell/Splash
