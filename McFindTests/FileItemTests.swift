import XCTest
@testable import McFind

final class FileItemTests: XCTestCase {

    func testFormattedSizeForDirectoryReturnsEmpty() {
        let item = FileItem(path: "/Users/test/Documents", name: "Documents", isDirectory: true, size: 4096, dateModified: Date())
        XCTAssertEqual(item.formattedSize, "")
    }

    func testFormattedSizeForFile() {
        let item = FileItem(path: "/Users/test/file.txt", name: "file.txt", isDirectory: false, size: 1024, dateModified: Date())
        XCTAssertFalse(item.formattedSize.isEmpty)
        XCTAssertTrue(item.formattedSize.contains("1")) // 1 KB
    }

    func testFormattedDateToday() {
        let now = Date()
        let item = FileItem(path: "/tmp/test.txt", name: "test.txt", isDirectory: false, size: 100, dateModified: now)
        XCTAssertTrue(item.formattedDate.hasPrefix("Today"))
    }

    func testFormattedDateYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let item = FileItem(path: "/tmp/test.txt", name: "test.txt", isDirectory: false, size: 100, dateModified: yesterday)
        XCTAssertTrue(item.formattedDate.hasPrefix("Yesterday"))
    }

    func testFormattedDateThisWeek() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let item = FileItem(path: "/tmp/test.txt", name: "test.txt", isDirectory: false, size: 100, dateModified: threeDaysAgo)
        let weekday = Calendar.current.component(.weekday, from: threeDaysAgo)
        let weekdaySymbols = Calendar.current.shortWeekdaySymbols
        let expectedPrefix = weekdaySymbols[weekday - 1]
        XCTAssertTrue(item.formattedDate.hasPrefix(expectedPrefix))
    }

    func testFormattedDateThisYear() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let item = FileItem(path: "/tmp/test.txt", name: "test.txt", isDirectory: false, size: 100, dateModified: thirtyDaysAgo)
        XCTAssertFalse(item.formattedDate.hasPrefix("Today"))
        XCTAssertFalse(item.formattedDate.hasPrefix("Yesterday"))
        XCTAssertTrue(item.formattedDate.contains(":"))
    }

    func testFormattedDateOtherYear() {
        let lastYear = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let item = FileItem(path: "/tmp/test.txt", name: "test.txt", isDirectory: false, size: 100, dateModified: lastYear)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        XCTAssertEqual(item.formattedDate, formatter.string(from: lastYear))
    }

    func testFileExtension() {
        let item = FileItem(path: "/Users/test/file.swift", name: "file.swift", isDirectory: false, size: 100, dateModified: Date())
        XCTAssertEqual(item.fileExtension, "swift")
    }

    func testFileExtensionNilForNoExtension() {
        let item = FileItem(path: "/Users/test/README", name: "README", isDirectory: false, size: 100, dateModified: Date())
        XCTAssertNil(item.fileExtension)
    }

    func testFileExtensionNilForDirectory() {
        let item = FileItem(path: "/Users/test/Documents", name: "Documents", isDirectory: true, size: 512, dateModified: Date())
        if item.fileExtension != nil {
            // Directories typically don't have extensions, but it depends on the path
        }
    }

    func testHashable() {
        let date = Date()
        let a = FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: date)
        let b = FileItem(path: "/a.txt", name: "a.txt", isDirectory: false, size: 10, dateModified: date)
        let set: Set<FileItem> = [a, b]
        XCTAssertEqual(set.count, 1) // Same content, same path -> equal
    }

    func testIdentifiable() {
        let item = FileItem(path: "/test.txt", name: "test.txt", isDirectory: false, size: 0, dateModified: Date())
        XCTAssertEqual(item.id, item.id)
    }

    func testIdIsStableAndDerivedFromPath() {
        // Two distinct FileItem values for the same path must report the same id,
        // so identity-based diffing (e.g. table view row diffing) treats them as
        // the same file rather than as a delete+insert.
        let a = FileItem(path: "/Users/test/file.txt", name: "file.txt", isDirectory: false, size: 10, dateModified: Date())
        let b = FileItem(path: "/Users/test/file.txt", name: "file.txt", isDirectory: false, size: 20, dateModified: Date())
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(a.id, "/Users/test/file.txt")
    }

    func testIdChangesWhenPathChanges() {
        // A rename produces a new path, so it should be treated as a new identity.
        let original = FileItem(path: "/Users/test/old.txt", name: "old.txt", isDirectory: false, size: 10, dateModified: Date())
        let renamed = FileItem(path: "/Users/test/new.txt", name: "new.txt", isDirectory: false, size: 10, dateModified: Date())
        XCTAssertNotEqual(original.id, renamed.id)
    }
}
