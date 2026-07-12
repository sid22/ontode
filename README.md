# ontode

A lightweight, native macOS Markdown viewer for people who live in `.md` files.
Think "Obsidian minus the graph, plugins, and weight."

Point it at a folder and it indexes every `.md` / `.markdown` file, renders them as
GitHub-flavored Markdown, searches their full text, and updates live as files change on
disk — for example while an AI agent is editing your `CLAUDE.md` and design docs.

## Features

- **Reader** — GFM rendering (headings, lists, task lists, tables, block quotes, code
  blocks) built on [swift-markdown], with Swift syntax highlighting via [Splash]
- **File tree** — sidebar nested by directory, hidden files excluded
- **Full-text search** — SQLite FTS5 with prefix matching and ranked snippet results
- **Live updates** — FSEvents watcher rescans the folder and re-renders the open file
  when anything changes
- **Wikilinks** — `[[note]]` and `[[note|label]]` resolve to files in the open folder
- **Quick open** — ⌘P fuzzy file switcher
- **In-place editing** — Obsidian-style: click a block to place the cursor, press Return
  or double-click to reveal its raw Markdown and edit it right there; Esc, ⌘⏎, or
  clicking away saves straight back to disk
- **Solarized themes** — Solarized Dark by default, with a one-click toggle to Solarized
  Light (toolbar sun/moon button or ⇧⌘L); your choice is remembered

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
| ⌘O | Open folder |
| ⌘P | Quick open file |
| ⌥⌘↑ / ⌥⌘↓ | Previous / next file |
| ↑ / ↓ | Move through the sidebar, or move the block cursor in the reader |
| Return or double-click | Edit the focused block in place |
| ⌘E | Edit the focused block |
| Esc or ⌘⏎ | Finish editing and save |
| ⇧⌘L | Toggle Solarized Light / Dark |

## License

MIT — see [LICENSE](LICENSE).

[swift-markdown]: https://github.com/swiftlang/swift-markdown
[Splash]: https://github.com/JohnSundell/Splash
