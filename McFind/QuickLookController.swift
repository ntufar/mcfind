import AppKit
import Quartz

final class QuickLookController: NSObject, QLPreviewPanelDataSource {
    var files: [FileItem] = []
    var selectedIndex: Int = 0

    var isVisible: Bool {
        QLPreviewPanel.shared()?.isVisible ?? false
    }

    func togglePanel() {
        guard let panel = QLPreviewPanel.shared() else { return }

        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.dataSource = self
            panel.delegate = nil
            panel.currentPreviewItemIndex = selectedIndex
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        files.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard index >= 0, index < files.count else { return nil }
        return NSURL(fileURLWithPath: files[index].path)
    }
}
