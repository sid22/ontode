import SwiftUI

struct QuickOpenView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var highlightedIndex = 0
    @FocusState private var fieldFocused: Bool

    var body: some View {
        let matches = appState.quickOpenMatches(for: query)
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                TextField("Go to file…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .focused($fieldFocused)
                    .onSubmit { open(at: highlightedIndex, in: matches) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            Divider()
            if matches.isEmpty {
                Text("No matching files")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(Array(matches.enumerated()), id: \.element) { index, url in
                                row(for: url, highlighted: index == highlightedIndex)
                                    .id(index)
                                    .onTapGesture { open(at: index, in: matches) }
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: highlightedIndex) { _, newValue in
                        proxy.scrollTo(newValue)
                    }
                }
            }
            Divider()
            HStack(spacing: 16) {
                hint("↑↓", "Navigate")
                hint("⏎", "Open")
                hint("esc", "Dismiss")
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 560, height: 400)
        .presentationBackground(.ultraThickMaterial)
        .onAppear { fieldFocused = true }
        .onChange(of: query) { _, _ in highlightedIndex = 0 }
        .onKeyPress(.downArrow) {
            move(1, count: matches.count)
            return .handled
        }
        .onKeyPress(.upArrow) {
            move(-1, count: matches.count)
            return .handled
        }
        .onExitCommand { dismiss() }
    }

    private func row(for url: URL, highlighted: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundStyle(highlighted ? .white : .secondary)
            Text(appState.relativePath(for: url))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .foregroundStyle(highlighted ? .white : .primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(highlighted ? theme.accent : Color.clear)
        )
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private func move(_ delta: Int, count: Int) {
        guard count > 0 else { return }
        highlightedIndex = min(max(0, highlightedIndex + delta), count - 1)
    }

    private func open(at index: Int, in matches: [URL]) {
        guard matches.indices.contains(index) else { return }
        appState.selectFile(matches[index])
        dismiss()
    }
}
