import Foundation
import Combine
import AppKit

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedIndices: Set<Int> = []
    @Published var files: [FileItem] = []
    @Published var selectedSizeFilter: SizeFilter = .any

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

    var isQuickLookVisible: Bool {
        quickLookController.isVisible
    }

    init() {
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
            $selectedSizeFilter
        )
        .sink { [weak self] query, sizeFilter in
            print("⌨️  SearchText changed to: '\(query)' | sizeFilter: \(sizeFilter.displayName)")
            self?.performSearch(query, sizeFilter: sizeFilter)
        }
        .store(in: &cancellables)
    }

    private func performSearch(_ query: String, sizeFilter: SizeFilter = .any) {
        print("🚀 performSearch() called on \(Thread.current)")
        searchQueue.async { [weak self] in
            print("  🔄 Search queue executing...")
            guard let self = self else { return }
            print("  🔍 Calling fileIndexer.search() for: '\(query)' sizeFilter: \(sizeFilter.displayName)")
            let results = self.fileIndexer.search(query, sizeFilter: sizeFilter)
            print("  ✅ fileIndexer.search() returned \(results.count) results")

            DispatchQueue.main.async {
                print("  📝 Updating UI with \(results.count) results")
                self.files = results
                self.selectedIndices = results.isEmpty ? [] : [0]
                print("  ✅ UI updated")
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
        let urls = selectedFiles.map { URL(fileURLWithPath: $0.path) }
        for url in urls {
            NSWorkspace.shared.open(url)
        }
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
                print("❌ Failed to move file to trash: \(error)")
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
            print("❌ Failed to rename file: \(error)")
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
            print("❌ Failed to open Terminal: \(error)")
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
