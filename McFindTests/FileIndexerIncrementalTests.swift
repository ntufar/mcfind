import XCTest
@testable import McFind

/// Incremental indexing must pick up changes made while the app was closed.
/// A directory's own mtime only moves when a direct child is added, removed
/// or renamed, so the scan must still descend into subtrees whose top
/// directory looks unchanged. Otherwise nested files stay missing.
final class FileIndexerIncrementalTests: XCTestCase {
    var home: URL!
    var db: IndexDatabase!
    var dbDir: URL!
    var indexer: FileIndexer!

    override func setUp() {
        super.setUp()
        let root = FileManager.default.temporaryDirectory
        home = root.appendingPathComponent("mcfind-home-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        // The scan stores paths with symlinks resolved, so test paths must match.
        if let canonical = try? home.resourceValues(forKeys: [.canonicalPathKey]).canonicalPath {
            home = URL(fileURLWithPath: canonical, isDirectory: true)
        }
        dbDir = root.appendingPathComponent("mcfind-db-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        db = IndexDatabase(customPath: dbDir.appendingPathComponent("test.db").path)
        indexer = FileIndexer(homeDirectory: home, database: db, enableMonitoring: false, autoStartIndexing: false)
    }

    override func tearDown() {
        indexer = nil
        db = nil
        try? FileManager.default.removeItem(at: home)
        try? FileManager.default.removeItem(at: dbDir)
        super.tearDown()
    }

    private func write(_ text: String, to url: URL) {
        try! text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func runIncremental() {
        let generation = db.getCurrentGeneration() + 1
        db.storeCurrentGeneration(generation)
        indexer.incrementalIndexDirectory(estimatedTotal: db.getFileCount(), generation: generation)
    }

    private func testFile(_ name: String, in dir: URL) -> URL {
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        write("seed", to: url)
        return url
    }

    func testFindsFileCreatedInNestedDirectory() {
        let sub = home.appendingPathComponent("parent/sub", isDirectory: true)
        _ = testFile("old.txt", in: sub)
        runIncremental()
        XCTAssertEqual(db.search("old.txt").count, 1)

        // Only sub/ moves here. parent/ keeps its mtime.
        write("blend", to: sub.appendingPathComponent("new.blend"))
        runIncremental()

        let results = db.search("*.blend")
        XCTAssertEqual(results.map(\.name), ["new.blend"])
        XCTAssertEqual(db.search("old.txt").count, 1)
    }

    func testFindsFileInNewNestedDirectoryUnderUnchangedParent() {
        let nested = home.appendingPathComponent("work/diagrams", isDirectory: true)
        _ = testFile("notes.txt", in: nested)
        runIncremental()
        XCTAssertEqual(db.search("notes.txt").count, 1)

        // New directory two levels down. Only diagrams/ moves, work/ does not.
        let fresh = nested.appendingPathComponent("fresh", isDirectory: true)
        _ = testFile("model.blend", in: fresh)
        runIncremental()

        XCTAssertEqual(db.search("*.blend").map(\.name), ["model.blend"])
    }

    func testDetectsEditedFileUnderUnchangedDirectory() {
        let sub = home.appendingPathComponent("docs", isDirectory: true)
        let url = testFile("report.txt", in: sub)
        runIncremental()
        XCTAssertEqual(db.search("report.txt").first?.size, 4)

        // Editing contents leaves the parent directory mtime alone.
        write("much longer contents", to: url)
        runIncremental()

        XCTAssertEqual(db.search("report.txt").first?.size, 20)
    }

    func testRemovesDeletedFile() {
        let sub = home.appendingPathComponent("docs", isDirectory: true)
        let url = testFile("gone.txt", in: sub)
        runIncremental()
        XCTAssertEqual(db.search("gone.txt").count, 1)

        try! FileManager.default.removeItem(at: url)
        // Scans minutes apart in real use. Space the mtime out so the
        // 1ms tolerance cannot mistake the deletion for no change.
        let stored = db.getDirMtime(sub.path) ?? 0
        try! FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: stored + 5)],
            ofItemAtPath: sub.path
        )
        runIncremental()

        XCTAssertTrue(db.search("gone.txt").isEmpty)
    }
}
