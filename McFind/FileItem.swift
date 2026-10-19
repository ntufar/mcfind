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

    /// One pattern per age band so the column stays narrow and scannable:
    /// "Today, 7:48 PM", "Tue, 7:48 PM", "Mar 4", "Sep 17, 2025".
    var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        let time = timeFormatter.string(from: dateModified)

        if calendar.isDateInToday(dateModified) {
            return "Today, " + time
        }

        if calendar.isDateInYesterday(dateModified) {
            return "Yesterday, " + time
        }

        if let daysAgo = calendar.dateComponents([.day], from: dateModified, to: now).day, daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: dateModified) + ", " + time
        }

        let formatter = DateFormatter()
        if calendar.component(.year, from: dateModified) == calendar.component(.year, from: now) {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
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
