import Foundation
import Combine

class FileIndexer: ObservableObject {
    @Published var isIndexing = false
    @Published var progress: Double = 0.0
    @Published var indexedCount = 0
    @Published var totalFiles = 0
    
    private var allFiles: [FileItem] = []
    private var filteredFiles: [FileItem] = []
    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    
    var files: [FileItem] {
        return filteredFiles
    }
    
    func startIndexing() {
        guard !isIndexing else { return }
        
        isIndexing = true
        progress = 0.0
        indexedCount = 0
        allFiles.removeAll()
        filteredFiles.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.indexDirectory(self?.homeDirectory ?? URL(fileURLWithPath: "/"))
        }
    }
    
    private func indexDirectory(_ url: URL) {
        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageContents]
        )
        
        guard let enumerator = enumerator else { return }
        
        var fileCount = 0
        let startTime = Date()
        
        for case let fileURL as URL in enumerator {
            // Skip system directories and hidden files
            if shouldSkipDirectory(fileURL) {
                enumerator.skipDescendants()
                continue
            }
            
            let fileItem = FileItem(url: fileURL)
            DispatchQueue.main.async { [weak self] in
                self?.allFiles.append(fileItem)
                self?.indexedCount += 1
                fileCount += 1
                
                // Update progress every 100 files
                if fileCount % 100 == 0 {
                    self?.progress = Double(fileCount) / 10000.0 // Estimate
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.isIndexing = false
            self?.progress = 1.0
            self?.totalFiles = fileCount
            self?.filteredFiles = self?.allFiles ?? []
        }
    }
    
    private func shouldSkipDirectory(_ url: URL) -> Bool {
        let path = url.path
        let skipPaths = [
            "/Library/Caches",
            "/Library/Logs",
            "/Library/Application Support/Google/Chrome",
            "/Library/Application Support/Firefox",
            "/.Trash",
            "/Library/Developer/Xcode/DerivedData",
            "/Library/Developer/CoreSimulator"
        ]
        
        return skipPaths.contains { path.hasPrefix($0) }
    }
    
    func search(_ query: String) {
        guard !query.isEmpty else {
            filteredFiles = allFiles
            return
        }
        
        let lowercaseQuery = query.lowercased()
        filteredFiles = allFiles.filter { file in
            file.name.lowercased().contains(lowercaseQuery) ||
            file.path.lowercased().contains(lowercaseQuery)
        }.sorted { first, second in
            // Prioritize exact matches and directory matches
            let firstScore = calculateScore(file: first, query: lowercaseQuery)
            let secondScore = calculateScore(file: second, query: lowercaseQuery)
            return firstScore > secondScore
        }
    }
    
    private func calculateScore(file: FileItem, query: String) -> Int {
        var score = 0
        let name = file.name.lowercased()
        let path = file.path.lowercased()
        
        // Exact name match gets highest score
        if name == query {
            score += 1000
        }
        // Name starts with query
        else if name.hasPrefix(query) {
            score += 500
        }
        // Name contains query
        else if name.contains(query) {
            score += 100
        }
        
        // Path contains query
        if path.contains(query) {
            score += 50
        }
        
        // Directory gets slight boost
        if file.isDirectory {
            score += 10
        }
        
        return score
    }
}
