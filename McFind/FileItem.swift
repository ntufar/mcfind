import Foundation
import AppKit
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable {
    let id = UUID()
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
        if isDirectory {
            return NSImage(named: NSImage.folderName) ?? NSImage()
        } else {
            if #available(macOS 12.0, *) {
                // Prefer deriving UTType from extension
                if let fileExtension = fileExtension,
                   let contentType = UTType(filenameExtension: fileExtension) {
                    return NSWorkspace.shared.icon(for: contentType)
                }
                
                // Try deriving UTType from the URL resource values
                let url = URL(fileURLWithPath: path)
                if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
                    return NSWorkspace.shared.icon(for: contentType)
                }
                
                // Generic item icon on modern macOS without using deprecated API
                return NSWorkspace.shared.icon(for: .item)
            } else {
                // Legacy fallback for pre-macOS 12
                return NSWorkspace.shared.icon(forFileType: fileExtension ?? "")
            }
        }
    }
    
    var formattedSize: String {
        if isDirectory {
            return ""
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: dateModified)
    }
    
    init(url: URL) {
        self.name = url.lastPathComponent
        self.path = url.path
        self.isDirectory = url.hasDirectoryPath
        
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
}
