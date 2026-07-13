import Foundation
import SQLite3

struct SearchEntry {
    let url: URL
    let displayPath: String
}

struct SearchResult: Identifiable {
    let url: URL
    let displayPath: String
    let snippet: AttributedString

    var id: URL { url }
}

protocol SearchIndex {
    func reindex(_ entries: [SearchEntry])
    func search(_ query: String, completion: @escaping @MainActor ([SearchResult]) -> Void)
}

final class FTS5SearchIndex: SearchIndex {
    private var db: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private let queue = DispatchQueue(label: "ontode.search-index", qos: .userInitiated)
    private var reindexGeneration = 0
    private let generationLock = NSLock()

    init() {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let ontodeDir = appSupportURL.appendingPathComponent("Ontode", isDirectory: true)
        try? fileManager.createDirectory(at: ontodeDir, withIntermediateDirectories: true)
        let dbPath = ontodeDir.appendingPathComponent("search.db").path

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            db = nil
        }
        exec("PRAGMA journal_mode = WAL")
        exec("CREATE VIRTUAL TABLE IF NOT EXISTS docs USING fts5(path UNINDEXED, name, body, tokenize = 'porter unicode61')")
        exec("CREATE TABLE IF NOT EXISTS file_meta (path TEXT PRIMARY KEY, mtime REAL NOT NULL)")
    }

    deinit {
        sqlite3_close(db)
    }

    func reindex(_ entries: [SearchEntry]) {
        generationLock.lock()
        reindexGeneration += 1
        let generation = reindexGeneration
        generationLock.unlock()
        queue.async { [weak self] in
            guard let self else { return }
            self.generationLock.lock()
            let isCurrent = generation == self.reindexGeneration
            self.generationLock.unlock()
            guard isCurrent else { return }
            self.performReindex(entries)
        }
    }

    func search(_ query: String, completion: @escaping @MainActor ([SearchResult]) -> Void) {
        queue.async { [weak self] in
            let results = self?.performSearch(query) ?? []
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    completion(results)
                }
            }
        }
    }

    // MARK: - Incremental Reindex

    private func performReindex(_ entries: [SearchEntry]) {
        guard db != nil else { return }

        // Build a lookup of current entries keyed by file path.
        var currentByPath: [String: SearchEntry] = [:]
        for entry in entries {
            currentByPath[entry.url.path] = entry
        }

        // Load previously stored modification timestamps from file_meta.
        let storedMtimes = loadStoredMtimes()

        // Determine the set of paths that were previously indexed.
        var previousPaths = Set(storedMtimes.keys)

        exec("BEGIN")

        // Upsert new / changed files.
        for (path, entry) in currentByPath {
            previousPaths.remove(path)

            guard let actualMtime = modificationDate(for: entry.url) else { continue }
            if let storedMtime = storedMtimes[path], storedMtime == actualMtime {
                // File hasn't changed — skip.
                continue
            }

            // Remove stale rows (if any) then insert fresh data.
            deleteDoc(atPath: path)
            insertDoc(entry: entry, mtime: actualMtime)
        }

        // Remove rows for files that no longer exist in the entries list.
        for stalePath in previousPaths {
            deleteDoc(atPath: stalePath)
        }

        exec("COMMIT")
    }

    /// Returns the file's `contentModificationDate` as a `TimeInterval` (seconds since reference date), or `nil` on failure.
    private func modificationDate(for url: URL) -> Double? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let date = values.contentModificationDate else {
            return nil
        }
        return date.timeIntervalSinceReferenceDate
    }

    /// Loads all rows from `file_meta` into a `[path: mtime]` dictionary.
    private func loadStoredMtimes() -> [String: Double] {
        var result: [String: Double] = [:]
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT path, mtime FROM file_meta", -1, &statement, nil) == SQLITE_OK else {
            return result
        }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let pathPtr = sqlite3_column_text(statement, 0) else { continue }
            let path = String(cString: pathPtr)
            let mtime = sqlite3_column_double(statement, 1)
            result[path] = mtime
        }
        return result
    }

    /// Deletes a document from both `docs` and `file_meta` by path.
    private func deleteDoc(atPath path: String) {
        var stmt: OpaquePointer?

        // Delete from FTS5 docs table.
        if sqlite3_prepare_v2(db, "DELETE FROM docs WHERE path = ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, path, -1, transient)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        stmt = nil

        // Delete from file_meta table.
        if sqlite3_prepare_v2(db, "DELETE FROM file_meta WHERE path = ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, path, -1, transient)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// Inserts a document into both `docs` and `file_meta`.
    private func insertDoc(entry: SearchEntry, mtime: Double) {
        guard let body = try? String(contentsOf: entry.url, encoding: .utf8) else { return }
        var stmt: OpaquePointer?

        // Insert into FTS5 docs table.
        if sqlite3_prepare_v2(db, "INSERT INTO docs (path, name, body) VALUES (?, ?, ?)", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, entry.url.path, -1, transient)
            sqlite3_bind_text(stmt, 2, entry.displayPath, -1, transient)
            sqlite3_bind_text(stmt, 3, body, -1, transient)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        stmt = nil

        // Insert into file_meta table.
        if sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO file_meta (path, mtime) VALUES (?, ?)", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, entry.url.path, -1, transient)
            sqlite3_bind_double(stmt, 2, mtime)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Search

    private func performSearch(_ query: String) -> [SearchResult] {
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
                displayPath: String(cString: name),
                snippet: Self.attributedSnippet(String(cString: snippet))
            ))
        }
        return results
    }

    // MARK: - Helpers

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
