import Foundation

// MARK: - Size

/// A size band in bytes. `min` is inclusive, `max` is exclusive. Folders never match a size band,
/// because a folder's own size says nothing about what it holds.
struct SizeRange: Equatable, Hashable {
    var min: Int64?
    var max: Int64?

    static let kb: Int64 = 1024
    static let mb: Int64 = 1024 * 1024
    static let gb: Int64 = 1024 * 1024 * 1024

    /// Bands for the menu. They do not overlap.
    static let presets: [SizeRange] = [
        SizeRange(min: nil, max: 100 * kb),
        SizeRange(min: 100 * kb, max: mb),
        SizeRange(min: mb, max: 10 * mb),
        SizeRange(min: 10 * mb, max: 100 * mb),
        SizeRange(min: 100 * mb, max: gb),
        SizeRange(min: gb, max: nil)
    ]

    var label: String {
        switch (min, max) {
        case let (lo?, hi?): return "\(Self.format(lo)) to \(Self.format(hi))"
        case let (nil, hi?): return "Under \(Self.format(hi))"
        case let (lo?, nil): return "Over \(Self.format(lo))"
        case (nil, nil): return "Any size"
        }
    }

    var sqlClause: String {
        var parts = ["is_directory = 0"]
        if let min { parts.append("size >= \(min)") }
        if let max { parts.append("size < \(max)") }
        return parts.joined(separator: " AND ")
    }

    static func format(_ bytes: Int64) -> String {
        let units: [(Int64, String)] = [(gb, "GB"), (mb, "MB"), (kb, "KB")]
        for (size, name) in units where bytes >= size {
            let value = Double(bytes) / Double(size)
            let rounded = (value * 10).rounded() / 10
            return rounded == rounded.rounded() ? "\(Int(rounded)) \(name)" : "\(rounded) \(name)"
        }
        return "\(bytes) B"
    }

    /// Reads the value part of a `size:` token: `>10mb`, `<500kb`, `>=1gb`, `10mb..100mb`, `..5mb`, `2mb..`.
    /// A number without a unit means megabytes.
    static func parse(_ value: String) -> SizeRange? {
        if value.contains("..") {
            let parts = value.components(separatedBy: "..")
            guard parts.count == 2 else { return nil }
            let lo = parts[0].isEmpty ? nil : bytes(parts[0])
            let hi = parts[1].isEmpty ? nil : bytes(parts[1])
            if (!parts[0].isEmpty && lo == nil) || (!parts[1].isEmpty && hi == nil) { return nil }
            if lo == nil && hi == nil { return nil }
            if let lo, let hi, lo >= hi { return nil }
            return SizeRange(min: lo, max: hi)
        }
        if value.hasPrefix(">=") || value.hasPrefix(">") {
            guard let amount = bytes(value.drop(while: { $0 == ">" || $0 == "=" })) else { return nil }
            return SizeRange(min: amount, max: nil)
        }
        if value.hasPrefix("<=") {
            guard let amount = bytes(value.dropFirst(2)) else { return nil }
            return SizeRange(min: nil, max: amount + 1)
        }
        if value.hasPrefix("<") {
            guard let amount = bytes(value.dropFirst()) else { return nil }
            return SizeRange(min: nil, max: amount)
        }
        return nil
    }

    private static func bytes<S: StringProtocol>(_ text: S) -> Int64? {
        let lower = text.lowercased()
        let units: [(String, Int64)] = [("gb", gb), ("mb", mb), ("kb", kb), ("g", gb), ("m", mb), ("k", kb), ("b", 1)]
        var number = lower
        var multiplier = mb
        for (suffix, factor) in units where lower.hasSuffix(suffix) {
            number = String(lower.dropLast(suffix.count))
            multiplier = factor
            break
        }
        guard !number.isEmpty, number.allSatisfy({ $0.isNumber || $0 == "." }),
              let value = Double(number), value > 0, value < 1_000_000 else { return nil }
        return Int64(value * Double(multiplier))
    }
}

// MARK: - Kind

enum KindFilter: String, CaseIterable, Identifiable {
    case any
    case folders
    case documents
    case images
    case media
    case archives

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .any: return "All kinds"
        case .folders: return "Folders"
        case .documents: return "Documents"
        case .images: return "Images"
        case .media: return "Audio and video"
        case .archives: return "Archives"
        }
    }

    var extensions: [String] {
        switch self {
        case .any, .folders: return []
        case .documents: return ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "txt", "rtf", "md", "csv", "odt"]
        case .images: return ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp", "svg", "raw"]
        case .media: return ["mp3", "m4a", "wav", "flac", "aiff", "mp4", "mov", "mkv", "avi", "m4v"]
        case .archives: return ["zip", "tar", "gz", "tgz", "rar", "7z", "dmg", "pkg", "xz"]
        }
    }

    /// Reads the value of a `kind:` token when it names a category.
    static func parse(_ value: String) -> KindFilter? {
        switch value.lowercased() {
        case "folder", "folders", "dir", "dirs", "directory", "directories": return .folders
        case "document", "documents", "doc", "docs": return .documents
        case "image", "images", "photo", "photos", "picture", "pictures": return .images
        case "media", "audio", "video", "videos", "music": return .media
        case "archive", "archives": return .archives
        default: return nil
        }
    }
}

// MARK: - Modified

struct ModifiedFilter: Equatable, Hashable {
    /// Number of days back from now. Zero means since the start of today.
    var days: Int

    static let presets: [ModifiedFilter] = [
        ModifiedFilter(days: 0), ModifiedFilter(days: 7), ModifiedFilter(days: 30), ModifiedFilter(days: 365)
    ]

    var label: String {
        switch days {
        case 0: return "Today"
        case 1: return "Past day"
        case 7: return "Past week"
        case 30: return "Past month"
        case 365: return "Past year"
        default:
            if days % 365 == 0 { return "Past \(days / 365) years" }
            if days % 30 == 0 { return "Past \(days / 30) months" }
            if days % 7 == 0 { return "Past \(days / 7) weeks" }
            return "Past \(days) days"
        }
    }

    func cutoff(now: Date = Date(), calendar: Calendar = .current) -> Date {
        if days == 0 { return calendar.startOfDay(for: now) }
        return calendar.date(byAdding: .day, value: -days, to: now) ?? now
    }

    /// Reads the value of a `modified:` token: `today`, `week`, `month`, `year`, or a count like `3d`, `2w`, `6m`, `1y`.
    static func parse(_ value: String) -> ModifiedFilter? {
        let lower = value.lowercased()
        switch lower {
        case "today": return ModifiedFilter(days: 0)
        case "week": return ModifiedFilter(days: 7)
        case "month": return ModifiedFilter(days: 30)
        case "year": return ModifiedFilter(days: 365)
        default: break
        }
        guard let unit = lower.last, let count = Int(lower.dropLast()), count > 0, count <= 10_000 else { return nil }
        switch unit {
        case "d": return ModifiedFilter(days: count)
        case "w": return ModifiedFilter(days: count * 7)
        case "m": return ModifiedFilter(days: count * 30)
        case "y": return ModifiedFilter(days: count * 365)
        default: return nil
        }
    }
}

// MARK: - Combined filters

enum FilterDimension: String, CaseIterable, Identifiable {
    case size, kind, modified
    var id: String { rawValue }

    var title: String {
        switch self {
        case .size: return "Size"
        case .kind: return "Kind"
        case .modified: return "Modified"
        }
    }
}

struct SearchFilters: Equatable {
    var size: SizeRange?
    var kind: KindFilter = .any
    /// Extensions from `ext:` or `kind:pdf`. Lowercase letters and digits only.
    var extensions: [String] = []
    var modified: ModifiedFilter?

    static let none = SearchFilters()

    var isEmpty: Bool {
        size == nil && kind == .any && extensions.isEmpty && modified == nil
    }

    var hasKind: Bool { kind != .any || !extensions.isEmpty }

    var kindLabel: String {
        extensions.isEmpty ? kind.displayName : extensions.map { ".\($0)" }.joined(separator: ", ")
    }

    /// SQL conditions to join with AND. Every value is a number or a checked constant, never raw user text.
    func sqlClauses(now: Date = Date()) -> [String] {
        var clauses: [String] = []
        if let size { clauses.append(size.sqlClause) }
        if kind == .folders {
            clauses.append("is_directory = 1")
        } else if kind != .any || !extensions.isEmpty {
            let all = Array(Set(kind.extensions + extensions)).sorted()
            let likes = all.map { "name_normalized LIKE '%.\($0)'" }.joined(separator: " OR ")
            clauses.append("is_directory = 0 AND (\(likes))")
        }
        if let modified {
            clauses.append("modified_date >= \(modified.cutoff(now: now).timeIntervalSince1970)")
        }
        return clauses
    }
}

// MARK: - Query parsing

struct ParsedQuery: Equatable {
    /// What is left of the query after the filter tokens are taken out.
    var text = ""
    var filters = SearchFilters.none
    /// The token typed for each dimension, so the interface can remove exactly that word.
    var tokens: [FilterDimension: String] = [:]
}

enum QueryParser {
    /// Pulls `size:`, `kind:`, `ext:` and `modified:` words out of a query.
    /// A word that does not form a valid token stays in the search text, so half-typed tokens do nothing.
    static func parse(_ input: String) -> ParsedQuery {
        var result = ParsedQuery()
        var kept: [Substring] = []

        for word in input.split(separator: " ", omittingEmptySubsequences: true) {
            guard let colon = word.firstIndex(of: ":") else { kept.append(word); continue }
            let key = word[..<colon].lowercased()
            let value = String(word[word.index(after: colon)...])
            guard !value.isEmpty else { kept.append(word); continue }

            switch key {
            case "size":
                if let range = SizeRange.parse(value) {
                    result.filters.size = range
                    result.tokens[.size] = String(word)
                    continue
                }
            case "kind", "type":
                if let kind = KindFilter.parse(value) {
                    result.filters.kind = kind
                    result.filters.extensions = []
                    result.tokens[.kind] = String(word)
                    continue
                }
                if let exts = extensions(from: value) {
                    result.filters.kind = .any
                    result.filters.extensions = exts
                    result.tokens[.kind] = String(word)
                    continue
                }
            case "ext":
                if let exts = extensions(from: value) {
                    result.filters.kind = .any
                    result.filters.extensions = exts
                    result.tokens[.kind] = String(word)
                    continue
                }
            case "modified", "date", "changed":
                if let window = ModifiedFilter.parse(value) {
                    result.filters.modified = window
                    result.tokens[.modified] = String(word)
                    continue
                }
            default:
                break
            }
            kept.append(word)
        }

        result.text = kept.joined(separator: " ")
        return result
    }

    /// Takes one token word out of the text. Spacing between the other words is kept as typed.
    static func removing(_ token: String, from text: String) -> String {
        var removed = false
        let words = text.split(separator: " ", omittingEmptySubsequences: true).filter { word in
            if !removed, word == token { removed = true; return false }
            return true
        }
        return words.joined(separator: " ")
    }

    /// `pdf` or `.pdf,docx`. Returns nil when any part is not a plain extension.
    private static func extensions(from value: String) -> [String]? {
        let parts = value.split(separator: ",").map { $0.lowercased().drop(while: { $0 == "." }) }
        guard !parts.isEmpty, parts.count <= 12 else { return nil }
        var result: [String] = []
        for part in parts {
            guard !part.isEmpty, part.count <= 12, part.allSatisfy({ $0.isLetter && $0.isASCII || $0.isNumber && $0.isASCII }) else { return nil }
            result.append(String(part))
        }
        return result
    }
}
