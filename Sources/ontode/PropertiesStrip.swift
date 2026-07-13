import SwiftUI

struct PropertiesStrip: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appTheme) private var theme

    var body: some View {
        if let meta {
            VStack(alignment: .leading, spacing: Metrics.space2) {
                ForEach(meta.properties.keys.sorted(), id: \.self) { key in
                    HStack(alignment: .firstTextBaseline, spacing: Metrics.space3) {
                        Text(key)
                            .font(Typography.caption)
                            .foregroundStyle(theme.secondary)
                            .frame(minWidth: 70, alignment: .leading)
                        Text(meta.properties[key] ?? "")
                            .font(Typography.caption)
                            .foregroundStyle(theme.text)
                            .textSelection(.enabled)
                    }
                }
                if !meta.tags.isEmpty {
                    FlowLayout(spacing: Metrics.space1 + 2) {
                        ForEach(meta.tags, id: \.self) { tag in
                            Button(action: { appState.tagFilter = tag }) {
                                Text("#" + tag)
                                    .font(Typography.caption)
                                    .foregroundStyle(theme.accent)
                                    .padding(.horizontal, Metrics.space2)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: Metrics.radiusSmall)
                                            .fill(theme.accent.opacity(0.14))
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Filter by #\(tag)")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.space4)
            .padding(.vertical, Metrics.space3)
            .background(theme.raised.opacity(0.35))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(theme.border)
                    .frame(height: 1)
            }
        }
    }

    private var meta: NoteMeta? {
        guard let file = appState.selectedFile,
              let meta = appState.noteIndex.byURL[file],
              !(meta.properties.isEmpty && meta.tags.isEmpty) else { return nil }
        return meta
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let positions = arrange(width: bounds.width, subviews: subviews).positions
        for (subview, position) in zip(subviews, positions) {
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x + size.width)
            x += size.width + spacing
        }
        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
