import XCTest
@testable import McFind

final class SearchViewModelTests: XCTestCase {
    var viewModel: SearchViewModel!

    override func setUp() {
        super.setUp()
        viewModel = SearchViewModel()
    }

    override func tearDown() {
        viewModel = nil
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
        viewModel.selectedFile = viewModel.files[1]
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
        viewModel.selectedFile = viewModel.files[0]
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
        viewModel.selectedFile = viewModel.files[2]
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
        viewModel.selectedFile = viewModel.files[0]

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
}
