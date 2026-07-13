import SwiftUI

struct BacklinksPanel: View {
    let maxContentHeight: CGFloat

    @EnvironmentObject var appState: AppState
    @Environment(\.appTheme) private var theme
    @AppStorage("ontode.backlinksCollapsed") private var collapsed = false
    @State private var unlinked: [Backlink] = []
    @State private var contentHeight: CGFloat = 0

    private struct ScanKey: Hashable {
        let file: URL?
        let revision: UUID
        let collapsed: Bool
    }

    private struct MentionGroup: Identifiable {
        let source: URL
        let refs: [WikiRef]

        var id: URL { source }
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
            header
            if !collapsed {
                ScrollView(.vertical) {
                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Metrics.space4)
                        .padding(.bottom, Metrics.space3)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                            }
                        )
                }
                .frame(height: min(max(contentHeight, 24), max(maxContentHeight, 24)))
                .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
            }
        }
        .background(theme.sidebar)
        .task(id: ScanKey(file: appState.selectedFile, revision: appState.noteIndex.revision, collapsed: collapsed)) {
            unlinked = []
            guard !collapsed,
                  let file = appState.selectedFile,
                  let meta = appState.noteIndex.byURL[file] else { return }
            let files = appState.mdFiles
            unlinked = await UnlinkedMentionScanner.scan(
                needles: [meta.title] + meta.aliases,
                excluding: file,
                in: files
            )
        }
    }

    private var linked: [Backlink] {
        guard let file = appState.selectedFile else { return [] }
        return appState.noteIndex.backlinks[file] ?? []
    }

    private var header: some View {
        Button(action: { collapsed.toggle() }) {
            HStack(spacing: Metrics.space2) {
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                Text("Linked mentions (\(linked.count))")
                    .font(Typography.caption.weight(.medium))
                Spacer()
            }
            .foregroundStyle(theme.secondary)
            .padding(.horizontal, Metrics.space4)
            .padding(.vertical, Metrics.space2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        let linkedGroups = grouped(linked)
        let unlinkedGroups = grouped(unlinked)
        if linkedGroups.isEmpty && unlinkedGroups.isEmpty {
            Text("No backlinks yet.")
                .font(Typography.caption)
                .foregroundStyle(theme.secondary)
                .padding(.top, Metrics.space1)
        } else {
            LazyVStack(alignment: .leading, spacing: Metrics.space2) {
                ForEach(linkedGroups) { group in
                    mentionGroup(group)
                }
                if !unlinkedGroups.isEmpty {
                    Text("Unlinked mentions (\(unlinked.count))")
                        .font(Typography.caption.weight(.medium))
                        .foregroundStyle(theme.secondary)
                        .padding(.top, Metrics.space2)
                    ForEach(unlinkedGroups) { group in
                        mentionGroup(group)
                    }
                }
            }
        }
    }

    private func grouped(_ links: [Backlink]) -> [MentionGroup] {
        Dictionary(grouping: links, by: \.source)
            .map { MentionGroup(source: $0.key, refs: $0.value.map(\.ref).sorted { $0.line < $1.line }) }
            .sorted { appState.displayPath(for: $0.source) < appState.displayPath(for: $1.source) }
    }

    private func mentionGroup(_ group: MentionGroup) -> some View {
        Button(action: { appState.selectFile(group.source) }) {
            VStack(alignment: .leading, spacing: Metrics.space1) {
                Text(appState.displayPath(for: group.source))
                    .font(Typography.caption.weight(.medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ForEach(Array(group.refs.enumerated()), id: \.offset) { _, ref in
                    Text(highlighted(ref))
                        .font(Typography.caption)
                        .foregroundStyle(theme.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.space2)
            .background(
                RoundedRectangle(cornerRadius: Metrics.radiusSmall)
                    .fill(theme.raised.opacity(0.5))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func highlighted(_ ref: WikiRef) -> AttributedString {
        if ref.context.contains("[[") {
            return highlightingWikilinks(in: ref.context)
        }
        return highlightingOccurrences(of: ref.target, in: ref.context)
    }

    private func highlightingWikilinks(in context: String) -> AttributedString {
        var result = AttributedString()
        var remainder = Substring(context)
        while let open = remainder.range(of: "[["),
              let close = remainder.range(of: "]]", range: open.upperBound..<remainder.endIndex) {
            result += AttributedString(String(remainder[..<open.lowerBound]))
            var link = AttributedString(String(remainder[open.lowerBound..<close.upperBound]))
            link.foregroundColor = theme.accent
            result += link
            remainder = remainder[close.upperBound...]
        }
        result += AttributedString(String(remainder))
        return result
    }

    private func highlightingOccurrences(of target: String, in context: String) -> AttributedString {
        var result = AttributedString()
        var remainder = Substring(context)
        while let range = remainder.range(of: target, options: .caseInsensitive) {
            result += AttributedString(String(remainder[..<range.lowerBound]))
            var hit = AttributedString(String(remainder[range]))
            hit.foregroundColor = theme.accent
            result += hit
            remainder = remainder[range.upperBound...]
        }
        result += AttributedString(String(remainder))
        return result
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
