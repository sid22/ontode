import SwiftUI

struct FileReaderView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appTheme) private var theme
    @FocusState private var readerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !appState.openTabs.isEmpty {
                TabBarView()
            }
            if let file = appState.selectedFile {
                readerContent(for: file)
            } else {
                ContentUnavailableView(
                    "No file open",
                    systemImage: "doc.text",
                    description: Text("Pick a file from the sidebar, or press ⌘P.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(theme.canvas)
    }

    @ViewBuilder
    private func readerContent(for file: URL) -> some View {
        Group {
            if appState.showSource {
                sourceView
            } else {
                renderedView
            }
        }
        .id(file)
        .navigationTitle(file.lastPathComponent)
        .overlay(alignment: .bottomTrailing) { wordCountBadge }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "ontode-wiki" else { return .systemAction }
            let raw = String(url.absoluteString.dropFirst("ontode-wiki:".count))
            appState.openWikilink(raw.removingPercentEncoding ?? raw)
            return .handled
        })
    }

    private var renderedView: some View {
        VStack(spacing: 0) {
            breadcrumbBar
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    MarkdownView()
                        .padding(.horizontal, 28)
                        .padding(.vertical, 24)
                        .frame(maxWidth: 720, alignment: .leading)
                        .frame(maxWidth: .infinity)
                }
                .focusable()
                .focusEffectDisabled()
                .focused($readerFocused)
                .onKeyPress(.return) {
                    guard appState.editingBlockID == nil else { return .ignored }
                    appState.beginEditingFocusedBlock()
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    guard appState.editingBlockID == nil else { return .ignored }
                    appState.moveFocus(-1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    guard appState.editingBlockID == nil else { return .ignored }
                    appState.moveFocus(1)
                    return .handled
                }
                .onChange(of: appState.focusedBlockID) { _, id in
                    if appState.editingBlockID == nil {
                        readerFocused = true
                    }
                    if let id {
                        proxy.scrollTo(id)
                    }
                }
                .onChange(of: appState.editingBlockID) { _, id in
                    if let id {
                        proxy.scrollTo(id)
                    } else {
                        readerFocused = true
                    }
                }
            }
        }
    }

    private var sourceView: some View {
        ScrollView(.vertical) {
            Text(appState.fileContent)
                .font(.system(size: 12.5, design: .monospaced))
                .lineSpacing(3)
                .foregroundStyle(theme.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
        }
    }

    private var breadcrumbBar: some View {
        HStack(spacing: 3) {
            Spacer(minLength: 0)
            let parts = appState.breadcrumb(for: appState.selectedFile ?? URL(fileURLWithPath: "/"))
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if index > 0 {
                    Text("/")
                        .foregroundStyle(theme.secondary.opacity(0.5))
                }
                Text(part)
                    .foregroundStyle(index == parts.count - 1 ? theme.text : theme.secondary)
            }
        }
        .font(.system(size: 12))
        .lineLimit(1)
        .truncationMode(.head)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var wordCountBadge: some View {
        Text("\(appState.wordCount) words")
            .font(.caption)
            .foregroundStyle(theme.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(12)
    }
}
