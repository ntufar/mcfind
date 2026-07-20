import Foundation
import AppKit

struct FileItem: Identifiable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let dateModified: Date
    let fileExtension: String?

    var displayName: String {
        return name
    }

    var fileIcon: NSImage {
        return NSWorkspace.shared.icon(forFile: path)
    }

    var formattedSize: String {
        guard !isDirectory else { return "" }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()

        // If today, show time only
        if calendar.isDateInToday(dateModified) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Today " + formatter.string(from: dateModified)
        }

        // If yesterday
        if calendar.isDateInYesterday(dateModified) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Yesterday " + formatter.string(from: dateModified)
        }

        // If this week, show day name
        if let daysAgo = calendar.dateComponents([.day], from: dateModified, to: now).day, daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE HH:mm"
            return formatter.string(from: dateModified)
        }

        // If this year, show date without year
        if calendar.component(.year, from: dateModified) == calendar.component(.year, from: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, HH:mm"
            return formatter.string(from: dateModified)
        }

        // Otherwise show full date
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: dateModified)
    }

    init(url: URL) {
        self.name = url.lastPathComponent
        self.path = url.path

        // Properly detect if this is a directory
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            self.isDirectory = isDir.boolValue
        } else {
            self.isDirectory = false
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            self.size = attributes[.size] as? Int64 ?? 0
            self.dateModified = attributes[.modificationDate] as? Date ?? Date()
        } catch {
            self.size = 0
            self.dateModified = Date()
        }

        self.fileExtension = url.pathExtension.isEmpty ? nil : url.pathExtension
    }

    // Initialize from database
    init(path: String, name: String, isDirectory: Bool, size: Int64, dateModified: Date) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.dateModified = dateModified
        self.fileExtension = URL(fileURLWithPath: path).pathExtension.isEmpty ? nil : URL(fileURLWithPath: path).pathExtension
    }

    // Initialize from enumerator-provided URL properties (avoids extra stat)
    init(url: URL, isDir: Bool, size: Int64, dateModified: Date) {
        self.name = url.lastPathComponent
        self.path = url.path
        self.isDirectory = isDir
        self.size = size
        self.dateModified = dateModified
        self.fileExtension = url.pathExtension.isEmpty ? nil : url.pathExtension
    }
}

enum SizeFilter: String, CaseIterable, Identifiable {
    case any
    case under100KB
    case under1MB
    case under10MB
    case under100MB
    case over100MB
    case over1GB

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .any: return "Any"
        case .under100KB: return "<100 KB"
        case .under1MB: return "<1 MB"
        case .under10MB: return "<10 MB"
        case .under100MB: return "<100 MB"
        case .over100MB: return ">100 MB"
        case .over1GB: return ">1 GB"
        }
    }

    var sqlClause: String {
        switch self {
        case .any: return ""
        case .under100KB: return "AND size < 102400"
        case .under1MB: return "AND size < 1048576"
        case .under10MB: return "AND size < 10485760"
        case .under100MB: return "AND size < 104857600"
        case .over100MB: return "AND size > 104857600 AND is_directory = 0"
        case .over1GB: return "AND size > 1073741824 AND is_directory = 0"
        }
    }
}
