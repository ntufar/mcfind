import Foundation
import Combine
import AppKit

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedFile: FileItem?
    @Published var selectedIndex = 0
    
    private let fileIndexer = FileIndexer()
    private var cancellables = Set<AnyCancellable>()
    
    var files: [FileItem] {
        return fileIndexer.files
    }
    
    var isIndexing: Bool {
        return fileIndexer.isIndexing
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
        startIndexing()
    }
    
    private func setupSearchBinding() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.fileIndexer.search(query)
            }
            .store(in: &cancellables)
    }
    
    func startIndexing() {
        fileIndexer.startIndexing()
    }
    
    func selectNext() {
        guard !files.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, files.count - 1)
        selectedFile = files[selectedIndex]
    }
    
    func selectPrevious() {
        guard !files.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
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
}
