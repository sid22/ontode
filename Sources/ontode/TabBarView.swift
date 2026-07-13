import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(appState.openTabs, id: \.self) { url in
                        TabItemView(url: url)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }
            Button {
                appState.quickOpenPresented = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(theme.secondary)
            .padding(.horizontal, 10)
            .help("Open a file (⌘P)")
        }
        .frame(height: 36)
        .background(theme.sidebar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
        }
    }
}

private struct TabItemView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appTheme) private var theme
    let url: URL
    @State private var hovering = false

    private var isActive: Bool {
        appState.selectedFile == url
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(url.deletingPathExtension().lastPathComponent)
                .font(.system(size: 12.5, weight: isActive ? .medium : .regular))
                .lineLimit(1)
                .foregroundStyle(isActive ? theme.emphasis : theme.secondary)
            Button {
                appState.closeTab(url)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(theme.secondary)
            }
            .buttonStyle(.borderless)
            .opacity(hovering || isActive ? 1 : 0)
            .help("Close tab (⌘W)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? theme.canvas : (hovering ? theme.raised.opacity(0.6) : .clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { appState.selectFile(url) }
        .onHover { hovering = $0 }
        .help(appState.displayPath(for: url))
    }
}
