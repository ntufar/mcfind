import Foundation
import Combine

class FileIndexer: ObservableObject {
    @Published var isIndexing = false
    @Published var isIncremental = false
    @Published var statusMessage = ""
    @Published var progress: Double = 0.0
    @Published var indexedCount = 0
    @Published var totalFiles = 0
    @Published var isLoadingFromDisk = false

    private let database = IndexDatabase()
    private var fileMonitor: FileMonitor?
    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    private let indexingQueue = DispatchQueue(label: "com.mcfind.indexing", qos: .utility)
    private var isCancelled = false
    private let settings = IndexSettings.shared

    private var indexDotFiles: Bool {
        UserDefaults.standard.bool(forKey: "indexDotFiles")
    }

    init() {
        loadIndexFromDisk()
        startFileMonitoring()
    }

    deinit {
        fileMonitor?.stop()
    }

    private func loadIndexFromDisk() {
        let dbExists = FileManager.default.fileExists(atPath: database.dbPath)

        if dbExists {
            DispatchQueue.main.async { [weak self] in
                self?.isLoadingFromDisk = false
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isLoadingFromDisk = true
            }
        }

        indexingQueue.async { [weak self] in
            guard let self = self else { return }

            // Purge any dot files that were indexed before dot-file filtering was enabled
            if !self.indexDotFiles {
                self.database.removeDotFiles()
            }

            let count = self.database.getFileCount()
            print("📊 Loaded \(count) files from disk")

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.totalFiles = count
                self.isLoadingFromDisk = false

                if count == 0 {
                    self.startIndexing()
                } else {
                    self.startIncrementalIndexing()
                }
            }
        }
    }

    func startIncrementalIndexing() {
        guard !isIndexing else { return }
        isCancelled = false
        isIndexing = true
        isIncremental = true
        progress = 0.0
        indexedCount = 0
        statusMessage = "Scanning for file changes..."

        print("🔍 Starting incremental indexing")
        let estimatedTotal = database.getFileCount()
        let newGeneration = database.getCurrentGeneration() + 1
        database.storeCurrentGeneration(newGeneration)

        indexingQueue.async { [weak self] in
            self?.incrementalIndexDirectory(estimatedTotal: estimatedTotal, generation: newGeneration)
        }
    }

    private func startFileMonitoring() {
        fileMonitor = FileMonitor(paths: [homeDirectory.path]) { [weak self] path, flags in
            self?.handleFileSystemEvent(path: path, flags: flags)
        }
        fileMonitor?.start()
    }

    private func handleFileSystemEvent(path: String, flags: FSEventStreamEventFlags) {
        // Ignore events for the database directory itself
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("McFind", isDirectory: true).path

        if path.hasPrefix(appFolder) {
            // Ignore database files and temp files
            return
        }

        // Check if path should be indexed based on settings
        if !settings.shouldIndexPath(path, homeDirectory: homeDirectory.path) {
            return
        }

        // Skip dot files/directories unless enabled in settings
        if !indexDotFiles && URL(fileURLWithPath: path).pathComponents.contains(where: { $0.hasPrefix(".") }) {
            return
        }

        let isCreated = (flags & UInt32(kFSEventStreamEventFlagItemCreated)) != 0
        let isRemoved = (flags & UInt32(kFSEventStreamEventFlagItemRemoved)) != 0
        let isModified = (flags & UInt32(kFSEventStreamEventFlagItemModified)) != 0
        let isRenamed = (flags & UInt32(kFSEventStreamEventFlagItemRenamed)) != 0

        if isRemoved {
            print("🗑️  File removed: \(path)")
            database.deleteFile(atPath: path)
            DispatchQueue.main.async { [weak self] in
                self?.totalFiles = self?.database.getFileCount() ?? 0
            }
        } else if isCreated || isRenamed {
            print("➕ File created/renamed: \(path)")
            let url = URL(fileURLWithPath: path)
            let file = FileItem(url: url)
            database.insertFile(file)
            DispatchQueue.main.async { [weak self] in
                self?.totalFiles = self?.database.getFileCount() ?? 0
            }
        } else if isModified {
            // Update the file in the database
            let url = URL(fileURLWithPath: path)
            if fileManager.fileExists(atPath: path) {
                let file = FileItem(url: url)
                database.insertFile(file)
            }
        }
    }

    func startIndexing() {
        guard !isIndexing else { return }
        isCancelled = false
        isIndexing = true
        isIncremental = false
        progress = 0.0
        indexedCount = 0
        statusMessage = "Scanning files..."

        print("🔍 Starting full reindex")
        database.clearDatabase()

        indexingQueue.async { [weak self] in
            self?.indexDirectory()
        }
    }

    func cancel() {
        isCancelled = true
    }

    private func indexDirectory() {
        print("🔍 Starting indexing from: \(homeDirectory.path)")

        let enumerator = fileManager.enumerator(
            at: homeDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isPackageKey],
            options: []
        )

        guard let enumerator = enumerator else {
            print("❌ Failed to create enumerator")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isIndexing = false
                self.isIncremental = false
            }
            return
        }

        print("✅ Enumerator created successfully")

        let estimatedFileCount = 500000
        var batch: [FileItem] = []
        var count = 0
        let batchSize = 1000

        for case let fileURL as URL in enumerator {
            if isCancelled {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isIndexing = false
                    self.isIncremental = false
                }
                return
            }

            let path = fileURL.path

            // Check if this path should be indexed based on settings
            if !settings.shouldIndexPath(path, homeDirectory: homeDirectory.path) {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                    enumerator.skipDescendants()
                }
                continue
            }

            // Skip dot files/directories unless enabled in settings
            if !indexDotFiles && fileURL.lastPathComponent.hasPrefix(".") {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                    enumerator.skipDescendants()
                }
                continue
            }

            // Add the file or directory to the index FIRST
            batch.append(FileItem(url: fileURL))
            count += 1

            // Update UI periodically (every 100 files) so users see progress
            // before the first DB batch commit
            if count % 100 == 0 {
                let currentCount = count
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, !self.isCancelled else { return }
                    self.indexedCount = currentCount
                }
            }

            // Then check if this is a directory whose descendants we should skip
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                if shouldSkipDirectory(fileURL) {
                    enumerator.skipDescendants()
                }
            }

            if batch.count >= batchSize {
                let itemsToAdd = batch
                let currentCount = count

                // Insert batch into database
                database.insertFiles(itemsToAdd)

                DispatchQueue.main.async { [weak self] in
                    guard let self = self, !self.isCancelled else { return }
                    self.indexedCount = currentCount
                    self.statusMessage = "Indexing \(currentCount) files..."
                    self.progress = min(Double(currentCount) / Double(estimatedFileCount), 0.95)
                }
                batch.removeAll(keepingCapacity: true)
            }
        }

        if !batch.isEmpty {
            database.insertFiles(batch)
            let currentCount = count
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isCancelled else { return }
                self.indexedCount = currentCount
                self.statusMessage = "Indexing \(currentCount) files..."
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            print("✅ Indexing complete: \(count) files indexed")

            self.isIndexing = false
            self.isIncremental = false
            self.progress = 1.0
            self.totalFiles = count
        }
    }

    private func incrementalIndexDirectory(estimatedTotal: Int, generation: Int64) {
        print("🔍 Incremental scanning from: \(homeDirectory.path)")

        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isPackageKey]

        let enumerator = fileManager.enumerator(
            at: homeDirectory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: []
        )

        guard let enumerator = enumerator else {
            print("❌ Failed to create enumerator")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isIndexing = false
                self.isIncremental = false
            }
            return
        }

        var batch: [FileItem] = []
        var count = 0
        let batchSize = 1000
        var changedDirs: [(path: String, mtime: Double)] = []

        for case let fileURL as URL in enumerator {
            if isCancelled {
                finishIndexing(count: count)
                return
            }

            let path = fileURL.path

            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys) else {
                continue
            }

            let isDir = resourceValues.isDirectory ?? false
            let isPackage = resourceValues.isPackage ?? false

            if !settings.shouldIndexPath(path, homeDirectory: homeDirectory.path) {
                if isDir { enumerator.skipDescendants() }
                continue
            }

            // Skip dot files/directories unless enabled in settings
            if !indexDotFiles && fileURL.lastPathComponent.hasPrefix(".") {
                if isDir { enumerator.skipDescendants() }
                continue
            }

            if isDir && !isPackage {
                if shouldSkipDirectory(fileURL) {
                    enumerator.skipDescendants()
                    continue
                }

                let currentMtime = resourceValues.contentModificationDate?.timeIntervalSince1970 ?? 0
                let storedMtime = database.getDirMtime(path)

                if let stored = storedMtime, abs(currentMtime - stored) < 0.001 {
                    database.updateGeneration(path: path, generation: generation)
                    enumerator.skipDescendants()
                    continue
                }

                let size = resourceValues.fileSize ?? 0
                let date = resourceValues.contentModificationDate ?? Date()
                batch.append(FileItem(url: fileURL, isDir: true, size: Int64(size), dateModified: date))
                count += 1
                changedDirs.append((path, currentMtime))
            } else if !isPackage {
                let size = resourceValues.fileSize ?? 0
                let date = resourceValues.contentModificationDate ?? Date()
                batch.append(FileItem(url: fileURL, isDir: false, size: Int64(size), dateModified: date))
                count += 1
            }

            // Update UI periodically so users see progress before first batch commit
            if count > 0, count % 100 == 0 {
                let currentCount = count
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, !self.isCancelled else { return }
                    self.indexedCount = currentCount
                }
            }

            if batch.count >= batchSize {
                database.insertFiles(batch, generation: generation)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, !self.isCancelled else { return }
                    self.indexedCount = count
                    self.statusMessage = "Indexing \(count) changed files..."
                    self.progress = min(Double(count) / Double(max(estimatedTotal, 1)), 0.95)
                }
                batch.removeAll(keepingCapacity: true)
            }
        }

        if !batch.isEmpty {
            database.insertFiles(batch, generation: generation)
        }

        DispatchQueue.main.async { [weak self] in
            self?.statusMessage = "Saving directory timestamps..."
        }

        for (dirPath, mtime) in changedDirs {
            database.setDirMtime(dirPath, mtime: mtime)
        }

        DispatchQueue.main.async { [weak self] in
            self?.statusMessage = "Cleaning up removed files..."
        }

        let deletedCount = database.deleteByGeneration(notEqual: generation)
        if deletedCount > 0 {
            print("🗑️  Removed \(deletedCount) stale index entries")
        }

        database.storeLastIndexedAt(Date())
        finishIndexing(count: count)
    }

    private func finishIndexing(count: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            print("✅ Incremental indexing finished: \(count) files processed")
            self.isIndexing = false
            self.isIncremental = false
            self.progress = 1.0
            self.totalFiles = self.database.getFileCount()
        }
    }

    private func shouldSkipDirectory(_ url: URL) -> Bool {
        let path = url.path
        let lastComponent = url.lastPathComponent

        // Skip common cache and temporary directories
        let skipDirectoryNames = [
            "node_modules",
            ".git",
            ".svn",
            ".hg",
            "__pycache__",
            ".pytest_cache",
            ".mypy_cache",
            ".tox",
            "venv",
            ".venv",
            "target",
            "dist",
            "build",
            ".next",
            ".nuxt",
            "coverage"
        ]

        if skipDirectoryNames.contains(lastComponent) {
            return true
        }

        // Skip specific system paths within Library
        // But don't add CloudStorage or Mobile Documents here - they're controlled by settings
        let relativeSkipPaths = [
            "/Library/Caches",
            "/Library/Logs",
            "/Library/Application Support/Google/Chrome",
            "/Library/Application Support/Firefox",
            "/.Trash",
            "/Library/Developer/Xcode/DerivedData",
            "/Library/Developer/CoreSimulator",
            "/Library/Mail",
            "/Library/Containers",
            "/Library/Application Support/com.apple",
            "/Library/Saved Application State"
        ]

        if relativeSkipPaths.contains(where: { path.hasPrefix(homeDirectory.path + $0) }) {
            return true
        }

        // Skip package bundles
        let pathExtension = url.pathExtension.lowercased()
        let packageExtensions = ["app", "bundle", "framework", "plugin", "kext", "xcodeproj", "xcworkspace"]

        return packageExtensions.contains(pathExtension)
    }

    func search(_ query: String, sizeFilter: SizeFilter = .any) -> [FileItem] {
        return database.search(query, filterDotFiles: !indexDotFiles, sizeFilter: sizeFilter)
    }

    func removeDotFilesFromIndex() {
        database.removeDotFiles()
    }
}
