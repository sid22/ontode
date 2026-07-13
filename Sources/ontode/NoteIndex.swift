import Foundation

struct WikiRef: Hashable, Sendable {
    let target: String
    let line: Int
    let context: String
}

struct Backlink: Hashable, Sendable {
    let source: URL
    let ref: WikiRef
}

struct NoteMeta: Sendable {
    let url: URL
    var title: String
    var aliases: [String]
    var tags: [String]
    var properties: [String: String]
    var outgoing: [WikiRef]
    var mtime: Double
}

struct SavedQuery: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var query: String
}

struct TagCount: Hashable, Identifiable, Sendable {
    let tag: String
    let count: Int

    var id: String { tag }
}

struct NoteIndexSnapshot: Sendable {
    let byURL: [URL: NoteMeta]
    let resolution: [String: URL]
    let backlinks: [URL: [Backlink]]
    let tagCounts: [TagCount]
    let revision = UUID()

    static let empty = NoteIndexSnapshot(byURL: [:], resolution: [:], backlinks: [:], tagCounts: [])
}

enum Frontmatter {
    struct Parsed {
        var scalars: [String: String] = [:]
        var lists: [String: [String]] = [:]
        var bodyStart = 0
    }

    static func parse(_ lines: [String]) -> Parsed? {
        guard lines.first == "---" else { return nil }
        guard let closing = lines.dropFirst().firstIndex(of: "---") else { return nil }
        var parsed = Parsed()
        parsed.bodyStart = closing + 1
        var pendingKey: String?
        for line in lines[1..<closing] {
            let stripped = line.trimmingCharacters(in: .whitespaces)
            if stripped.hasPrefix("- "), let key = pendingKey {
                parsed.lists[key, default: []].append(unquote(String(stripped.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
                continue
            }
            guard let first = line.first, first != " ", first != "\t",
                  let colon = line.firstIndex(of: ":") else {
                pendingKey = nil
                continue
            }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let rest = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else {
                pendingKey = nil
                continue
            }
            if rest.isEmpty {
                pendingKey = key
            } else if rest.hasPrefix("["), rest.hasSuffix("]") {
                parsed.lists[key] = rest.dropFirst().dropLast()
                    .split(separator: ",")
                    .map { unquote($0.trimmingCharacters(in: .whitespaces)) }
                pendingKey = nil
            } else {
                parsed.scalars[key] = unquote(rest)
                pendingKey = nil
            }
        }
        return parsed
    }

    static func displaySource(_ source: String) -> String {
        var lines = source.components(separatedBy: "\n")
        guard let parsed = parse(lines) else { return source }
        for index in 0..<parsed.bodyStart {
            lines[index] = ""
        }
        return lines.joined(separator: "\n")
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}

enum NoteIndexBuilder {
    static func build(files: [URL], roots: [URL], previous: NoteIndexSnapshot) -> NoteIndexSnapshot {
        var byURL: [URL: NoteMeta] = [:]
        for url in files {
            if Task.isCancelled { return previous }
            let mtime = modificationDate(for: url)
            if let cached = previous.byURL[url], cached.mtime == mtime, mtime > 0 {
                byURL[url] = cached
                continue
            }
            guard let meta = parseNote(url: url, mtime: mtime) else { continue }
            byURL[url] = meta
        }

        var resolution: [String: URL] = [:]
        func claim(_ key: String, _ url: URL) {
            let lowered = key.lowercased()
            guard !lowered.isEmpty, resolution[lowered] == nil else { return }
            resolution[lowered] = url
        }
        for url in files {
            guard let meta = byURL[url] else { continue }
            let relative = relativePath(url, roots: roots)
            claim(url.deletingPathExtension().lastPathComponent, url)
            claim(relative, url)
            claim((relative as NSString).deletingPathExtension, url)
            claim(meta.title, url)
            for alias in meta.aliases {
                claim(alias, url)
            }
        }

        var backlinks: [URL: [Backlink]] = [:]
        for url in files {
            guard let meta = byURL[url] else { continue }
            for ref in meta.outgoing {
                guard let destination = resolution[ref.target.lowercased()] else { continue }
                backlinks[destination, default: []].append(Backlink(source: url, ref: ref))
            }
        }

        var counts: [String: Int] = [:]
        for meta in byURL.values {
            for tag in meta.tags {
                counts[tag, default: 0] += 1
            }
        }
        let tagCounts = counts
            .map { TagCount(tag: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.tag < $1.tag : $0.count > $1.count }

        return NoteIndexSnapshot(byURL: byURL, resolution: resolution, backlinks: backlinks, tagCounts: tagCounts)
    }

    private static func modificationDate(for url: URL) -> Double {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let date = values.contentModificationDate else {
            return 0
        }
        return date.timeIntervalSinceReferenceDate
    }

    private static func relativePath(_ url: URL, roots: [URL]) -> String {
        let root = roots
            .filter { url.path == $0.path || url.path.hasPrefix($0.path + "/") }
            .max { $0.path.count < $1.path.count }
        guard let root else { return url.lastPathComponent }
        return String(url.path.dropFirst(root.path.count + 1))
    }

    private static func parseNote(url: URL, mtime: Double) -> NoteMeta? {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = raw.components(separatedBy: "\n")
        let frontmatter = Frontmatter.parse(lines)
        let body = scanBody(lines, from: frontmatter?.bodyStart ?? 0)

        let fallbackTitle = url.deletingPathExtension().lastPathComponent
        let title = frontmatter?.scalars["title"].flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTitle

        var tags: [String] = []
        var seen = Set<String>()
        for tag in (frontmatter.map(tagList) ?? []) + body.tags where seen.insert(tag).inserted {
            tags.append(tag)
        }

        var properties = frontmatter?.scalars ?? [:]
        for key in ["title", "tags", "aliases"] {
            properties[key] = nil
        }

        return NoteMeta(
            url: url,
            title: title,
            aliases: frontmatter.map(aliasList) ?? [],
            tags: tags,
            properties: properties,
            outgoing: body.refs,
            mtime: mtime
        )
    }

    private static func aliasList(_ parsed: Frontmatter.Parsed) -> [String] {
        if let list = parsed.lists["aliases"] {
            return list.filter { !$0.isEmpty }
        }
        if let scalar = parsed.scalars["aliases"], !scalar.isEmpty {
            return scalar.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        return []
    }

    private static func tagList(_ parsed: Frontmatter.Parsed) -> [String] {
        let raw: [String]
        if let list = parsed.lists["tags"] {
            raw = list
        } else if let scalar = parsed.scalars["tags"] {
            raw = scalar.split(separator: ",").map(String.init)
        } else {
            raw = []
        }
        return raw
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
            .filter { !$0.isEmpty }
    }

    private static func scanBody(_ lines: [String], from bodyStart: Int) -> (tags: [String], refs: [WikiRef]) {
        var tags: [String] = []
        var seen = Set<String>()
        var refs: [WikiRef] = []
        var inFence = false
        for index in bodyStart..<lines.count {
            let line = lines[index]
            if line.drop(while: { $0 == " " || $0 == "\t" }).hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if inFence { continue }
            let scannable = strippingInlineCode(line)
            collectTags(from: scannable, into: &tags, seen: &seen)
            collectRefs(from: scannable, line: index + 1, context: line.trimmingCharacters(in: .whitespaces), into: &refs)
        }
        return (tags, refs)
    }

    private static func strippingInlineCode(_ line: String) -> String {
        var chars = Array(line)
        var start: Int?
        for index in chars.indices where chars[index] == "`" {
            if let opened = start {
                for cleared in opened...index {
                    chars[cleared] = " "
                }
                start = nil
            } else {
                start = index
            }
        }
        return String(chars)
    }

    private static func collectTags(from line: String, into tags: inout [String], seen: inout Set<String>) {
        let chars = Array(line)
        var index = 0
        while index < chars.count {
            guard chars[index] == "#", index == 0 || chars[index - 1].isWhitespace else {
                index += 1
                continue
            }
            var end = index + 1
            guard end < chars.count, isWordChar(chars[end]) else {
                index = end
                continue
            }
            end += 1
            while end < chars.count, isTagChar(chars[end]) {
                end += 1
            }
            let tag = String(chars[(index + 1)..<end]).lowercased()
            if seen.insert(tag).inserted {
                tags.append(tag)
            }
            index = end
        }
    }

    private static func collectRefs(from line: String, line lineNumber: Int, context: String, into refs: inout [WikiRef]) {
        var remainder = Substring(line)
        while let open = remainder.range(of: "[["),
              let close = remainder.range(of: "]]", range: open.upperBound..<remainder.endIndex) {
            let inner = remainder[open.upperBound..<close.lowerBound]
            let parts = inner.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            let target = parts.isEmpty ? "" : parts[0].trimmingCharacters(in: .whitespaces)
            if !target.isEmpty {
                refs.append(WikiRef(target: target, line: lineNumber, context: context))
            }
            remainder = remainder[close.upperBound...]
        }
    }

    private static func isWordChar(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    private static func isTagChar(_ character: Character) -> Bool {
        isWordChar(character) || character == "/" || character == "-"
    }
}

enum UnlinkedMentionScanner {
    static func scan(needles: [String], excluding origin: URL, in files: [URL], limit: Int = 200) async -> [Backlink] {
        let wanted = needles
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        guard !wanted.isEmpty else { return [] }
        var results: [Backlink] = []
        for url in files {
            if Task.isCancelled || results.count >= limit { break }
            guard url != origin,
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let loweredText = text.lowercased()
            guard wanted.contains(where: { loweredText.contains($0) }) else { continue }
            for (index, line) in text.components(separatedBy: "\n").enumerated() {
                guard results.count < limit else { break }
                let lowered = line.lowercased()
                for needle in wanted where hasUnlinkedMatch(of: needle, in: lowered) {
                    results.append(Backlink(
                        source: url,
                        ref: WikiRef(
                            target: needle,
                            line: index + 1,
                            context: line.trimmingCharacters(in: .whitespaces)
                        )
                    ))
                    break
                }
            }
        }
        return results
    }

    private static func hasUnlinkedMatch(of needle: String, in line: String) -> Bool {
        var searchStart = line.startIndex
        while let range = line.range(of: needle, range: searchStart..<line.endIndex) {
            searchStart = range.upperBound
            if range.lowerBound > line.startIndex,
               isWordChar(line[line.index(before: range.lowerBound)]) { continue }
            if range.upperBound < line.endIndex,
               isWordChar(line[range.upperBound]) { continue }
            if insideWikilink(line, range) { continue }
            return true
        }
        return false
    }

    private static func insideWikilink(_ line: String, _ range: Range<String.Index>) -> Bool {
        guard let open = line.range(of: "[[", options: .backwards, range: line.startIndex..<range.lowerBound) else {
            return false
        }
        if let close = line.range(of: "]]", options: .backwards, range: line.startIndex..<range.lowerBound),
           close.lowerBound > open.lowerBound {
            return false
        }
        return line.range(of: "]]", range: range.upperBound..<line.endIndex) != nil
    }

    private static func isWordChar(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}
