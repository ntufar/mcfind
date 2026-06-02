import XCTest
@testable import McFind

final class IndexDatabaseTests: XCTestCase {
    var db: IndexDatabase!
    var dbPath: String!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        dbPath = tempDir.appendingPathComponent("test-\(UUID().uuidString).db").path
        db = IndexDatabase(customPath: dbPath)
    }

    override func tearDown() {
        db = nil
        try? FileManager.default.removeItem(atPath: dbPath)
        let walPath = dbPath + "-wal"
        let shmPath = dbPath + "-shm"
        try? FileManager.default.removeItem(atPath: walPath)
        try? FileManager.default.removeItem(atPath: shmPath)
        super.tearDown()
    }

    func testEmptyDatabaseHasZeroFiles() {
        XCTAssertEqual(db.getFileCount(), 0)
    }

    func testInsertFileIncreasesCount() {
        let file = FileItem(path: "/test.txt", name: "test.txt", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file)
        XCTAssertEqual(db.getFileCount(), 1)
    }

    func testInsertFilesInBatch() {
        let files = (1...10).map { i in
            FileItem(path: "/file\(i).txt", name: "file\(i).txt", isDirectory: false, size: Int64(i * 100), dateModified: Date())
        }
        db.insertFiles(files)
        XCTAssertEqual(db.getFileCount(), 10)
    }

    func testSearchByExactName() {
        let file = FileItem(path: "/Documents/report.pdf", name: "report.pdf", isDirectory: false, size: 5000, dateModified: Date())
        db.insertFile(file)
        let results = db.search("report")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "report.pdf")
    }

    func testSearchIsCaseInsensitive() {
        let file = FileItem(path: "/Documents/Report.pdf", name: "Report.pdf", isDirectory: false, size: 5000, dateModified: Date())
        db.insertFile(file)
        let results = db.search("report")
        XCTAssertEqual(results.count, 1)
    }

    func testSearchByPartialName() {
        let file = FileItem(path: "/Documents/something_long.txt", name: "something_long.txt", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file)
        let results = db.search("thing")
        XCTAssertEqual(results.count, 1)
    }

    func testSearchByPath() {
        let file = FileItem(path: "/Users/test/Documents/work/file.txt", name: "file.txt", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file)
        let results = db.search("work")
        XCTAssertEqual(results.count, 1)
    }

    func testSearchEmptyQueryReturnsEmpty() {
        let file = FileItem(path: "/test.txt", name: "test.txt", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file)
        let results = db.search("")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchWithNoMatch() {
        let file = FileItem(path: "/test.txt", name: "test.txt", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file)
        let results = db.search("nonexistent")
        XCTAssertTrue(results.isEmpty)
    }

    func testDeleteFile() {
        let file = FileItem(path: "/test.txt", name: "test.txt", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file)
        XCTAssertEqual(db.getFileCount(), 1)
        db.deleteFile(atPath: "/test.txt")
        XCTAssertEqual(db.getFileCount(), 0)
    }

    func testDeleteFileWithChildren() {
        let dir = FileItem(path: "/Projects", name: "Projects", isDirectory: true, size: 0, dateModified: Date())
        let file = FileItem(path: "/Projects/main.swift", name: "main.swift", isDirectory: false, size: 200, dateModified: Date())
        db.insertFile(dir)
        db.insertFile(file)
        XCTAssertEqual(db.getFileCount(), 2)
        db.deleteFile(atPath: "/Projects")
        XCTAssertEqual(db.getFileCount(), 0)
    }

    func testClearDatabase() {
        let files = (1...5).map { i in
            FileItem(path: "/file\(i).txt", name: "file\(i).txt", isDirectory: false, size: 0, dateModified: Date())
        }
        db.insertFiles(files)
        XCTAssertEqual(db.getFileCount(), 5)
        db.clearDatabase()
        XCTAssertEqual(db.getFileCount(), 0)
    }

    func testGetAllFiles() {
        let files = [
            FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date()),
            FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date()),
        ]
        db.insertFiles(files)
        let all = db.getAllFiles()
        XCTAssertEqual(all.count, 2)
        let paths = Set(all.map { $0.path })
        XCTAssertTrue(paths.contains("/a.txt"))
        XCTAssertTrue(paths.contains("/b.txt"))
    }

    func testMetadataCRUD() {
        XCTAssertNil(db.getMetadata(key: "test_key"))
        db.setMetadata(key: "test_key", value: "test_value")
        XCTAssertEqual(db.getMetadata(key: "test_key"), "test_value")
        db.setMetadata(key: "test_key", value: "updated_value")
        XCTAssertEqual(db.getMetadata(key: "test_key"), "updated_value")
    }

    func testLastIndexedAt() {
        XCTAssertNil(db.getLastIndexedAt())
        let date = Date(timeIntervalSince1970: 1700000000)
        db.storeLastIndexedAt(date)
        let lastIndexed = db.getLastIndexedAt()
        XCTAssertNotNil(lastIndexed)
        XCTAssertEqual(lastIndexed!.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testCurrentGeneration() {
        XCTAssertEqual(db.getCurrentGeneration(), 0)
        db.storeCurrentGeneration(42)
        XCTAssertEqual(db.getCurrentGeneration(), 42)
    }

    func testDirMtime() {
        XCTAssertNil(db.getDirMtime("/Users/test"))
        db.setDirMtime("/Users/test", mtime: 1234567890.0)
        XCTAssertEqual(db.getDirMtime("/Users/test"), 1234567890.0)
    }

    func testUpdateGeneration() {
        let gen1: Int64 = 1
        let gen2: Int64 = 2

        let file1 = FileItem(path: "/Users/test/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date())
        let file2 = FileItem(path: "/Users/test/sub/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date())

        db.insertFile(file1, generation: gen1)
        db.insertFile(file2, generation: gen1)
        XCTAssertEqual(db.getFileCount(), 2)

        db.updateGeneration(path: "/Users/test", generation: gen2)
        db.storeCurrentGeneration(gen2)

        let deleted = db.deleteByGeneration(notEqual: gen2)
        XCTAssertEqual(deleted, 0) // Both files should have gen2 now
        XCTAssertEqual(db.getFileCount(), 2)
    }

    func testDeleteByGeneration() {
        let gen1: Int64 = 1
        let gen2: Int64 = 2

        let file1 = FileItem(path: "/Users/test/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date())
        let file2 = FileItem(path: "/Users/test/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date())

        db.insertFile(file1, generation: gen1)
        db.insertFile(file2, generation: gen2)

        let deleted = db.deleteByGeneration(notEqual: gen2)
        XCTAssertEqual(deleted, 1) // file1 should be deleted
        XCTAssertEqual(db.getFileCount(), 1)
        XCTAssertEqual(db.getAllFiles().first?.name, "b.txt")
    }

    func testSearchResultRanking() {
        let exact = FileItem(path: "/Documents/report.pdf", name: "report.pdf", isDirectory: false, size: 100, dateModified: Date())
        let prefix = FileItem(path: "/Documents/report_2024.pdf", name: "report_2024.pdf", isDirectory: false, size: 200, dateModified: Date())
        let partial = FileItem(path: "/Documents/annual_report.pdf", name: "annual_report.pdf", isDirectory: false, size: 300, dateModified: Date())

        db.insertFile(exact)
        db.insertFile(prefix)
        db.insertFile(partial)

        let results = db.search("report")
        XCTAssertGreaterThanOrEqual(results.count, 1)
        // Exact match should be first
        XCTAssertEqual(results.first?.name, "report.pdf")
    }

    func testInsertReplaceUpdatesFile() {
        let original = FileItem(path: "/test.txt", name: "test.txt", isDirectory: false, size: 100, dateModified: Date(timeIntervalSince1970: 1000))
        db.insertFile(original)
        let updated = FileItem(path: "/test.txt", name: "test.txt", isDirectory: false, size: 999, dateModified: Date(timeIntervalSince1970: 2000))
        db.insertFile(updated)

        XCTAssertEqual(db.getFileCount(), 1)
        let all = db.getAllFiles()
        XCTAssertEqual(all.first?.size, 999)
    }
}
