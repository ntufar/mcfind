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

        if !hasNameNorm {
            sqlite3_exec(db, "ALTER TABLE files ADD COLUMN name_normalized TEXT NOT NULL DEFAULT '';", nil, nil, nil)
        }
        if !hasPathNorm {
            sqlite3_exec(db, "ALTER TABLE files ADD COLUMN path_normalized TEXT NOT NULL DEFAULT '';", nil, nil, nil)
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

    func insertFile(_ file: FileItem) {
        dbQueue.sync {
            let insertQuery = """
            INSERT OR REPLACE INTO files (path, name, is_directory, size, modified_date, name_normalized, path_normalized)
            VALUES (?, ?, ?, ?, ?, ?, ?);
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

            if sqlite3_step(stmt) != SQLITE_DONE {
                print("❌ Error inserting file: \(file.path)")
            }

            sqlite3_finalize(stmt)
        }
    }

    func insertFiles(_ files: [FileItem]) {
        dbQueue.sync {
            sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)

            for file in files {
                // Call internal version that doesn't use dbQueue
                insertFileInternal(file)
            }

            sqlite3_exec(db, "COMMIT", nil, nil, nil)
        }
    }

    private func insertFileInternal(_ file: FileItem) {
        let insertQuery = """
        INSERT OR REPLACE INTO files (path, name, is_directory, size, modified_date, name_normalized, path_normalized)
        VALUES (?, ?, ?, ?, ?, ?, ?);
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

    func search(_ query: String) -> [FileItem] {
        print("🔍 IndexDatabase.search() called with: '\(query)'")
        guard !query.isEmpty else {
            print("⚠️ Empty query, returning []")
            return []
        }

        print("⏳ Waiting for database queue...")
        let startTime = Date()
        let results = dbQueue.sync {
            print("🔓 Database queue acquired")
            return searchInternal(query)
        }
        let elapsed = Date().timeIntervalSince(startTime)
        print("✅ Search completed in \(String(format: "%.3f", elapsed))s - found \(results.count) results")
        return results
    }

    private func searchInternal(_ query: String) -> [FileItem] {
        print("  📊 searchInternal() starting...")
        var files: [FileItem] = []

        // Normalize query for Unicode-aware case-insensitive matching
        let normalizedQuery = query.lowercased()
        let pattern = "%\(normalizedQuery)%"
        let prefixPattern = "\(normalizedQuery)%"
        let pathPattern = "%/\(normalizedQuery)%"

        let searchQuery = """
        SELECT path, name, is_directory, size, modified_date FROM files
        WHERE name_normalized LIKE ? OR path_normalized LIKE ?
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

        // WHERE name_normalized LIKE ? OR path_normalized LIKE ?
        pattern.withCString { cString in
            _ = sqlite3_bind_text(stmt, 1, cString, -1, SQLITE_TRANSIENT)
        }
        pattern.withCString { cString in
            _ = sqlite3_bind_text(stmt, 2, cString, -1, SQLITE_TRANSIENT)
        }

        // ORDER BY cases
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
        print("  ✅ searchInternal() found \(files.count) files")

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
            sqlite3_exec(db, "VACUUM;", nil, nil, nil)
        }
    }
}
