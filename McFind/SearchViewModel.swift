import Foundation
import Combine
import AppKit

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedIndices: Set<Int> = []
    @Published var files: [FileItem] = []
    /// Filters picked from the menus. A filter typed into the search box (`size:>10mb`) wins over the menu for its dimension.
    @Published var menuFilters = SearchFilters.none
    /// Matches the query would have without any filters. Only set when filters hide every result.
    @Published var matchesWithoutFilters: Int = 0
    @Published var recentFiles: [FileItem] = []
    /// The query the current `files` were found with. Lags `searchText` by the debounce and search time.
    @Published var resultsQuery = ""

    // MARK: Filters

    var parsedQuery: ParsedQuery { QueryParser.parse(searchText) }

    /// Menu filters with the typed tokens laid over them.
    var effectiveFilters: SearchFilters { Self.merge(menu: menuFilters, parsed: parsedQuery) }

    var hasActiveFilters: Bool { !effectiveFilters.isEmpty }

    /// True when there is anything to search for: words, or filters on their own.
    var hasQuery: Bool { !parsedQuery.text.isEmpty || hasActiveFilters }

    private static func merge(menu: SearchFilters, parsed: ParsedQuery) -> SearchFilters {
        var result = menu
        if let size = parsed.filters.size { result.size = size }
        if parsed.tokens[.kind] != nil {
            result.kind = parsed.filters.kind
            result.extensions = parsed.filters.extensions
        }
        if let modified = parsed.filters.modified { result.modified = modified }
        return result
    }

    /// Label for a dimension's active filter, or nil when that dimension is not filtered.
    func activeLabel(for dimension: FilterDimension) -> String? {
        let filters = effectiveFilters
        switch dimension {
        case .size: return filters.size?.label
        case .kind: return filters.hasKind ? filters.kindLabel : nil
        case .modified: return filters.modified?.label
        }
    }

    func isFromToken(_ dimension: FilterDimension) -> Bool {
        parsedQuery.tokens[dimension] != nil
    }

    var activeFilterSummary: String {
        FilterDimension.allCases.compactMap { dimension in
            activeLabel(for: dimension).map { "\(dimension.title.lowercased()): \($0)" }
        }.joined(separator: ", ")
    }

    /// Picking from a menu replaces a token typed for the same dimension, so the two never disagree.
    func setSize(_ range: SizeRange?) {
        dropToken(.size)
        menuFilters.size = range
    }

    func setKind(_ kind: KindFilter) {
        dropToken(.kind)
        menuFilters.kind = kind
        menuFilters.extensions = []
    }

    func setModified(_ window: ModifiedFilter?) {
        dropToken(.modified)
        menuFilters.modified = window
    }

    func clearFilter(_ dimension: FilterDimension) {
        switch dimension {
        case .size: setSize(nil)
        case .kind: setKind(.any)
        case .modified: setModified(nil)
        }
    }

    func clearFilters() {
        FilterDimension.allCases.forEach(clearFilter)
    }

    /// Adds example text from the welcome screen to the search box.
    func insertQuerySnippet(_ snippet: String) {
        searchText = searchText.isEmpty ? snippet : searchText + " " + snippet
    }

    private func dropToken(_ dimension: FilterDimension) {
        if let token = parsedQuery.tokens[dimension] {
            searchText = QueryParser.removing(token, from: searchText)
        }
    }

    var selectedFile: FileItem? {
        guard let idx = selectedIndices.sorted().last, idx >= 0, idx < files.count else { return nil }
        return files[idx]
    }

    var selectedFiles: [FileItem] {
        selectedIndices.sorted().compactMap { files.indices.contains($0) ? files[$0] : nil }
    }

    private let fileIndexer = FileIndexer()
    private var cancellables = Set<AnyCancellable>()
    private let searchQueue = DispatchQueue(label: "com.mcfind.search", qos: .userInitiated)
    private let quickLookController = QuickLookController()

    var isIndexing: Bool {
        return fileIndexer.isIndexing
    }

    var isIncremental: Bool {
        return fileIndexer.isIncremental
    }

    var isLoadingFromDisk: Bool {
        return fileIndexer.isLoadingFromDisk
    }

    var progress: Double {
        return fileIndexer.progress
    }

    var statusMessage: String {
        return fileIndexer.statusMessage
    }

    var indexedCount: Int {
        return fileIndexer.indexedCount
    }

    var totalFiles: Int {
        return fileIndexer.totalFiles
    }

    var lastIndexedAt: Date? {
        return fileIndexer.lastIndexedAt
    }

    /// Share of the previous index size already scanned. Nil when no previous index exists to compare against.
    var indexingFraction: Double? {
        guard fileIndexer.totalFiles > 0, !isIncremental else { return nil }
        return min(Double(fileIndexer.indexedCount) / Double(fileIndexer.totalFiles), 0.99)
    }

    var isQuickLookVisible: Bool {
        quickLookController.isVisible
    }

    init() {
        loadRecentFiles()
        setupSearchBinding()
        fileIndexer.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        fileIndexer.databaseDidChange
            .sink { [weak self] deletedPaths in
                guard let self = self else { return }
                let pathsToRemove = Set(deletedPaths)
                let indicesToRemove = self.files.enumerated()
                    .filter { pathsToRemove.contains($0.element.path) }
                    .map(\.offset)
                    .sorted(by: >)
                for index in indicesToRemove {
                    self.files.remove(at: index)
                }
            }
            .store(in: &cancellables)
    }

    private func setupSearchBinding() {
        Publishers.CombineLatest(
            $searchText.removeDuplicates().debounce(for: .milliseconds(150), scheduler: RunLoop.main),
            $menuFilters.removeDuplicates()
        )
        .sink { [weak self] text, menu in
            let parsed = QueryParser.parse(text)
            let filters = Self.merge(menu: menu, parsed: parsed)
            Log.search.debug("⌨️  SearchText changed to: '\(text)' | text: '\(parsed.text)' | filters: \(String(describing: filters))")
            self?.performSearch(parsed.text, filters: filters)
        }
        .store(in: &cancellables)
    }

    private func performSearch(_ query: String, filters: SearchFilters = .none) {
        Log.search.debug("🚀 performSearch() called on \(Thread.current)")
        searchQueue.async { [weak self] in
            Log.search.debug("  🔄 Search queue executing...")
            guard let self = self else { return }
            Log.search.debug("  🔍 Calling fileIndexer.search() for: '\(query)'")
            let results = self.fileIndexer.search(query, filters: filters)
            var hidden = 0
            if results.isEmpty && !query.isEmpty && !filters.isEmpty {
                hidden = self.fileIndexer.search(query).count
            }
            Log.search.debug("  ✅ fileIndexer.search() returned \(results.count) results")

            DispatchQueue.main.async {
                Log.search.debug("  📝 Updating UI with \(results.count) results")
                self.files = results
                self.matchesWithoutFilters = hidden
                self.resultsQuery = query
                self.selectedIndices = results.isEmpty ? [] : [0]
                Log.search.debug("  ✅ UI updated")
            }
        }
    }

    func startIndexing() {
        fileIndexer.startIndexing()
    }

    func cancelIndexing() {
        fileIndexer.cancel()
    }

    func toggleQuickLook() {
        let focusIndex = selectedIndices.sorted().last ?? 0
        quickLookController.files = files
        quickLookController.selectedIndex = focusIndex
        quickLookController.togglePanel()
    }

    func selectNext() {
        guard !files.isEmpty else { return }
        let current = selectedIndices.sorted().last ?? 0
        let next = (current + 1) % files.count
        selectedIndices = [next]
    }

    func selectPrevious() {
        guard !files.isEmpty else { return }
        let current = selectedIndices.sorted().last ?? 0
        let prev = current == 0 ? files.count - 1 : current - 1
        selectedIndices = [prev]
    }

    func selectFile(at index: Int) {
        guard index >= 0 && index < files.count else { return }
        selectedIndices = [index]
    }

    func toggleSelection(at index: Int) {
        guard index >= 0 && index < files.count else { return }
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            selectedIndices.insert(index)
        }
    }

    func selectAll() {
        selectedIndices = Set(0..<files.count)
    }

    func openSelectedFiles() {
        open(selectedFiles)
    }

    func open(_ items: [FileItem]) {
        for item in items {
            NSWorkspace.shared.open(URL(fileURLWithPath: item.path))
        }
        recordRecent(items)
    }

    // MARK: Recent files

    private static let recentsKey = "recentFilePaths"
    private static let recentsLimit = 6

    private func loadRecentFiles() {
        let paths = UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []
        recentFiles = paths
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { FileItem(url: URL(fileURLWithPath: $0)) }
    }

    private func recordRecent(_ items: [FileItem]) {
        guard !items.isEmpty else { return }
        var paths = UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []
        for item in items.reversed() {
            paths.removeAll { $0 == item.path }
            paths.insert(item.path, at: 0)
        }
        paths = Array(paths.prefix(Self.recentsLimit))
        UserDefaults.standard.set(paths, forKey: Self.recentsKey)
        loadRecentFiles()
    }

    func reveal(_ items: [FileItem]) {
        let urls = items.map { URL(fileURLWithPath: $0.path) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func copyPaths(of items: [FileItem]) {
        guard !items.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(items.map(\.path).joined(separator: "\n"), forType: .string)
    }

    func revealInFinder() {
        let urls = selectedFiles.map { URL(fileURLWithPath: $0.path) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func copyPaths() {
        guard !selectedFiles.isEmpty else { return }
        NSPasteboard.general.clearContents()
        let paths = selectedFiles.map(\.path)
        NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
    }

    func copyFiles() {
        guard !selectedFiles.isEmpty else { return }
        NSPasteboard.general.clearContents()
        let urls = selectedFiles.map { NSURL(fileURLWithPath: $0.path) as NSURL }
        NSPasteboard.general.writeObjects(urls)
    }

    func moveToTrashFiles(at indices: Set<Int>) {
        let sortedIndices = indices.sorted(by: >)
        for index in sortedIndices {
            guard index >= 0, index < files.count else { continue }
            let file = files[index]
            let url = URL(fileURLWithPath: file.path)
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                Log.search.error("❌ Failed to move file to trash: \(error)")
            }
        }
        for index in sortedIndices {
            guard index >= 0, index < files.count else { continue }
            files.remove(at: index)
        }
        selectedIndices = files.isEmpty ? [] : [min(sortedIndices.min() ?? 0, files.count - 1)]
    }

    func renameFile(at index: Int, to newName: String) {
        guard index >= 0, index < files.count else { return }
        let file = files[index]
        let oldURL = URL(fileURLWithPath: file.path)
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
        } catch {
            Log.search.error("❌ Failed to rename file: \(error)")
        }
    }

    func openTerminal() {
        guard let file = selectedFile else { return }
        let directory = URL(fileURLWithPath: file.path).deletingLastPathComponent()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("mcfind_terminal_here.command")
        let command = "cd \(directory.path.shellEscaped)\nclear\nexec $SHELL\n"
        do {
            try command.write(to: tempURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempURL.path)
            NSWorkspace.shared.open(tempURL)
        } catch {
            Log.search.error("❌ Failed to open Terminal: \(error)")
        }
    }

    func copyPathsEscaped() {
        guard !selectedFiles.isEmpty else { return }
        NSPasteboard.general.clearContents()
        let escaped = selectedFiles.map(\.path.shellEscaped).joined(separator: " ")
        NSPasteboard.general.setString(escaped, forType: .string)
    }
}

private extension String {
    var shellEscaped: String {
        let escaped = self.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
