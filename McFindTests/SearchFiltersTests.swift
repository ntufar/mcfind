import XCTest
@testable import McFind

final class SearchFiltersTests: XCTestCase {

    // MARK: Query parsing

    func testPlainTextHasNoFilters() {
        let parsed = QueryParser.parse("annual report")
        XCTAssertEqual(parsed.text, "annual report")
        XCTAssertTrue(parsed.filters.isEmpty)
        XCTAssertTrue(parsed.tokens.isEmpty)
    }

    func testTokensAreRemovedFromText() {
        let parsed = QueryParser.parse("invoice size:>10mb kind:pdf modified:week")
        XCTAssertEqual(parsed.text, "invoice")
        XCTAssertEqual(parsed.filters.size, SizeRange(min: 10 * SizeRange.mb, max: nil))
        XCTAssertEqual(parsed.filters.extensions, ["pdf"])
        XCTAssertEqual(parsed.filters.modified, ModifiedFilter(days: 7))
        XCTAssertEqual(parsed.tokens[.size], "size:>10mb")
    }

    func testHalfTypedTokenStaysInText() {
        XCTAssertEqual(QueryParser.parse("size:").text, "size:")
        XCTAssertEqual(QueryParser.parse("size:>").text, "size:>")
        XCTAssertEqual(QueryParser.parse("modified:soon").text, "modified:soon")
        XCTAssertTrue(QueryParser.parse("size:>").filters.isEmpty)
    }

    func testFiltersWithoutText() {
        let parsed = QueryParser.parse("kind:images")
        XCTAssertEqual(parsed.text, "")
        XCTAssertEqual(parsed.filters.kind, .images)
    }

    func testRegexQueryIsNotTreatedAsToken() {
        XCTAssertEqual(QueryParser.parse("/foo:bar/").text, "/foo:bar/")
    }

    func testExtensionListRejectsUnsafeCharacters() {
        XCTAssertTrue(QueryParser.parse("ext:pdf'--").filters.isEmpty)
        XCTAssertEqual(QueryParser.parse("ext:PNG,.jpg").filters.extensions, ["png", "jpg"])
    }

    func testRemovingToken() {
        XCTAssertEqual(QueryParser.removing("size:>1mb", from: "report size:>1mb pdf"), "report pdf")
    }

    // MARK: Size

    func testSizeSyntax() {
        XCTAssertEqual(SizeRange.parse(">500kb"), SizeRange(min: 500 * SizeRange.kb, max: nil))
        XCTAssertEqual(SizeRange.parse("<2gb"), SizeRange(min: nil, max: 2 * SizeRange.gb))
        XCTAssertEqual(SizeRange.parse("1mb..50mb"), SizeRange(min: SizeRange.mb, max: 50 * SizeRange.mb))
        XCTAssertEqual(SizeRange.parse(">10"), SizeRange(min: 10 * SizeRange.mb, max: nil), "No unit means MB")
        XCTAssertNil(SizeRange.parse("10mb"))
        XCTAssertNil(SizeRange.parse("50mb..1mb"))
        XCTAssertNil(SizeRange.parse(">abc"))
    }

    func testSizeLabels() {
        XCTAssertEqual(SizeRange(min: nil, max: 100 * SizeRange.kb).label, "Under 100 KB")
        XCTAssertEqual(SizeRange(min: 100 * SizeRange.kb, max: SizeRange.mb).label, "100 KB to 1 MB")
        XCTAssertEqual(SizeRange(min: SizeRange.gb, max: nil).label, "Over 1 GB")
    }

    func testPresetsDoNotOverlap() {
        let presets = SizeRange.presets
        for (a, b) in zip(presets, presets.dropFirst()) {
            XCTAssertEqual(a.max, b.min)
        }
    }

    // MARK: Modified

    func testModifiedSyntaxAndLabels() {
        XCTAssertEqual(ModifiedFilter.parse("today"), ModifiedFilter(days: 0))
        XCTAssertEqual(ModifiedFilter.parse("3d")?.days, 3)
        XCTAssertEqual(ModifiedFilter.parse("2w")?.days, 14)
        XCTAssertEqual(ModifiedFilter.parse("week")?.label, "Past week")
        XCTAssertEqual(ModifiedFilter.parse("6m")?.label, "Past 6 months")
        XCTAssertNil(ModifiedFilter.parse("0d"))
        XCTAssertNil(ModifiedFilter.parse("x"))
    }

    // MARK: Search

    private func makeDatabase() -> (IndexDatabase, String) {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).db").path
        return (IndexDatabase(customPath: path), path)
    }

    func testFiltersNarrowDatabaseResults() {
        let (db, path) = makeDatabase()
        defer {
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.removeItem(atPath: path + "-wal")
            try? FileManager.default.removeItem(atPath: path + "-shm")
        }
        let now = Date()
        let old = Calendar.current.date(byAdding: .day, value: -90, to: now)!
        db.insertFile(FileItem(path: "/d/invoice-new.pdf", name: "invoice-new.pdf", isDirectory: false, size: 3 * SizeRange.mb, dateModified: now))
        db.insertFile(FileItem(path: "/d/invoice-old.pdf", name: "invoice-old.pdf", isDirectory: false, size: 3 * SizeRange.mb, dateModified: old))
        db.insertFile(FileItem(path: "/d/invoice-small.png", name: "invoice-small.png", isDirectory: false, size: 10 * SizeRange.kb, dateModified: now))
        db.insertFile(FileItem(path: "/d/invoices", name: "invoices", isDirectory: true, size: 4096, dateModified: now))

        let pdfs = db.search("invoice", filters: SearchFilters(extensions: ["pdf"]))
        XCTAssertEqual(Set(pdfs.map(\.name)), ["invoice-new.pdf", "invoice-old.pdf"])

        let recent = db.search("invoice", filters: SearchFilters(modified: ModifiedFilter(days: 7)))
        XCTAssertEqual(Set(recent.map(\.name)), ["invoice-new.pdf", "invoice-small.png", "invoices"])

        let big = db.search("invoice", filters: SearchFilters(size: SizeRange(min: SizeRange.mb, max: nil)))
        XCTAssertEqual(Set(big.map(\.name)), ["invoice-new.pdf", "invoice-old.pdf"], "Folders never match a size band")

        let folders = db.search("invoice", filters: SearchFilters(kind: .folders))
        XCTAssertEqual(folders.map(\.name), ["invoices"])

        let images = db.search("", filters: SearchFilters(kind: .images))
        XCTAssertEqual(images.map(\.name), ["invoice-small.png"], "Filters alone return results")

        XCTAssertTrue(db.search("").isEmpty, "No text and no filters returns nothing")
    }
}
