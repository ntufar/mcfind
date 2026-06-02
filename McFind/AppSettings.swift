import Foundation
import Combine

class AppSettings: ObservableObject {
    @Published var showFullPath: Bool {
        didSet {
            UserDefaults.standard.set(showFullPath, forKey: "showFullPath")
        }
    }

    @Published var compactMode: Bool {
        didSet {
            UserDefaults.standard.set(compactMode, forKey: "compactMode")
        }
    }

    @Published var indexDotFiles: Bool {
        didSet {
            UserDefaults.standard.set(indexDotFiles, forKey: "indexDotFiles")
        }
    }

    init() {
        self.showFullPath = UserDefaults.standard.bool(forKey: "showFullPath")
        self.compactMode = UserDefaults.standard.bool(forKey: "compactMode")
        self.indexDotFiles = UserDefaults.standard.bool(forKey: "indexDotFiles")
    }
}
