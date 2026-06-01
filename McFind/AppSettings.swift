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

    init() {
        self.showFullPath = UserDefaults.standard.bool(forKey: "showFullPath")
        self.compactMode = UserDefaults.standard.bool(forKey: "compactMode")
    }
}
