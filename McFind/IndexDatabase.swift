import Foundation
import SQLite3

class IndexDatabase {
    private var db: OpaquePointer?
    let dbPath: String  // Made public so FileIndexer can check if file exists
    private let dbQueue = DispatchQueue(label: "com.mcfind.database", qos: .userInitiated)

    init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("McFind", isDirectory: true)

        try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)

        dbPath = appFolder.appendingPathComponent("index.db").path
        print("📁 Database path: \(dbPath)")

        openDatabase()
        createTableIfNeeded()
        migrateSchemaIfNeeded()
        dbQueue.async { [weak self] in
            self?.vacuumIfNeeded()
        }
    }

    init(customPath: String) {
        dbPath = customPath
        let parentDir = (customPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
        print("📁 Database path: \(dbPath)")

        openDatabase()
        createTableIfNeeded()
        migrateSchemaIfNeeded()
        dbQueue.async { [weak self] in
            self?.vacuumIfNeeded()
        }
    }

    deinit {
        closeDatabase()
    }

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ Error opening database")
        }
    }

    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    private func createTableIfNeeded() {
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS files (
            path TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            is_directory INTEGER NOT NULL,
            size INTEGER NOT NULL,
            modified_date REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_name ON files(name COLLATE NOCASE);
        CREATE INDEX IF NOT EXISTS idx_path ON files(path COLLATE NOCASE);

        CREATE TABLE IF NOT EXISTS metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS dir_mtime (
            path TEXT PRIMARY KEY,
            mtime REAL NOT NULL
        );
        """

        var error: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, createTableQuery, nil, nil, &error) != SQLITE_OK {
            let errorMessage = String(cString: error!)
            print("❌ Error creating table: \(errorMessage)")
            sqlite3_free(error)
        }
    }

    private func vacuumIfNeeded() {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA freelist_count;", -1, &stmt, nil) == SQLITE_OK else { return }
        guard sqlite3_step(stmt) == SQLITE_ROW else { sqlite3_finalize(stmt); return }
        let freePages = sqlite3_column_int64(stmt, 0)
        sqlite3_finalize(stmt)
        guard freePages > 10000 else { return }

        guard sqlite3_prepare_v2(db, "PRAGMA page_count;", -1, &stmt, nil) == SQLITE_OK else { return }
        guard sqlite3_step(stmt) == SQLITE_ROW else { sqlite3_finalize(stmt); return }
        let totalPages = sqlite3_column_int64(stmt, 0)
        sqlite3_finalize(stmt)
        guard totalPages > 0 else { return }

        let freeRatio = Double(freePages) / Double(totalPages)
        guard freeRatio > 0.1 else { return }

        print("🧹 VACUUM: \(freePages) free pages (\(Int(freeRatio * 100))% of \(totalPages)) — running VACUUM")
        sqlite3_exec(db, "VACUUM;", nil, nil, nil)
        print("✅ VACUUM complete")
    }

    private func columnExists(in table: String, name: String) -> Bool {
        let query = "PRAGMA table_info(\(table));"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 1) {
                if String(cString: cString) == name {
                    return true
                }
            }
        }
        return false
    }

    private func migrateSchemaIfNeeded() {
        let hasNameNorm = columnExists(in: "files", name: "name_normalized")
        let hasPathNorm = columnExists(in: "files", name: "path_normalized")
        let hasGeneration = columnExists(in: "files", name: "generation")

        if !hasNameNorm {
            sqlite3_exec(db, "ALTER TABLE files ADD COLUMN name_normalized TEXT NOT NULL DEFAULT '';", nil, nil, nil)
        }
        if !hasPathNorm {
            sqlite3_exec(db, "ALTER TABLE files ADD COLUMN path_normalized TEXT NOT NULL DEFAULT '';", nil, nil, nil)
        }
        if !hasGeneration {
            sqlite3_exec(db, "ALTER TABLE files ADD COLUMN generation INTEGER NOT NULL DEFAULT 0;", nil, nil, nil)
        }

        // Migrate existing rows: Swift lowercased() handles Unicode properly
        var statement: OpaquePointer?
        let selectQuery = "SELECT rowid, path, name FROM files WHERE name_normalized = '' AND name != '';"
        guard sqlite3_prepare_v2(db, selectQuery, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }

        typealias RowMigration = (rowid: Int64, normPath: String, normName: String)
        var migrations: [RowMigration] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let rowid = sqlite3_column_int64(statement, 0)
            let path = String(cString: sqlite3_column_text(statement, 1)!)
            let name = String(cString: sqlite3_column_text(statement, 2)!)
            migrations.append((rowid, path.lowercased(), name.lowercased()))
        }
        guard !migrations.isEmpty else { return }

        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        let updateSQL = "UPDATE files SET name_normalized = ?, path_normalized = ? WHERE rowid = ?;"
        var updateStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSQL, -1, &updateStmt, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for m in migrations {
            sqlite3_bind_int64(updateStmt, 3, m.rowid)
            m.normName.withCString { sqlite3_bind_text(updateStmt, 1, $0, -1, SQLITE_TRANSIENT) }
            m.normPath.withCString { sqlite3_bind_text(updateStmt, 2, $0, -1, SQLITE_TRANSIENT) }
            sqlite3_step(updateStmt)
            sqlite3_reset(updateStmt)
        }
        sqlite3_finalize(updateStmt)
        sqlite3_exec(db, "COMMIT", nil, nil, nil)

        print("✅ Migrated \(migrations.count) rows with Unicode-aware lowercased values")

        // Indexes for fast search on normalized columns
        sqlite3_exec(db, "CREATE INDEX IF NOT EXISTS idx_name_norm ON files(name_normalized);", nil, nil, nil)
        sqlite3_exec(db, "CREATE INDEX IF NOT EXISTS idx_path_norm ON files(path_normalized);", nil, nil, nil)
    }

    func insertFile(_ file: FileItem, generation: Int64 = 0) {
        dbQueue.sync {
            let insertQuery = """
            INSERT OR REPLACE INTO files (path, name, is_directory, size, modified_date, name_normalized, path_normalized, generation)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK else {
                print("❌ Error preparing insert statement")
                return
            }

            guard let stmt = statement else {
                print("❌ Statement is nil")
                return
            }

            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

            file.path.withCString { cString in
                _ = sqlite3_bind_text(stmt, 1, cString, -1, SQLITE_TRANSIENT)
            }
            file.name.withCString { cString in
                _ = sqlite3_bind_text(stmt, 2, cString, -1, SQLITE_TRANSIENT)
            }
            sqlite3_bind_int(stmt, 3, file.isDirectory ? 1 : 0)
            sqlite3_bind_int64(stmt, 4, file.size)
            sqlite3_bind_double(stmt, 5, file.dateModified.timeIntervalSince1970)
            file.name.lowercased().withCString { cString in
                _ = sqlite3_bind_text(stmt, 6, cString, -1, SQLITE_TRANSIENT)
            }
            file.path.lowercased().withCString { cString in
                _ = sqlite3_bind_text(stmt, 7, cString, -1, SQLITE_TRANSIENT)
            }
            sqlite3_bind_int64(stmt, 8, generation)

            if sqlite3_step(stmt) != SQLITE_DONE {
                print("❌ Error inserting file: \(file.path)")
            }

            sqlite3_finalize(stmt)
        }
    }

    func insertFiles(_ files: [FileItem], generation: Int64 = 0) {
        dbQueue.sync {
            sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)

            for file in files {
                insertFileInternal(file, generation: generation)
            }

            sqlite3_exec(db, "COMMIT", nil, nil, nil)
        }
    }

    private func insertFileInternal(_ file: FileItem, generation: Int64 = 0) {
        let insertQuery = """
        INSERT OR REPLACE INTO files (path, name, is_directory, size, modified_date, name_normalized, path_normalized, generation)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing insert statement")
            return
        }

        guard let stmt = statement else {
            print("❌ Statement is nil")
            return
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        file.path.withCString { cString in
            _ = sqlite3_bind_text(stmt, 1, cString, -1, SQLITE_TRANSIENT)
        }
        file.name.withCString { cString in
            _ = sqlite3_bind_text(stmt, 2, cString, -1, SQLITE_TRANSIENT)
        }
        sqlite3_bind_int(stmt, 3, file.isDirectory ? 1 : 0)
        sqlite3_bind_int64(stmt, 4, file.size)
        sqlite3_bind_double(stmt, 5, file.dateModified.timeIntervalSince1970)
        file.name.lowercased().withCString { cString in
            _ = sqlite3_bind_text(stmt, 6, cString, -1, SQLITE_TRANSIENT)
        }
        file.path.lowercased().withCString { cString in
            _ = sqlite3_bind_text(stmt, 7, cString, -1, SQLITE_TRANSIENT)
        }
        sqlite3_bind_int64(stmt, 8, generation)

        if sqlite3_step(stmt) != SQLITE_DONE {
            print("❌ Error inserting file: \(file.path)")
        }

        sqlite3_finalize(stmt)
    }

    func deleteFile(atPath path: String) {
        dbQueue.sync {
            let deleteQuery = "DELETE FROM files WHERE path = ? OR path LIKE ?;"

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK else {
                print("❌ Error preparing delete statement")
                return
            }

            guard let stmt = statement else {
                print("❌ Statement is nil")
                return
            }

            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

            path.withCString { cString in
                _ = sqlite3_bind_text(stmt, 1, cString, -1, SQLITE_TRANSIENT)
            }

            // Also delete all files under this path (if it's a directory)
            let pathPattern = path.hasSuffix("/") ? path + "%" : path + "/%"
            pathPattern.withCString { cString in
                _ = sqlite3_bind_text(stmt, 2, cString, -1, SQLITE_TRANSIENT)
            }

            _ = sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }

    func getAllFiles() -> [FileItem] {
        return dbQueue.sync {
            var files: [FileItem] = []
            let query = "SELECT path, name, is_directory, size, modified_date FROM files;"

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                print("❌ Error preparing select statement")
                return files
            }

            guard let stmt = statement else {
                print("❌ Statement is nil")
                return files
            }

            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let pathPtr = sqlite3_column_text(stmt, 0),
                      let namePtr = sqlite3_column_text(stmt, 1) else {
                    print("⚠️ Skipping row with NULL path or name")
                    continue
                }

                let path = String(cString: pathPtr)
                let name = String(cString: namePtr)
                let isDirectory = sqlite3_column_int(stmt, 2) != 0
                let size = sqlite3_column_int64(stmt, 3)
                let modifiedDate = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))

                files.append(FileItem(
                    path: path,
                    name: name,
                    isDirectory: isDirectory,
                    size: size,
                    dateModified: modifiedDate
                ))
            }

            sqlite3_finalize(stmt)
            return files
        }
    }

    private enum SearchMode {
        case simple(normalizedQuery: String, pattern: String, prefixPattern: String, pathPattern: String)
        case wildcard(likePattern: String)
        case regex(sqlFilter: String, regex: NSRegularExpression)
    }

    func search(_ query: String, filterDotFiles: Bool = false, sizeFilter: SizeFilter = .any) -> [FileItem] {
        print("🔍 IndexDatabase.search() called with: '\(query)' (filterDotFiles: \(filterDotFiles) sizeFilter: \(sizeFilter.displayName))")
        guard !query.isEmpty else {
            print("⚠️ Empty query, returning []")
            return []
        }

        print("⏳ Waiting for database queue...")
        let startTime = Date()
        let results = dbQueue.sync {
            print("🔓 Database queue acquired")
            return searchInternal(query, filterDotFiles: filterDotFiles, sizeFilter: sizeFilter)
        }
        let elapsed = Date().timeIntervalSince(startTime)
        print("✅ Search completed in \(String(format: "%.3f", elapsed))s - found \(results.count) results")
        return results
    }

    private func parseSearchMode(_ query: String) -> SearchMode {
        let normalizedQuery = query.lowercased()

        // Regex mode: /pattern/
        if normalizedQuery.hasPrefix("/") && normalizedQuery.hasSuffix("/") && normalizedQuery.count > 2 {
            let regexPattern = String(normalizedQuery.dropFirst().dropLast())
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: [.caseInsensitive]) {
                let sqlFilter = extractLiteralForSQL(from: regexPattern)
                return .regex(sqlFilter: sqlFilter, regex: regex)
            }
        }

        // Wildcard mode: contains * or ?
        if normalizedQuery.contains("*") || normalizedQuery.contains("?") {
            var likePattern = normalizedQuery
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "%", with: "\\%")
                .replacingOccurrences(of: "_", with: "\\_")
                .replacingOccurrences(of: "*", with: "%")
                .replacingOccurrences(of: "?", with: "_")
            return .wildcard(likePattern: likePattern)
        }

        // Simple mode: existing substring behavior
        let pattern = "%\(normalizedQuery)%"
        let prefixPattern = "\(normalizedQuery)%"
        let pathPattern = "%/\(normalizedQuery)%"
        return .simple(normalizedQuery: normalizedQuery, pattern: pattern, prefixPattern: prefixPattern, pathPattern: pathPattern)
    }

    private func containsAlternation(_ pattern: String) -> Bool {
        var depth = 0
        for char in pattern {
            if char == "(" { depth += 1 }
            else if char == ")" { depth -= 1 }
            else if char == "|", depth > 0 { return true }
        }
        return false
    }

    /// Build a LIKE pre-filter string from a regex pattern.
    /// Extracts the longest literal segment from the pattern.
    /// Returns empty string if no usable literal found (caller falls back to `%`).
    private func extractLiteralForSQL(from regexPattern: String) -> String {
        // If the pattern contains alternation (|), fall back to broad search
        guard !containsAlternation(regexPattern) else { return "" }

        var best = ""
        var current = ""
        let special = CharacterSet(charactersIn: ".^$+?{}[]|()\\*")
        for char in regexPattern {
            if char.isLetter || char.isNumber || char == " " || char == "-" || char == "_" {
                current.append(char)
            } else if char == "." || char == "*" || char == "+" || char == "?" {
                // Regex metacharacters — break the literal segment
                if current.count > best.count { best = current }
                current = ""
            } else {
                if current.count > best.count { best = current }
                current = ""
            }
        }
        if current.count > best.count { best = current }
        // Require at least 2 characters for a useful filter
        return best.count >= 2 ? best : ""
    }

    private func searchInternal(_ query: String, filterDotFiles: Bool = false, sizeFilter: SizeFilter = .any) -> [FileItem] {
        print("  📊 searchInternal() starting... (filterDotFiles: \(filterDotFiles), sizeFilter: \(sizeFilter.displayName))")

        let mode = parseSearchMode(query)
        var clauses: [String] = []
        if filterDotFiles { clauses.append("path_normalized NOT LIKE '%/.%'") }
        if !sizeFilter.sqlClause.isEmpty {
            let sizeClause = String(sizeFilter.sqlClause.dropFirst(4))
            clauses.append(sizeClause)
        }
        let filterClause = clauses.isEmpty ? "" : "AND " + clauses.joined(separator: " AND ")

        switch mode {
        case .simple(let normalizedQuery, let pattern, let prefixPattern, let pathPattern):
            return searchSimple(normalizedQuery: normalizedQuery, pattern: pattern, prefixPattern: prefixPattern, pathPattern: pathPattern, filterClause: filterClause)
        case .wildcard(let likePattern):
            return searchWildcard(likePattern: likePattern, filterClause: filterClause)
        case .regex(let sqlFilter, let regex):
            return searchRegex(sqlFilter: sqlFilter, regex: regex, filterClause: filterClause)
        }
    }

    private func searchSimple(normalizedQuery: String, pattern: String, prefixPattern: String, pathPattern: String, filterClause: String = "") -> [FileItem] {
        var files: [FileItem] = []

        let searchQuery = """
        SELECT path, name, is_directory, size, modified_date FROM files
        WHERE (name_normalized LIKE ? OR path_normalized LIKE ?) \(filterClause)
        ORDER BY
            CASE
                WHEN name_normalized = ? THEN 1
                WHEN name_normalized LIKE ? THEN 2
                WHEN name_normalized LIKE ? THEN 3
                WHEN path_normalized LIKE ? THEN 4
                ELSE 5
            END,
            name_normalized COLLATE NOCASE
        LIMIT 1000;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, searchQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing search statement")
            return files
        }

        guard let stmt = statement else {
            print("❌ Statement is nil")
            return files
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        pattern.withCString { cString in
            _ = sqlite3_bind_text(stmt, 1, cString, -1, SQLITE_TRANSIENT)
        }
        pattern.withCString { cString in
            _ = sqlite3_bind_text(stmt, 2, cString, -1, SQLITE_TRANSIENT)
        }
        normalizedQuery.withCString { cString in
            _ = sqlite3_bind_text(stmt, 3, cString, -1, SQLITE_TRANSIENT)
        }
        prefixPattern.withCString { cString in
            _ = sqlite3_bind_text(stmt, 4, cString, -1, SQLITE_TRANSIENT)
        }
        pattern.withCString { cString in
            _ = sqlite3_bind_text(stmt, 5, cString, -1, SQLITE_TRANSIENT)
        }
        pathPattern.withCString { cString in
            _ = sqlite3_bind_text(stmt, 6, cString, -1, SQLITE_TRANSIENT)
        }

        files = readSearchResults(stmt)
        sqlite3_finalize(stmt)
        print("  ✅ searchSimple() found \(files.count) files")
        return files
    }

    private func searchWildcard(likePattern: String, filterClause: String = "") -> [FileItem] {
        var files: [FileItem] = []

        let searchQuery = """
        SELECT path, name, is_directory, size, modified_date FROM files
        WHERE (name_normalized LIKE ? ESCAPE '\\'
           OR path_normalized LIKE ? ESCAPE '\\') \(filterClause)
        ORDER BY name_normalized COLLATE NOCASE
        LIMIT 1000;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, searchQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing wildcard search statement")
            return files
        }

        guard let stmt = statement else {
            print("❌ Statement is nil")
            return files
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        likePattern.withCString { cString in
            _ = sqlite3_bind_text(stmt, 1, cString, -1, SQLITE_TRANSIENT)
        }
        likePattern.withCString { cString in
            _ = sqlite3_bind_text(stmt, 2, cString, -1, SQLITE_TRANSIENT)
        }

        files = readSearchResults(stmt)
        sqlite3_finalize(stmt)
        print("  ✅ searchWildcard() found \(files.count) files")
        return files
    }

    private func searchRegex(sqlFilter: String, regex: NSRegularExpression, filterClause: String = "") -> [FileItem] {
        var candidates: [FileItem] = []

        let filterPattern = sqlFilter.isEmpty ? "%" : "%\(sqlFilter.lowercased())%"

        let searchQuery = """
        SELECT path, name, is_directory, size, modified_date FROM files
        WHERE (name_normalized LIKE ?
           OR path_normalized LIKE ?) \(filterClause)
        ORDER BY name_normalized COLLATE NOCASE
        LIMIT 5000;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, searchQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing regex search statement")
            return []
        }

        guard let stmt = statement else {
            print("❌ Statement is nil")
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        filterPattern.withCString { cString in
            _ = sqlite3_bind_text(stmt, 1, cString, -1, SQLITE_TRANSIENT)
        }
        filterPattern.withCString { cString in
            _ = sqlite3_bind_text(stmt, 2, cString, -1, SQLITE_TRANSIENT)
        }

        candidates = readSearchResults(stmt)
        sqlite3_finalize(stmt)

        let files = candidates.filter { item in
            let range = NSRange(location: 0, length: (item.name as NSString).length)
            return regex.firstMatch(in: item.name, options: [], range: range) != nil
        }

        print("  ✅ searchRegex() found \(files.count) files (from \(candidates.count) candidates)")
        return Array(files.prefix(1000))
    }

    private func readSearchResults(_ stmt: OpaquePointer?) -> [FileItem] {
        guard let stmt = stmt else { return [] }
        var files: [FileItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let pathPtr = sqlite3_column_text(stmt, 0),
                  let namePtr = sqlite3_column_text(stmt, 1) else {
                print("⚠️ Skipping row with NULL path or name")
                continue
            }

            let path = String(cString: pathPtr)
            let name = String(cString: namePtr)
            let isDirectory = sqlite3_column_int(stmt, 2) != 0
            let size = sqlite3_column_int64(stmt, 3)
            let modifiedDate = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))

            files.append(FileItem(
                path: path,
                name: name,
                isDirectory: isDirectory,
                size: size,
                dateModified: modifiedDate
            ))
        }
        return files
    }

    func getFileCount() -> Int {
        return dbQueue.sync {
            let query = "SELECT COUNT(*) FROM files;"
            var count = 0

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                print("❌ Error preparing count statement")
                return 0
            }

            guard let stmt = statement else {
                print("❌ Statement is nil")
                return 0
            }

            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }

            sqlite3_finalize(stmt)
            return count
        }
    }

    func clearDatabase() {
        dbQueue.sync {
            sqlite3_exec(db, "DELETE FROM files;", nil, nil, nil)
            sqlite3_exec(db, "DELETE FROM metadata;", nil, nil, nil)
            sqlite3_exec(db, "DELETE FROM dir_mtime;", nil, nil, nil)
            sqlite3_exec(db, "VACUUM;", nil, nil, nil)
        }
    }

    // MARK: - Incremental Indexing

    func setMetadata(key: String, value: String) {
        dbQueue.sync {
            let query = "INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?);"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK, let s = stmt else { return }
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            key.withCString { sqlite3_bind_text(s, 1, $0, -1, SQLITE_TRANSIENT) }
            value.withCString { sqlite3_bind_text(s, 2, $0, -1, SQLITE_TRANSIENT) }
            sqlite3_step(s)
            sqlite3_finalize(s)
        }
    }

    func getMetadata(key: String) -> String? {
        dbQueue.sync {
            let query = "SELECT value FROM metadata WHERE key = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK, let s = stmt else { return nil }
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            key.withCString { sqlite3_bind_text(s, 1, $0, -1, SQLITE_TRANSIENT) }
            var result: String?
            if sqlite3_step(s) == SQLITE_ROW, let ptr = sqlite3_column_text(s, 0) {
                result = String(cString: ptr)
            }
            sqlite3_finalize(s)
            return result
        }
    }

    func storeLastIndexedAt(_ date: Date) {
        setMetadata(key: "last_indexed_at", value: "\(date.timeIntervalSince1970)")
    }

    func getLastIndexedAt() -> Date? {
        guard let val = getMetadata(key: "last_indexed_at") else { return nil }
        guard let interval = TimeInterval(val) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    func storeCurrentGeneration(_ gen: Int64) {
        setMetadata(key: "generation", value: "\(gen)")
    }

    func getCurrentGeneration() -> Int64 {
        guard let val = getMetadata(key: "generation") else { return 0 }
        return Int64(val) ?? 0
    }

    func deleteByGeneration(notEqual gen: Int64) -> Int {
        dbQueue.sync {
            let query = "DELETE FROM files WHERE generation != ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK, let s = stmt else { return 0 }
            sqlite3_bind_int64(s, 1, gen)
            sqlite3_step(s)
            let changes = Int(sqlite3_changes(db))
            sqlite3_finalize(s)
            return changes
        }
    }

    func removeDotFiles() {
        dbQueue.sync {
            let query = "DELETE FROM files WHERE path_normalized LIKE '%/.%';"
            sqlite3_exec(db, query, nil, nil, nil)
        }
    }

    // MARK: - Directory mtime tracking

    func getDirMtime(_ path: String) -> Double? {
        dbQueue.sync {
            let query = "SELECT mtime FROM dir_mtime WHERE path = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK, let s = stmt else { return nil }
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            path.withCString { sqlite3_bind_text(s, 1, $0, -1, SQLITE_TRANSIENT) }
            var result: Double?
            if sqlite3_step(s) == SQLITE_ROW {
                result = sqlite3_column_double(s, 0)
            }
            sqlite3_finalize(s)
            return result
        }
    }

    func setDirMtime(_ path: String, mtime: Double) {
        dbQueue.sync {
            let query = "INSERT OR REPLACE INTO dir_mtime (path, mtime) VALUES (?, ?);"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK, let s = stmt else { return }
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            path.withCString { sqlite3_bind_text(s, 1, $0, -1, SQLITE_TRANSIENT) }
            sqlite3_bind_double(s, 2, mtime)
            sqlite3_step(s)
            sqlite3_finalize(s)
        }
    }

    // MARK: - Generation helpers for incremental indexing

    /// Mark all files under `dirPath` (and the dir itself) as current for the given generation.
    func updateGeneration(path dirPath: String, generation: Int64) {
        dbQueue.sync {
            let query = "UPDATE files SET generation = ? WHERE path = ? OR path LIKE ? ESCAPE '\\';"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK, let s = stmt else { return }
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_int64(s, 1, generation)
            dirPath.withCString { sqlite3_bind_text(s, 2, $0, -1, SQLITE_TRANSIENT) }
            let escaped = dirPath.replacingOccurrences(of: "\\", with: "\\\\")
                                .replacingOccurrences(of: "%", with: "\\%")
                                .replacingOccurrences(of: "_", with: "\\_")
            (escaped + "/%").withCString { sqlite3_bind_text(s, 3, $0, -1, SQLITE_TRANSIENT) }
            sqlite3_step(s)
            sqlite3_finalize(s)
        }
    }

}
