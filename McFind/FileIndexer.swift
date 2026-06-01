import Foundation
import Combine

class FileIndexer: ObservableObject {
    @Published var isIndexing = false
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

    init() {
        loadIndexFromDisk()
        startFileMonitoring()
    }

    deinit {
        fileMonitor?.stop()
    }

    private func loadIndexFromDisk() {
        // Check if database file exists and has size > 0
        let dbExists = FileManager.default.fileExists(atPath: database.dbPath)

        if dbExists {
            // Database exists, show UI immediately
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

            let count = self.database.getFileCount()
            print("📊 Loaded \(count) files from disk")

            DispatchQueue.main.async { [weak self] in
                self?.totalFiles = count
                self?.isLoadingFromDisk = false

                // If no index exists, start initial indexing
                if count == 0 {
                    self?.startIndexing()
                }
            }
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
        progress = 0.0
        indexedCount = 0

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
                self?.isIndexing = false
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
                    self?.isIndexing = false
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

            // Add the file or directory to the index FIRST
            batch.append(FileItem(url: fileURL))
            count += 1

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
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            print("✅ Indexing complete: \(count) files indexed")

            self.isIndexing = false
            self.progress = 1.0
            self.totalFiles = count
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

    func search(_ query: String) -> [FileItem] {
        return database.search(query)
    }
}
