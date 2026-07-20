import os

enum Log {
    static let indexing = Logger(subsystem: "com.mcfind.app", category: "indexing")
    static let database = Logger(subsystem: "com.mcfind.app", category: "database")
    static let search = Logger(subsystem: "com.mcfind.app", category: "search")
    static let ui = Logger(subsystem: "com.mcfind.app", category: "ui")
    static let fileMonitor = Logger(subsystem: "com.mcfind.app", category: "fileMonitor")
}
