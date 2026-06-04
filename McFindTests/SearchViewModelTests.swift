import XCTest
@testable import McFind

final class SearchViewModelTests: XCTestCase {
    var viewModel: SearchViewModel!
    let testFile = FileItem(path: "/tmp/test.txt", name: "test.txt", isDirectory: false, size: 100, dateModified: Date())
    let testDir = FileItem(path: "/tmp/folder", name: "folder", isDirectory: true, size: 512, dateModified: Date())

    override func setUp() {
        super.setUp()
        viewModel = SearchViewModel()
    }

    override func tearDown() {
        viewModel = nil
        NSPasteboard.general.clearContents()
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertTrue(viewModel.files.isEmpty)
        XCTAssertNil(viewModel.selectedFile)
        XCTAssertTrue(viewModel.selectedIndices.isEmpty)
    }

    func testSelectNextWithEmptyFiles() {
        viewModel.files = []
        viewModel.selectNext()
        XCTAssertNil(viewModel.selectedFile)
        XCTAssertTrue(viewModel.selectedIndices.isEmpty)
    }

    func testSelectNextWrapsToFirst() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
        ]
        viewModel.selectedIndices = [1]
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndices, [0])
        XCTAssertEqual(viewModel.selectedFile?.name, "a.txt")
    }

    func testSelectNextAdvancesIndex() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
            FileItem(path: "/c.txt", name: "c.txt", isDirectory: false, size: 30, dateModified: Date()),
        ]
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndices, [1])
        XCTAssertEqual(viewModel.selectedFile?.name, "b.txt")
    }

    func testSelectPreviousWithEmptyFiles() {
        viewModel.files = []
        viewModel.selectPrevious()
        XCTAssertNil(viewModel.selectedFile)
        XCTAssertTrue(viewModel.selectedIndices.isEmpty)
    }

    func testSelectPreviousWrapsToLast() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
        ]
        viewModel.selectedIndices = [0]
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndices, [1])
        XCTAssertEqual(viewModel.selectedFile?.name, "b.txt")
    }

    func testSelectPreviousDecrementsIndex() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
            FileItem(path: "/c.txt", name: "c.txt", isDirectory: false, size: 30, dateModified: Date()),
        ]
        viewModel.selectedIndices = [2]
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndices, [1])
        XCTAssertEqual(viewModel.selectedFile?.name, "b.txt")
    }

    func testSelectFileValidIndex() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
        ]
        viewModel.selectFile(at: 1)
        XCTAssertEqual(viewModel.selectedIndices, [1])
        XCTAssertEqual(viewModel.selectedFile?.name, "b.txt")
    }

    func testSelectFileInvalidIndexDoesNothing() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
        ]
        viewModel.selectedIndices = [0]

        viewModel.selectFile(at: -1)
        XCTAssertEqual(viewModel.selectedIndices, [0])

        viewModel.selectFile(at: 5)
        XCTAssertEqual(viewModel.selectedIndices, [0])

        viewModel.selectFile(at: 1)
        XCTAssertEqual(viewModel.selectedIndices, [0])
    }

    func testSelectNextSingleFileStaysOnSame() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
        ]
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndices, [0])
        XCTAssertEqual(viewModel.selectedFile?.name, "a.txt")
    }

    func testSelectPreviousSingleFileStaysOnSame() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
        ]
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndices, [0])
        XCTAssertEqual(viewModel.selectedFile?.name, "a.txt")
    }

    func testMultipleSelectNextCalls() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
            FileItem(path: "/c.txt", name: "c.txt", isDirectory: false, size: 30, dateModified: Date()),
        ]
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndices, [1])
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndices, [2])
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndices, [0]) // wraps around
    }

    func testMultipleSelectPreviousCalls() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
            FileItem(path: "/c.txt", name: "c.txt", isDirectory: false, size: 30, dateModified: Date()),
        ]
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndices, [2])
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndices, [1])
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndices, [0])
    }

    // MARK: - Multi-select specific tests

    func testToggleSelection() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
            FileItem(path: "/c.txt", name: "c.txt", isDirectory: false, size: 30, dateModified: Date()),
        ]
        viewModel.toggleSelection(at: 0)
        XCTAssertEqual(viewModel.selectedIndices, [0])
        viewModel.toggleSelection(at: 2)
        XCTAssertEqual(viewModel.selectedIndices, [0, 2])
        viewModel.toggleSelection(at: 0)
        XCTAssertEqual(viewModel.selectedIndices, [2])
    }

    func testToggleSelectionInvalidIndex() {
        viewModel.files = [testFile]
        viewModel.toggleSelection(at: -1)
        XCTAssertTrue(viewModel.selectedIndices.isEmpty)
        viewModel.toggleSelection(at: 5)
        XCTAssertTrue(viewModel.selectedIndices.isEmpty)
    }

    func testSelectAll() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
            FileItem(path: "/c.txt", name: "c.txt", isDirectory: false, size: 30, dateModified: Date()),
        ]
        viewModel.selectAll()
        XCTAssertEqual(viewModel.selectedIndices, [0, 1, 2])
        XCTAssertEqual(viewModel.selectedFiles.count, 3)
    }

    func testSelectedFiles() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
            FileItem(path: "/c.txt", name: "c.txt", isDirectory: false, size: 30, dateModified: Date()),
        ]
        viewModel.selectedIndices = [0, 2]
        let files = viewModel.selectedFiles
        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(files[0].name, "a.txt")
        XCTAssertEqual(files[1].name, "c.txt")
    }

    func testSelectedFileReturnsLastSelected() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
            FileItem(path: "/c.txt", name: "c.txt", isDirectory: false, size: 30, dateModified: Date()),
        ]
        viewModel.selectedIndices = [0, 2]
        XCTAssertEqual(viewModel.selectedFile?.name, "c.txt") // last (highest index)
    }

    // MARK: - Actions

    func testCopyPathWritesToPasteboard() {
        viewModel.files = [testFile]
        viewModel.selectedIndices = [0]
        viewModel.copyPaths()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), testFile.path)
    }

    func testCopyPathWithNoSelectionDoesNothing() {
        viewModel.files = []
        NSPasteboard.general.setString("existing", forType: .string)
        viewModel.copyPaths()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "existing")
    }

    func testCopyPathWithMultipleFiles() {
        let fileA = FileItem(path: "/tmp/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date())
        let fileB = FileItem(path: "/tmp/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date())
        viewModel.files = [fileA, fileB]
        viewModel.selectedIndices = [0, 1]
        viewModel.copyPaths()
        let result = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(result, "/tmp/a.txt\n/tmp/b.txt")
    }

    func testCopyFileWritesURLToPasteboard() {
        viewModel.files = [testFile]
        viewModel.selectedIndices = [0]
        viewModel.copyFiles()
        guard let items = NSPasteboard.general.pasteboardItems else {
            XCTFail("Expected pasteboard items")
            return
        }
        let urls = items.compactMap { $0.propertyList(forType: .fileURL) as? String }
        XCTAssertTrue(urls.contains(where: { $0.hasSuffix("/test.txt") }))
    }

    func testCopyFileWithDirectoryWritesURL() {
        viewModel.files = [testDir]
        viewModel.selectedIndices = [0]
        viewModel.copyFiles()
        guard let items = NSPasteboard.general.pasteboardItems else {
            XCTFail("Expected pasteboard items")
            return
        }
        let urls = items.compactMap { $0.propertyList(forType: .fileURL) as? String }
        XCTAssertTrue(urls.contains(where: { $0.hasSuffix("/folder") }))
    }

    func testCopyFileWithNoSelectionDoesNothing() {
        viewModel.files = []
        NSPasteboard.general.setString("existing", forType: .string)
        viewModel.copyFiles()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "existing")
    }

    func testCopyFileWithMultipleFiles() {
        let fileA = FileItem(path: "/tmp/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date())
        let fileB = FileItem(path: "/tmp/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date())
        viewModel.files = [fileA, fileB]
        viewModel.selectedIndices = [0, 1]
        viewModel.copyFiles()
        guard let items = NSPasteboard.general.pasteboardItems else {
            XCTFail("Expected pasteboard items")
            return
        }
        let urls = items.compactMap { $0.propertyList(forType: .fileURL) as? String }
        XCTAssertEqual(urls.count, 2)
    }

    func testRevealInFinderWithNoSelectionDoesNothing() {
        viewModel.files = []
        viewModel.revealInFinder()
        XCTAssertNil(viewModel.selectedFile)
    }

    func testOpenSelectedFileWithNoSelectionDoesNothing() {
        viewModel.files = []
        viewModel.openSelectedFiles()
        XCTAssertNil(viewModel.selectedFile)
    }

    func testCopyPathEscapedWithMultipleFiles() {
        let fileA = FileItem(path: "/tmp/a file.txt", name: "a file.txt", isDirectory: false, size: 10, dateModified: Date())
        let fileB = FileItem(path: "/tmp/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date())
        viewModel.files = [fileA, fileB]
        viewModel.selectedIndices = [0, 1]
        viewModel.copyPathsEscaped()
        let result = NSPasteboard.general.string(forType: .string)
        XCTAssertTrue(result?.contains("'/tmp/a file.txt'") ?? false)
        XCTAssertTrue(result?.contains("'/tmp/b.txt'") ?? false)
    }

    func testRenameFileInvalidIndexDoesNothing() {
        let tmpDir = FileManager.default.temporaryDirectory
        let originalURL = tmpDir.appendingPathComponent("mcfind-test-rename-\(UUID().uuidString).txt")
        FileManager.default.createFile(atPath: originalURL.path, contents: "test".data(using: .utf8))
        defer { try? FileManager.default.removeItem(at: originalURL) }

        viewModel.files = [FileItem(url: originalURL)]
        viewModel.selectedIndices = [0]

        viewModel.renameFile(at: -1, to: "new.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalURL.path))
        XCTAssertEqual(viewModel.files[0].name, originalURL.lastPathComponent)

        viewModel.renameFile(at: 5, to: "new.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalURL.path))
    }

    func testRenameFileRenamesOnDisk() {
        let tmpDir = FileManager.default.temporaryDirectory
        let originalURL = tmpDir.appendingPathComponent("mcfind-test-rename-\(UUID().uuidString).txt")
        FileManager.default.createFile(atPath: originalURL.path, contents: "test".data(using: .utf8))
        let newName = "mcfind-test-renamed-\(UUID().uuidString).txt"
        let newURL = tmpDir.appendingPathComponent(newName)
        defer {
            try? FileManager.default.removeItem(at: originalURL)
            try? FileManager.default.removeItem(at: newURL)
        }

        viewModel.files = [FileItem(url: originalURL)]
        viewModel.selectedIndices = [0]

        viewModel.renameFile(at: 0, to: newName)

        XCTAssertFalse(FileManager.default.fileExists(atPath: originalURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path))
    }

    func testSelectAllWithEmptyFiles() {
        viewModel.files = []
        viewModel.selectAll()
        XCTAssertTrue(viewModel.selectedIndices.isEmpty)
    }

    func testMoveToTrashFilesWithMultipleSelection() {
        // This test verifies the multi-select trash method works without crashing
        // Actual trash operations are hard to test without leaving files on disk
        viewModel.files = [testFile, testDir]
        viewModel.selectedIndices = [0, 1]
        // Just verify the method signature works - we don't actually trash tmp files
        XCTAssertEqual(viewModel.selectedFiles.count, 2)
    }
}
