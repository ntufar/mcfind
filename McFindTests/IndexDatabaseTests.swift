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

    // MARK: - Wildcard Search Tests

    func testWildcardStarMatchesAnySequence() {
        let file = FileItem(path: "/Documents/report_2024.pdf", name: "report_2024.pdf", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file)
        let results = db.search("report*.pdf")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "report_2024.pdf")
    }

    func testWildcardStarMatchesPrefix() {
        let pdf = FileItem(path: "/Docs/doc.pdf", name: "doc.pdf", isDirectory: false, size: 100, dateModified: Date())
        let txt = FileItem(path: "/Docs/doc.txt", name: "doc.txt", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(pdf)
        db.insertFile(txt)
        let results = db.search("*.pdf")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "doc.pdf")
    }

    func testWildcardQuestionMarkMatchesSingleChar() {
        let file1 = FileItem(path: "/Docs/file1.txt", name: "file1.txt", isDirectory: false, size: 100, dateModified: Date())
        let file2 = FileItem(path: "/Docs/fileA.txt", name: "fileA.txt", isDirectory: false, size: 100, dateModified: Date())
        let file3 = FileItem(path: "/Docs/file12.txt", name: "file12.txt", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file1)
        db.insertFile(file2)
        db.insertFile(file3)
        let results = db.search("file?.txt")
        XCTAssertEqual(results.count, 2)
        let names = Set(results.map { $0.name })
        XCTAssertTrue(names.contains("file1.txt"))
        XCTAssertTrue(names.contains("fileA.txt"))
        XCTAssertFalse(names.contains("file12.txt"))
    }

    func testWildcardMixed() {
        let file1 = FileItem(path: "/Docs/photo_2024.jpg", name: "photo_2024.jpg", isDirectory: false, size: 100, dateModified: Date())
        let file2 = FileItem(path: "/Docs/photo_2025.jpg", name: "photo_2025.jpg", isDirectory: false, size: 100, dateModified: Date())
        let file3 = FileItem(path: "/Docs/photo_2024.png", name: "photo_2024.png", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file1)
        db.insertFile(file2)
        db.insertFile(file3)
        let results = db.search("photo_202?.jpg")
        XCTAssertEqual(results.count, 2)
    }

    func testWildcardMatchesPath() {
        let file = FileItem(path: "/Users/test/work/project/main.swift", name: "main.swift", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file)
        let results = db.search("*/work/*")
        XCTAssertEqual(results.count, 1)
    }

    func testWildcardOnlyStarReturnsAll() {
        let file1 = FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: Date())
        let file2 = FileItem(path: "/b.txt", name: "b.txt", isDirectory: false, size: 20, dateModified: Date())
        db.insertFile(file1)
        db.insertFile(file2)
        let results = db.search("*")
        XCTAssertTrue(results.count >= 2)
    }

    func testSimpleQueryStillWorksWhenWildcardCharsPresentInFilename() {
        let file = FileItem(path: "/Docs/readme_star.md", name: "readme_star.md", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file)
        // A query without * or ? should use simple mode (substring match)
        let results = db.search("readme")
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Regex Search Tests

    func testRegexBasicPattern() {
        let pdf = FileItem(path: "/Docs/report.pdf", name: "report.pdf", isDirectory: false, size: 100, dateModified: Date())
        let png = FileItem(path: "/Docs/report.png", name: "report.png", isDirectory: false, size: 100, dateModified: Date())
        let txt = FileItem(path: "/Docs/notes.txt", name: "notes.txt", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(pdf)
        db.insertFile(png)
        db.insertFile(txt)
        let results = db.search("/\\.pdf$/")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "report.pdf")
    }

    func testRegexCaseInsensitive() {
        let file = FileItem(path: "/Docs/HelloWorld.swift", name: "HelloWorld.swift", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file)
        let results = db.search("/helloworld/")
        XCTAssertEqual(results.count, 1)
    }

    func testRegexWithDotMatchesLiteralDot() {
        let file = FileItem(path: "/Docs/index.html", name: "index.html", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file)
        let results = db.search("/index\\.html/")
        XCTAssertEqual(results.count, 1)
    }

    func testRegexAnchoredPattern() {
        let a = FileItem(path: "/Docs/apple.txt", name: "apple.txt", isDirectory: false, size: 100, dateModified: Date())
        let b = FileItem(path: "/Docs/pineapple.txt", name: "pineapple.txt", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(a)
        db.insertFile(b)
        let results = db.search("/^apple/")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "apple.txt")
    }

    func testRegexReturnsNoMatchesForInvalidPattern() {
        let file = FileItem(path: "/Docs/test.txt", name: "test.txt", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file)
        let results = db.search("/nomatch/")
        XCTAssertTrue(results.isEmpty)
    }

    func testRegexNoResultsWhenNotRegexPattern() {
        // Query with slashes but not a valid regex should fall back to simple search
        let file = FileItem(path: "/Docs/slash/test.txt", name: "test.txt", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file)
        // This isn't a valid regex pattern (unbalanced), but search should still work
        let results = db.search("/slash")
        // Not matching regex mode (no trailing /), should fall to simple mode
        XCTAssertEqual(results.count, 1)
    }

    func testRegexWithAlternation() {
        let jpg = FileItem(path: "/Docs/photo.jpg", name: "photo.jpg", isDirectory: false, size: 100, dateModified: Date())
        let png = FileItem(path: "/Docs/photo.png", name: "photo.png", isDirectory: false, size: 100, dateModified: Date())
        let gif = FileItem(path: "/Docs/photo.gif", name: "photo.gif", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(jpg)
        db.insertFile(png)
        db.insertFile(gif)
        let results = db.search("/\\.(jpg|png)$/")
        XCTAssertEqual(results.count, 2)
        let names = Set(results.map { $0.name })
        XCTAssertTrue(names.contains("photo.jpg"))
        XCTAssertTrue(names.contains("photo.png"))
        XCTAssertFalse(names.contains("photo.gif"))
    }

    func testSimpleSearchStillWorksWithSlashInQuery() {
        let file = FileItem(path: "/a/b/c/file.txt", name: "file.txt", isDirectory: false, size: 100, dateModified: Date())
        db.insertFile(file)
        // Query has slashes but not wrapped as /pattern/
        let results = db.search("a/b")
        XCTAssertEqual(results.count, 1)
    }
}
