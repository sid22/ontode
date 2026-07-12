import Foundation
import Markdown
import SwiftUI

struct MDBlock: Identifiable {
    let id = UUID()
    let kind: Kind
    let lineRange: ClosedRange<Int>?

    init(kind: Kind, lineRange: ClosedRange<Int>? = nil) {
        self.kind = kind
        self.lineRange = lineRange
    }

    enum Kind {
        case heading(Int, AttributedString)
        case paragraph(AttributedString)
        case code(String?, String)
        case quote([MDBlock])
        case bulletList([MDListItem])
        case orderedList([MDListItem], Int)
        case table([AttributedString], [[AttributedString]])
        case rule
    }
}

struct MDListItem: Identifiable {
    let id = UUID()
    let checkbox: Bool?
    let blocks: [MDBlock]
}

enum MarkdownBuilder {
    static func blocks(from source: String) -> [MDBlock] {
        Document(parsing: source).children.compactMap(block(from:))
    }

    private static func block(from markup: Markup) -> MDBlock? {
        let lineRange = markup.range.map { $0.lowerBound.line...max($0.lowerBound.line, $0.upperBound.line) }
        switch markup {
        case let heading as Heading:
            return MDBlock(kind: .heading(heading.level, inline(heading.children)), lineRange: lineRange)
        case let paragraph as Paragraph:
            return MDBlock(kind: .paragraph(inline(paragraph.children)), lineRange: lineRange)
        case let code as CodeBlock:
            return MDBlock(kind: .code(code.language, code.code.trimmingCharacters(in: .newlines)), lineRange: lineRange)
        case let html as HTMLBlock:
            return MDBlock(kind: .code("html", html.rawHTML.trimmingCharacters(in: .newlines)), lineRange: lineRange)
        case let quote as BlockQuote:
            return MDBlock(kind: .quote(quote.children.compactMap(block(from:))), lineRange: lineRange)
        case let list as UnorderedList:
            return MDBlock(kind: .bulletList(list.listItems.map(item(from:))), lineRange: lineRange)
        case let list as OrderedList:
            return MDBlock(kind: .orderedList(list.listItems.map(item(from:)), Int(list.startIndex)), lineRange: lineRange)
        case let table as Markdown.Table:
            let head = table.head.cells.map { inline($0.children) }
            let rows = table.body.rows.map { row in row.cells.map { inline($0.children) } }
            return MDBlock(kind: .table(head, rows), lineRange: lineRange)
        case is ThematicBreak:
            return MDBlock(kind: .rule, lineRange: lineRange)
        default:
            let fallback = markup.format().trimmingCharacters(in: .whitespacesAndNewlines)
            return fallback.isEmpty ? nil : MDBlock(kind: .paragraph(AttributedString(fallback)), lineRange: lineRange)
        }
    }

    private static func item(from listItem: ListItem) -> MDListItem {
        let checkbox: Bool?
        switch listItem.checkbox {
        case .checked: checkbox = true
        case .unchecked: checkbox = false
        case nil: checkbox = nil
        }
        return MDListItem(checkbox: checkbox, blocks: listItem.children.compactMap(block(from:)))
    }

    private static func inline<S: Sequence>(
        _ children: S,
        intents: InlinePresentationIntent = []
    ) -> AttributedString where S.Element == Markup {
        var result = AttributedString()
        for child in children {
            result += fragment(child, intents: intents)
        }
        return result
    }

    private static func fragment(_ markup: Markup, intents: InlinePresentationIntent) -> AttributedString {
        switch markup {
        case let text as Markdown.Text:
            return wikilinked(text.string, intents: intents)
        case let emphasis as Emphasis:
            return inline(emphasis.children, intents: intents.union(.emphasized))
        case let strong as Strong:
            return inline(strong.children, intents: intents.union(.stronglyEmphasized))
        case let strikethrough as Strikethrough:
            return inline(strikethrough.children, intents: intents.union(.strikethrough))
        case let code as InlineCode:
            var piece = AttributedString(code.code)
            piece.inlinePresentationIntent = intents.union(.code)
            piece.backgroundColor = Color.primary.opacity(0.07)
            return piece
        case let link as Markdown.Link:
            var piece = inline(link.children, intents: intents)
            if let destination = link.destination, let url = URL(string: destination) {
                piece.link = url
            }
            return piece
        case let image as Markdown.Image:
            var piece = AttributedString(image.plainText.isEmpty ? "[image]" : image.plainText)
            piece.foregroundColor = .secondary
            piece.inlinePresentationIntent = intents.union(.emphasized)
            return piece
        case let html as InlineHTML:
            var piece = AttributedString(html.rawHTML)
            piece.inlinePresentationIntent = intents.union(.code)
            return piece
        case is SoftBreak:
            return AttributedString(" ")
        case is LineBreak:
            return AttributedString("\n")
        default:
            return AttributedString(markup.format())
        }
    }

    private static func wikilinked(_ text: String, intents: InlinePresentationIntent) -> AttributedString {
        func plain(_ substring: Substring) -> AttributedString {
            var piece = AttributedString(String(substring))
            if !intents.isEmpty {
                piece.inlinePresentationIntent = intents
            }
            return piece
        }

        var result = AttributedString()
        var remainder = Substring(text)
        while let open = remainder.range(of: "[["),
              let close = remainder.range(of: "]]", range: open.upperBound..<remainder.endIndex) {
            result += plain(remainder[..<open.lowerBound])
            let inner = remainder[open.upperBound..<close.lowerBound]
            let parts = inner.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            let target = parts.isEmpty ? "" : parts[0].trimmingCharacters(in: .whitespaces)
            let label = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : target
            var link = AttributedString(label.isEmpty ? String(inner) : label)
            if !intents.isEmpty {
                link.inlinePresentationIntent = intents
            }
            if !target.isEmpty,
               let encoded = target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
               let url = URL(string: "ontode-wiki:" + encoded) {
                link.link = url
                link.underlineStyle = .single
            }
            result += link
            remainder = remainder[close.upperBound...]
        }
        result += plain(remainder)
        return result
    }
}
