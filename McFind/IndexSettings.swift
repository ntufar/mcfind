import Foundation
import Combine

struct IndexPath {
    let path: String
    let displayName: String
    let isTopLevel: Bool
    let defaultEnabled: Bool

    var sortOrder: Int {
        // Library paths should appear right after Library
        if path.hasPrefix("Library/") {
            return 1000 + path.count // Sub-paths of Library
        } else if path == "Library" {
            return 999 // Library itself
        } else {
            return 0 // Other top-level folders
        }
    }
}

class IndexSettings: ObservableObject {
    static let shared = IndexSettings()

    @Published var excludedPaths: Set<String> {
        didSet {
            saveSettings()
        }
    }

    private let defaults = UserDefaults.standard
    private let excludedPathsKey = "excludedPaths"

    // Predefined important paths
    static let predefinedPaths: [IndexPath] = [
        IndexPath(path: "Library", displayName: "Library", isTopLevel: true, defaultEnabled: false),
        IndexPath(path: "Library/CloudStorage", displayName: "Library → CloudStorage (OneDrive, SharePoint, Google Drive)", isTopLevel: false, defaultEnabled: true),
        IndexPath(path: "Library/Mobile Documents", displayName: "Library → iCloud Drive", isTopLevel: false, defaultEnabled: true)
    ]

    // Default paths to exclude (Library only, but not its important subfolders)
    static let defaultExcludedPaths: Set<String> = ["Library"]

    init() {
        if let saved = defaults.stringArray(forKey: excludedPathsKey) {
            self.excludedPaths = Set(saved)
        } else {
            // First launch - use defaults
            self.excludedPaths = IndexSettings.defaultExcludedPaths
            saveSettings()
        }
    }

    private func saveSettings() {
        defaults.set(Array(excludedPaths), forKey: excludedPathsKey)
    }

    func isExcluded(_ path: String) -> Bool {
        return excludedPaths.contains(path)
    }

    func shouldIndexPath(_ path: String, homeDirectory: String) -> Bool {
        // Get the relative path from home directory
        guard path.hasPrefix(homeDirectory + "/") else {
            return true // Not under home directory, index it
        }

        let relativePath = String(path.dropFirst(homeDirectory.count + 1))

        // Check specific paths first (more specific paths take precedence)
        // For example: if "Library/CloudStorage" is enabled but "Library" is disabled,
        // we should still index CloudStorage

        // Check if this path or any parent path is explicitly enabled (not excluded)
        for predefinedPath in Self.predefinedPaths.sorted(by: { $0.path.count > $1.path.count }) {
            if relativePath.hasPrefix(predefinedPath.path + "/") || relativePath == predefinedPath.path {
                // If this specific path is not excluded, allow indexing
                if !excludedPaths.contains(predefinedPath.path) {
                    return true
                }
                // If this specific path is excluded, block indexing
                if excludedPaths.contains(predefinedPath.path) && relativePath == predefinedPath.path {
                    return false
                }
            }
        }

        // Check top-level folder
        let components = relativePath.split(separator: "/")
        guard let firstComponent = components.first else {
            return true
        }

        let topLevelFolder = String(firstComponent)
        return !excludedPaths.contains(topLevelFolder)
    }

    func resetToDefaults() {
        excludedPaths = IndexSettings.defaultExcludedPaths
    }
}
