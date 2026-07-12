import SwiftUI

struct FileReaderView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appTheme) private var theme
    @FocusState private var readerFocused: Bool

    var body: some View {
        if let file = appState.selectedFile {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    MarkdownView()
                        .padding(.horizontal, 28)
                        .padding(.vertical, 24)
                        .frame(maxWidth: 720, alignment: .leading)
                        .frame(maxWidth: .infinity)
                }
                .background(theme.canvas)
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
            .id(file)
            .navigationTitle(file.lastPathComponent)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "ontode-wiki" else { return .systemAction }
                let raw = String(url.absoluteString.dropFirst("ontode-wiki:".count))
                appState.openWikilink(raw.removingPercentEncoding ?? raw)
                return .handled
            })
        } else {
            ContentUnavailableView(
                "No file selected",
                systemImage: "doc.text",
                description: Text("Pick a file from the sidebar.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.canvas)
        }
    }
}
