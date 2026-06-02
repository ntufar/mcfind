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
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func testSelectNextWithEmptyFiles() {
        viewModel.files = []
        viewModel.selectNext()
        XCTAssertNil(viewModel.selectedFile)
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func testSelectNextWrapsToFirst() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
        ]
        viewModel.selectedIndex = 1
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 0)
        XCTAssertEqual(viewModel.selectedFile?.name, "a.txt")
    }

    func testSelectNextAdvancesIndex() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
            FileItem(path: "/c.txt", name: "c.txt", isDirectory: false, size: 30, dateModified: Date()),
        ]
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 1)
        XCTAssertEqual(viewModel.selectedFile?.name, "b.txt")
    }

    func testSelectPreviousWithEmptyFiles() {
        viewModel.files = []
        viewModel.selectPrevious()
        XCTAssertNil(viewModel.selectedFile)
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func testSelectPreviousWrapsToLast() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
        ]
        viewModel.selectedIndex = 0
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 1)
        XCTAssertEqual(viewModel.selectedFile?.name, "b.txt")
    }

    func testSelectPreviousDecrementsIndex() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
            FileItem(path: "/c.txt", name: "c.txt", isDirectory: false, size: 30, dateModified: Date()),
        ]
        viewModel.selectedIndex = 2
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 1)
        XCTAssertEqual(viewModel.selectedFile?.name, "b.txt")
    }

    func testSelectFileValidIndex() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
        ]
        viewModel.selectFile(at: 1)
        XCTAssertEqual(viewModel.selectedIndex, 1)
        XCTAssertEqual(viewModel.selectedFile?.name, "b.txt")
    }

    func testSelectFileInvalidIndexDoesNothing() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
        ]
        viewModel.selectedIndex = 0

        viewModel.selectFile(at: -1)
        XCTAssertEqual(viewModel.selectedIndex, 0)

        viewModel.selectFile(at: 5)
        XCTAssertEqual(viewModel.selectedIndex, 0)

        viewModel.selectFile(at: 1)
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func testSelectNextSingleFileStaysOnSame() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
        ]
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 0)
        XCTAssertEqual(viewModel.selectedFile?.name, "a.txt")
    }

    func testSelectPreviousSingleFileStaysOnSame() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
        ]
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 0)
        XCTAssertEqual(viewModel.selectedFile?.name, "a.txt")
    }

    func testMultipleSelectNextCalls() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
            FileItem(path: "/c.txt", name: "c.txt", isDirectory: false, size: 30, dateModified: Date()),
        ]
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 1)
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 2)
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 0) // wraps around
    }

    func testMultipleSelectPreviousCalls() {
        viewModel.files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
            FileItem(path: "/c.txt", name: "c.txt", isDirectory: false, size: 30, dateModified: Date()),
        ]
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 2)
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 1)
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func testCopyPathWritesToPasteboard() {
        viewModel.files = [testFile]
        viewModel.selectedIndex = 0
        viewModel.copyPath()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), testFile.path)
    }

    func testCopyPathWithNoSelectionDoesNothing() {
        viewModel.files = []
        NSPasteboard.general.setString("existing", forType: .string)
        viewModel.copyPath()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "existing")
    }

    func testCopyFileWritesURLToPasteboard() {
        viewModel.files = [testFile]
        viewModel.selectedIndex = 0
        viewModel.copyFile()
        guard let items = NSPasteboard.general.pasteboardItems else {
            XCTFail("Expected pasteboard items")
            return
        }
        let urls = items.compactMap { $0.propertyList(forType: .fileURL) as? String }
        XCTAssertTrue(urls.contains(where: { $0.hasSuffix("/test.txt") }))
    }

    func testCopyFileWithDirectoryWritesURL() {
        viewModel.files = [testDir]
        viewModel.selectedIndex = 0
        viewModel.copyFile()
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
        viewModel.copyFile()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "existing")
    }

    func testRevealInFinderWithNoSelectionDoesNothing() {
        viewModel.files = []
        viewModel.revealInFinder()
        XCTAssertNil(viewModel.selectedFile)
    }

    func testOpenSelectedFileWithNoSelectionDoesNothing() {
        viewModel.files = []
        viewModel.openSelectedFile()
        XCTAssertNil(viewModel.selectedFile)
    }
}
