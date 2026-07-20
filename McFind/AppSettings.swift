import Foundation
import Combine

class AppSettings: ObservableObject {
    @Published var indexDotFiles: Bool {
        didSet {
            UserDefaults.standard.set(indexDotFiles, forKey: "indexDotFiles")
        }
    }

    init() {
        self.indexDotFiles = UserDefaults.standard.bool(forKey: "indexDotFiles")
    }
}
