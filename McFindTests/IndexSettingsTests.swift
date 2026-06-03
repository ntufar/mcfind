import XCTest
@testable import McFind

final class IndexSettingsTests: XCTestCase {
    var settings: IndexSettings!
    let homeDirectory = "/Users/testuser"

    override func setUp() {
        super.setUp()
        settings = IndexSettings()
        settings.resetToDefaults()
    }

    // MARK: - Defaults

    func testDefaultExcludedPaths() {
        XCTAssertTrue(settings.isExcluded("Library"))
        XCTAssertEqual(settings.excludedPaths, ["Library"])
    }

    func testResetToDefaults() {
        settings.excludedPaths = ["Library", "Downloads"]
        settings.resetToDefaults()
        XCTAssertEqual(settings.excludedPaths, ["Library"])
    }

    // MARK: - isExcluded

    func testIsExcludedReturnsTrueForExcludedPath() {
        settings.excludedPaths = ["Downloads"]
        XCTAssertTrue(settings.isExcluded("Downloads"))
    }

    func testIsExcludedReturnsFalseForNonExcludedPath() {
        settings.excludedPaths = ["Library"]
        XCTAssertFalse(settings.isExcluded("Documents"))
    }

    // MARK: - shouldIndexPath

    func testShouldIndexPathOutsideHome() {
        XCTAssertTrue(settings.shouldIndexPath("/System/Library", homeDirectory: homeDirectory))
    }

    func testShouldIndexPathNormalDocument() {
        let path = "\(homeDirectory)/Documents/work/file.txt"
        XCTAssertTrue(settings.shouldIndexPath(path, homeDirectory: homeDirectory))
    }

    func testShouldIndexPathExcludedTopLevel() {
        let path = "\(homeDirectory)/Library/Safari/Bookmarks.plist"
        XCTAssertFalse(settings.shouldIndexPath(path, homeDirectory: homeDirectory))
    }

    func testShouldIndexPathLibraryItself() {
        let path = "\(homeDirectory)/Library"
        XCTAssertFalse(settings.shouldIndexPath(path, homeDirectory: homeDirectory))
    }

    func testShouldIndexPathCloudStorageDespiteLibraryExcluded() {
        let path = "\(homeDirectory)/Library/CloudStorage/OneDrive/file.txt"
        XCTAssertTrue(settings.shouldIndexPath(path, homeDirectory: homeDirectory))
    }

    func testShouldIndexPathCloudStorageExact() {
        let path = "\(homeDirectory)/Library/CloudStorage"
        XCTAssertTrue(settings.shouldIndexPath(path, homeDirectory: homeDirectory))
    }

    func testShouldIndexPathMobileDocumentsDespiteLibraryExcluded() {
        let path = "\(homeDirectory)/Library/Mobile Documents/com~apple~CloudDocs/report.pdf"
        XCTAssertTrue(settings.shouldIndexPath(path, homeDirectory: homeDirectory))
    }

    func testShouldIndexPathWhenCloudStorageExplicitlyExcluded() {
        settings.excludedPaths = ["Library", "Library/CloudStorage"]
        let path = "\(homeDirectory)/Library/CloudStorage/OneDrive/file.txt"
        XCTAssertFalse(settings.shouldIndexPath(path, homeDirectory: homeDirectory))
    }

    func testShouldIndexPathDownloads() {
        let path = "\(homeDirectory)/Downloads/file.zip"
        XCTAssertTrue(settings.shouldIndexPath(path, homeDirectory: homeDirectory))
    }

    func testShouldIndexPathDownloadsAfterExclusion() {
        settings.excludedPaths = ["Library", "Downloads"]
        let path = "\(homeDirectory)/Downloads/file.zip"
        XCTAssertFalse(settings.shouldIndexPath(path, homeDirectory: homeDirectory))
    }

    func testShouldIndexPathUnrelatedPath() {
        let path = "/Applications/Xcode.app"
        XCTAssertTrue(settings.shouldIndexPath(path, homeDirectory: homeDirectory))
    }

    // MARK: - Predefined paths sort order

    func testPredefinedPathsSortOrder() {
        let library = IndexPath(path: "Library", displayName: "Library", isTopLevel: true, defaultEnabled: false)
        let cloudStorage = IndexPath(path: "Library/CloudStorage", displayName: "CloudStorage", isTopLevel: false, defaultEnabled: true)
        let mobileDocs = IndexPath(path: "Library/Mobile Documents", displayName: "Mobile Documents", isTopLevel: false, defaultEnabled: true)

        XCTAssertEqual(library.sortOrder, 999)
        XCTAssertEqual(cloudStorage.sortOrder, 1000 + "Library/CloudStorage".count)
        XCTAssertEqual(mobileDocs.sortOrder, 1000 + "Library/Mobile Documents".count)
    }

    // MARK: - Multiple top-level exclusions

    func testMultipleExclusions() {
        settings.excludedPaths = ["Library", "Downloads", "Desktop"]
        XCTAssertTrue(settings.isExcluded("Library"))
        XCTAssertTrue(settings.isExcluded("Downloads"))
        XCTAssertTrue(settings.isExcluded("Desktop"))
        XCTAssertFalse(settings.isExcluded("Documents"))
    }

    // MARK: - shouldSkipDescendants

    func testShouldSkipDescendantsOfExcludedTopLevelWithoutEnabledSubpaths() {
        settings.excludedPaths = ["Downloads"]
        let path = "\(homeDirectory)/Downloads"
        XCTAssertTrue(settings.shouldSkipDescendants(of: path, homeDirectory: homeDirectory))
    }

    func testShouldNotSkipDescendantsOfLibraryBecauseCloudStorageIsEnabled() {
        settings.excludedPaths = ["Library"]
        let path = "\(homeDirectory)/Library"
        XCTAssertFalse(settings.shouldSkipDescendants(of: path, homeDirectory: homeDirectory))
    }

    func testShouldSkipDescendantsOfLibraryWhenCloudStorageExplicitlyExcluded() {
        settings.excludedPaths = ["Library", "Library/CloudStorage"]
        let path = "\(homeDirectory)/Library"
        XCTAssertFalse(settings.shouldSkipDescendants(of: path, homeDirectory: homeDirectory))
    }

    func testShouldSkipDescendantsOfNonExcludedDirectory() {
        let path = "\(homeDirectory)/Documents"
        XCTAssertTrue(settings.shouldSkipDescendants(of: path, homeDirectory: homeDirectory))
    }

    func testShouldSkipDescendantsOfPathOutsideHome() {
        let path = "/Applications"
        XCTAssertTrue(settings.shouldSkipDescendants(of: path, homeDirectory: homeDirectory))
    }
}
