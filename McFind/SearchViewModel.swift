import Foundation
import Combine
import AppKit

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedIndex = 0
    @Published var files: [FileItem] = []
    @Published var selectedSizeFilter: SizeFilter = .any

    var selectedFile: FileItem? {
        guard selectedIndex >= 0, selectedIndex < files.count else { return nil }
        return files[selectedIndex]
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
        // Forward FileIndexer changes to SwiftUI so status bar updates properly
        fileIndexer.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
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
                self.selectedIndex = 0
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
        quickLookController.files = files
        quickLookController.selectedIndex = selectedIndex
        quickLookController.togglePanel()
    }

    func selectNext() {
        guard !files.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % files.count
    }

    func selectPrevious() {
        guard !files.isEmpty else { return }
        selectedIndex = selectedIndex == 0 ? files.count - 1 : selectedIndex - 1
    }

    func selectFile(at index: Int) {
        guard index >= 0 && index < files.count else { return }
        guard selectedIndex != index else { return }
        selectedIndex = index
    }

    func openSelectedFile() {
        guard let file = selectedFile else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
    }

    func revealInFinder() {
        guard let file = selectedFile else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
    }

    func copyPath() {
        guard let file = selectedFile else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(file.path, forType: .string)
    }

    func copyFile() {
        guard let file = selectedFile else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([NSURL(fileURLWithPath: file.path)])
    }

    func moveToTrashFile(at index: Int) {
        guard index >= 0, index < files.count else { return }
        let file = files[index]
        let url = URL(fileURLWithPath: file.path)
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            files.remove(at: index)
            if files.isEmpty {
                selectedIndex = 0
            } else {
                selectedIndex = min(index, files.count - 1)
            }
        } catch {
            print("❌ Failed to move file to trash: \(error)")
        }
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
}
