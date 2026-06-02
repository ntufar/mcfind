import Foundation
import Combine
import AppKit

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedFile: FileItem?
    @Published var selectedIndex = 0
    @Published var files: [FileItem] = []

    private let fileIndexer = FileIndexer()
    private var cancellables = Set<AnyCancellable>()
    private let searchQueue = DispatchQueue(label: "com.mcfind.search", qos: .userInitiated)

    var isIndexing: Bool {
        return fileIndexer.isIndexing
    }

    var isLoadingFromDisk: Bool {
        return fileIndexer.isLoadingFromDisk
    }

    var progress: Double {
        return fileIndexer.progress
    }

    var indexedCount: Int {
        return fileIndexer.indexedCount
    }

    var totalFiles: Int {
        return fileIndexer.totalFiles
    }

    init() {
        setupSearchBinding()
    }

    private func setupSearchBinding() {
        $searchText
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] query in
                print("⌨️  SearchText changed to: '\(query)'")
                self?.performSearch(query)
            }
            .store(in: &cancellables)
    }

    private func performSearch(_ query: String) {
        print("🚀 performSearch() called on \(Thread.current)")
        searchQueue.async { [weak self] in
            print("  🔄 Search queue executing...")
            guard let self = self else { return }
            print("  🔍 Calling fileIndexer.search() for: '\(query)'")
            let results = self.fileIndexer.search(query)
            print("  ✅ fileIndexer.search() returned \(results.count) results")

            DispatchQueue.main.async {
                print("  📝 Updating UI with \(results.count) results")
                self.files = results
                self.selectedIndex = 0
                self.selectedFile = self.files.first
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

    func selectNext() {
        guard !files.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % files.count
        selectedFile = files[selectedIndex]
    }

    func selectPrevious() {
        guard !files.isEmpty else { return }
        selectedIndex = selectedIndex == 0 ? files.count - 1 : selectedIndex - 1
        selectedFile = files[selectedIndex]
    }

    func selectFile(at index: Int) {
        guard index >= 0 && index < files.count else { return }
        selectedIndex = index
        selectedFile = files[index]
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
}
