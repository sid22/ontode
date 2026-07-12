import Foundation
import SQLite3

struct SearchResult: Identifiable {
    let url: URL
    let relativePath: String
    let snippet: AttributedString

    var id: URL { url }
}

protocol SearchIndex {
    func reindex(folder: URL, files: [URL])
    func search(_ query: String) -> [SearchResult]
}

final class FTS5SearchIndex: SearchIndex {
    private var db: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init() {
        if sqlite3_open(":memory:", &db) != SQLITE_OK {
            db = nil
        }
        exec("CREATE VIRTUAL TABLE IF NOT EXISTS docs USING fts5(path UNINDEXED, name, body, tokenize = 'porter unicode61')")
    }

    deinit {
        sqlite3_close(db)
    }

    func reindex(folder: URL, files: [URL]) {
        guard db != nil else { return }
        exec("DELETE FROM docs")
        exec("BEGIN")
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT INTO docs (path, name, body) VALUES (?, ?, ?)", -1, &statement, nil) == SQLITE_OK else {
            exec("COMMIT")
            return
        }
        for file in files {
            guard let body = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let name = String(file.path.dropFirst(folder.path.count + 1))
            sqlite3_bind_text(statement, 1, file.path, -1, transient)
            sqlite3_bind_text(statement, 2, name, -1, transient)
            sqlite3_bind_text(statement, 3, body, -1, transient)
            sqlite3_step(statement)
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
        }
        sqlite3_finalize(statement)
        exec("COMMIT")
    }

    func search(_ query: String) -> [SearchResult] {
        guard db != nil else { return [] }
        let tokens = query
            .split(whereSeparator: { $0.isWhitespace })
            .map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"*" }
        guard !tokens.isEmpty else { return [] }

        let sql = """
            SELECT path, name, snippet(docs, 2, '\u{02}', '\u{03}', '…', 12)
            FROM docs WHERE docs MATCH ? ORDER BY rank LIMIT 100
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, tokens.joined(separator: " "), -1, transient)

        var results: [SearchResult] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let path = sqlite3_column_text(statement, 0),
                  let name = sqlite3_column_text(statement, 1),
                  let snippet = sqlite3_column_text(statement, 2) else { continue }
            results.append(SearchResult(
                url: URL(fileURLWithPath: String(cString: path)),
                relativePath: String(cString: name),
                snippet: Self.attributedSnippet(String(cString: snippet))
            ))
        }
        return results
    }

    private func exec(_ sql: String) {
        guard db != nil else { return }
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private static func attributedSnippet(_ raw: String) -> AttributedString {
        var result = AttributedString()
        var remainder = Substring(raw)
        while let open = remainder.range(of: "\u{02}"),
              let close = remainder.range(of: "\u{03}", range: open.upperBound..<remainder.endIndex) {
            result += AttributedString(String(remainder[..<open.lowerBound]))
            var highlighted = AttributedString(String(remainder[open.upperBound..<close.lowerBound]))
            highlighted.inlinePresentationIntent = .stronglyEmphasized
            result += highlighted
            remainder = remainder[close.upperBound...]
        }
        result += AttributedString(String(remainder))
        return result
    }
}
