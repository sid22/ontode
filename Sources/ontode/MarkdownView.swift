import AppKit
import Splash
import SwiftUI

struct MarkdownView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if appState.blocks.isEmpty {
                if appState.editingBlockID == AppState.wholeFileEditID {
                    BlockEditor()
                } else {
                    SwiftUI.Text("Empty file — double-click or press Return to start writing.")
                        .foregroundStyle(theme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { appState.beginEditingFocusedBlock() }
                }
            } else {
                ForEach(appState.blocks) { block in
                    EditableBlockView(block: block)
                        .id(block.id)
                }
            }
        }
        .foregroundStyle(theme.text)
    }
}

struct EditableBlockView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appTheme) private var theme
    let block: MDBlock
    @State private var hovering = false

    var body: some View {
        if appState.editingBlockID == block.id {
            BlockEditor()
        } else {
            MDBlockView(block: block)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(backgroundColor)
                )
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
                .onTapGesture(count: 2) {
                    if appState.editingBlockID == nil {
                        appState.focusedBlockID = block.id
                        appState.beginEditing(block)
                    } else {
                        appState.commitEditing()
                    }
                }
                .onTapGesture {
                    if appState.editingBlockID == nil {
                        appState.focusedBlockID = block.id
                    } else {
                        appState.commitEditing()
                    }
                }
        }
    }

    private var backgroundColor: Color {
        if appState.focusedBlockID == block.id {
            return theme.accent.opacity(0.10)
        }
        if hovering {
            return theme.raised.opacity(0.6)
        }
        return .clear
    }
}

struct BlockEditor: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appTheme) private var theme
    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $appState.editingDraft)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(theme.text)
            .lineSpacing(2)
            .scrollContentBackground(.hidden)
            .frame(height: editorHeight)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.raised)
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(theme.accent.opacity(0.6), lineWidth: 1)
            )
            .focused($focused)
            .onAppear { focused = true }
            .onKeyPress(.escape) {
                appState.commitEditing()
                return .handled
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused {
                    appState.commitEditing()
                }
            }
    }

    private var editorHeight: CGFloat {
        let lines = appState.editingDraft.reduce(into: 1) { count, character in
            if character == "\n" { count += 1 }
        }
        return min(600, max(52, CGFloat(lines) * 19 + 16))
    }
}

struct MDBlockView: View {
    @Environment(\.appTheme) private var theme
    let block: MDBlock

    var body: some View {
        switch block.kind {
        case .heading(let level, let text):
            VStack(alignment: .leading, spacing: 7) {
                SwiftUI.Text(text)
                    .font(Self.headingFont(level))
                    .foregroundStyle(theme.emphasis)
                if level <= 2 {
                    Rectangle()
                        .fill(theme.border)
                        .frame(height: 1)
                }
            }
            .padding(.top, level <= 2 ? 10 : 6)
        case .paragraph(let text):
            SwiftUI.Text(text)
                .font(.system(size: 14))
                .lineSpacing(4)
        case .code(let language, let code):
            CodeBlockView(language: language, code: code)
        case .quote(let blocks):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.border)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(blocks) { MDBlockView(block: $0) }
                }
                .foregroundStyle(theme.secondary)
            }
            .padding(.vertical, 2)
        case .bulletList(let items):
            listView(items: items) { _ in "•" }
        case .orderedList(let items, let start):
            listView(items: items) { "\(start + $0)." }
        case .table(let head, let rows):
            MDTableView(head: head, rows: rows)
        case .rule:
            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
                .padding(.vertical, 6)
        }
    }

    private func listView(items: [MDListItem], marker: (Int) -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let checked = item.checkbox {
                        Image(systemName: checked ? "checkmark.square.fill" : "square")
                            .font(.system(size: 13))
                            .foregroundStyle(checked ? theme.accent : theme.secondary)
                    } else {
                        SwiftUI.Text(marker(index))
                            .font(.system(size: 14))
                            .monospacedDigit()
                            .foregroundStyle(theme.secondary)
                            .frame(minWidth: 16, alignment: .trailing)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(item.blocks) { MDBlockView(block: $0) }
                    }
                }
            }
        }
        .padding(.leading, 2)
    }

    private static func headingFont(_ level: Int) -> SwiftUI.Font {
        switch level {
        case 1: return .system(size: 27, weight: .bold)
        case 2: return .system(size: 21, weight: .bold)
        case 3: return .system(size: 17, weight: .semibold)
        case 4: return .system(size: 15, weight: .semibold)
        default: return .system(size: 13, weight: .semibold)
        }
    }
}

struct MDTableView: View {
    @Environment(\.appTheme) private var theme
    let head: [AttributedString]
    let rows: [[AttributedString]]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
            GridRow {
                ForEach(Array(head.enumerated()), id: \.offset) { _, cell in
                    SwiftUI.Text(cell)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.emphasis)
                }
            }
            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        SwiftUI.Text(cell)
                            .font(.system(size: 13))
                    }
                }
            }
        }
        .padding(12)
        .background(theme.raised.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }
}

struct CodeBlockView: View {
    @Environment(\.appTheme) private var theme
    let language: String?
    let code: String
    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty {
                SwiftUI.Text(language)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }
            ScrollView(.horizontal) {
                SwiftUI.Text(highlightedCode)
                    .lineSpacing(2)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copied ? theme.accent : theme.secondary)
                }
                .buttonStyle(.borderless)
                .padding(8)
                .help("Copy code")
            }
        }
        .onHover { hovering = $0 }
    }

    private var highlightedCode: AttributedString {
        if language?.lowercased() == "swift" {
            let highlighter = SyntaxHighlighter(format: AttributedStringOutputFormat(theme: theme.splashTheme))
            return Self.convert(highlighter.highlight(code))
        }
        var plain = AttributedString(code)
        plain.font = .system(size: 12.5, design: .monospaced)
        plain.foregroundColor = theme.text
        return plain
    }

    private static func convert(_ source: NSAttributedString) -> AttributedString {
        var result = AttributedString()
        source.enumerateAttributes(in: NSRange(location: 0, length: source.length)) { attributes, range, _ in
            var piece = AttributedString(source.attributedSubstring(from: range).string)
            piece.font = .system(size: 12.5, design: .monospaced)
            if let color = attributes[.foregroundColor] as? NSColor {
                piece.foregroundColor = Color(nsColor: color)
            }
            result += piece
        }
        return result
    }
}
