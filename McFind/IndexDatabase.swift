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

    func insertFile(_ file: FileItem) {
        dbQueue.sync {
            let insertQuery = """
            INSERT OR REPLACE INTO files (path, name, is_directory, size, modified_date)
            VALUES (?, ?, ?, ?, ?);
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
        INSERT OR REPLACE INTO files (path, name, is_directory, size, modified_date)
        VALUES (?, ?, ?, ?, ?);
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
        let searchQuery = """
        SELECT path, name, is_directory, size, modified_date FROM files
        WHERE name LIKE ? OR path LIKE ?
        ORDER BY
            CASE
                WHEN name = ? THEN 1
                WHEN name LIKE ? THEN 2
                WHEN name LIKE ? THEN 3
                WHEN path LIKE ? THEN 4
                ELSE 5
            END,
            name COLLATE NOCASE
        LIMIT 1000;
        """

        let pattern = "%\(query)%"
        let prefixPattern = "\(query)%"
        let pathPattern = "%/\(query)%"

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

        // WHERE name LIKE ? OR path LIKE ?
        pattern.withCString { cString in
            _ = sqlite3_bind_text(stmt, 1, cString, -1, SQLITE_TRANSIENT)
        }
        pattern.withCString { cString in
            _ = sqlite3_bind_text(stmt, 2, cString, -1, SQLITE_TRANSIENT)
        }

        // ORDER BY cases
        query.withCString { cString in
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
