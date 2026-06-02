import SwiftUI
import AppKit

extension Notification.Name {
    static let mcfindRenameSelected = Notification.Name("com.mcfind.renameSelected")
    static let mcfindRenameCancel = Notification.Name("com.mcfind.renameCancel")
}

struct ResizableTableView: NSViewRepresentable {
    @Binding var files: [FileItem]
    @Binding var selectedIndex: Int
    @Binding var focusResults: Bool
    var onDoubleClick: () -> Void
    var onSelectionChange: (Int) -> Void
    var onRevealInFinder: (() -> Void)?
    var onCopyPath: (() -> Void)?
    var onCopyFile: (() -> Void)?
    var onMoveToTrash: ((Int) -> Void)?
    var onRenameFile: ((Int, String) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()

        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = false
        tableView.headerView = nil
        tableView.target = context.coordinator
        tableView.action = #selector(Coordinator.tableViewClicked(_:))
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)

        let menu = NSMenu()
        menu.delegate = context.coordinator
        tableView.menu = menu

        // Name column
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 250
        nameColumn.minWidth = 100
        nameColumn.maxWidth = 500
        tableView.addTableColumn(nameColumn)

        // Path column
        let pathColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        pathColumn.title = "Path"
        pathColumn.width = 400
        pathColumn.minWidth = 150
        pathColumn.maxWidth = 1000
        tableView.addTableColumn(pathColumn)

        // Size column
        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        sizeColumn.title = "Size"
        sizeColumn.width = 100
        sizeColumn.minWidth = 60
        sizeColumn.maxWidth = 150
        tableView.addTableColumn(sizeColumn)

        // Modified column
        let modifiedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("modified"))
        modifiedColumn.title = "Modified"
        modifiedColumn.width = 150
        modifiedColumn.minWidth = 100
        modifiedColumn.maxWidth = 200
        tableView.addTableColumn(modifiedColumn)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true

        context.coordinator.tableView = tableView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? NSTableView else { return }

        // Check if files array actually changed
        let filesChanged = !areFilesEqual(context.coordinator.files, files)

        if filesChanged {
            print("📊 TableView: Files changed (old: \(context.coordinator.files.count), new: \(files.count))")
            context.coordinator.files = files
            tableView.reloadData()
        }

        // Only update selection if it changed and is different from what we last set
        if selectedIndex != context.coordinator.lastKnownSelection {
            print("📌 TableView: Selection changed to \(selectedIndex)")
            context.coordinator.lastKnownSelection = selectedIndex
            if selectedIndex >= 0 && selectedIndex < files.count {
                context.coordinator.isProgrammaticSelection = true
                tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
                tableView.scrollRowToVisible(selectedIndex)
                context.coordinator.isProgrammaticSelection = false
            }
        }

        // Give keyboard focus to the table when user navigates with arrow keys
        if focusResults {
            tableView.window?.makeFirstResponder(tableView)
            let binding = $focusResults
            DispatchQueue.main.async {
                binding.wrappedValue = false
            }
        }
    }

    private func areFilesEqual(_ a: [FileItem], _ b: [FileItem]) -> Bool {
        guard a.count == b.count else { return false }
        guard !a.isEmpty else { return true }
        // Quick check: compare first and last items
        return a.first?.id == b.first?.id && a.last?.id == b.last?.id
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(files: $files, selectedIndex: $selectedIndex, onDoubleClick: onDoubleClick, onSelectionChange: onSelectionChange, onRevealInFinder: onRevealInFinder, onCopyPath: onCopyPath, onCopyFile: onCopyFile, onMoveToTrash: onMoveToTrash, onRenameFile: onRenameFile)
    }

    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate, NSTextFieldDelegate {
        var files: [FileItem] = []
        @Binding var selectedIndex: Int
        var onDoubleClick: () -> Void
        var onSelectionChange: (Int) -> Void
        var onRevealInFinder: (() -> Void)?
        var onCopyPath: (() -> Void)?
        var onCopyFile: (() -> Void)?
        var onMoveToTrash: ((Int) -> Void)?
        var onRenameFile: ((Int, String) -> Void)?
        weak var tableView: NSTableView?
        var isProgrammaticSelection = false
        var lastKnownSelection = 0
        private var clickedRow: Int = -1
        private var renamingRow: Int = -1
        private var originalName: String = ""

        init(files: Binding<[FileItem]>, selectedIndex: Binding<Int>, onDoubleClick: @escaping () -> Void, onSelectionChange: @escaping (Int) -> Void, onRevealInFinder: (() -> Void)?, onCopyPath: (() -> Void)?, onCopyFile: (() -> Void)?, onMoveToTrash: ((Int) -> Void)?, onRenameFile: ((Int, String) -> Void)?) {
            self._selectedIndex = selectedIndex
            self.onDoubleClick = onDoubleClick
            self.onSelectionChange = onSelectionChange
            self.onRevealInFinder = onRevealInFinder
            self.onCopyPath = onCopyPath
            self.onCopyFile = onCopyFile
            self.onMoveToTrash = onMoveToTrash
            self.onRenameFile = onRenameFile
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(renameSelectedFile), name: .mcfindRenameSelected, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(cancelRenameNotification), name: .mcfindRenameCancel, object: nil)
        }

        deinit {
            NotificationCenter.default.removeObserver(self, name: .mcfindRenameSelected, object: nil)
            NotificationCenter.default.removeObserver(self, name: .mcfindRenameCancel, object: nil)
        }

        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            clickedRow = tableView?.clickedRow ?? -1
            guard clickedRow >= 0, clickedRow < files.count else { return }

            let openItem = NSMenuItem(title: "Open in Default App", action: #selector(menuOpenFile(_:)), keyEquivalent: "")
            openItem.target = self
            menu.addItem(openItem)

            let revealItem = NSMenuItem(title: "Reveal in Finder", action: #selector(menuRevealInFinder(_:)), keyEquivalent: "")
            revealItem.target = self
            menu.addItem(revealItem)

            menu.addItem(NSMenuItem.separator())

            let copyPathItem = NSMenuItem(title: "Copy Path", action: #selector(menuCopyPath(_:)), keyEquivalent: "")
            copyPathItem.target = self
            menu.addItem(copyPathItem)

            let copyFileItem = NSMenuItem(title: "Copy File", action: #selector(menuCopyFile(_:)), keyEquivalent: "")
            copyFileItem.target = self
            menu.addItem(copyFileItem)

            menu.addItem(NSMenuItem.separator())

            let shareItem = NSMenuItem(title: "Share", action: nil, keyEquivalent: "")
            shareItem.submenu = buildShareMenu()
            menu.addItem(shareItem)

            let renameItem = NSMenuItem(title: "Rename", action: #selector(menuRenameFile(_:)), keyEquivalent: "")
            renameItem.target = self
            menu.addItem(renameItem)

            menu.addItem(NSMenuItem.separator())

            let deleteItem = NSMenuItem(title: "Move to Trash", action: #selector(menuMoveToTrash(_:)), keyEquivalent: "")
            deleteItem.target = self
            menu.addItem(deleteItem)
        }

        private func buildShareMenu() -> NSMenu {
            let menu = NSMenu(title: "Share")
            guard clickedRow >= 0, clickedRow < files.count else { return menu }
            let url = URL(fileURLWithPath: files[clickedRow].path)
            let services = NSSharingService.sharingServices(forItems: [url])
            for service in services {
                let item = NSMenuItem(title: service.title, action: #selector(shareViaService(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = service
                item.image = service.image
                menu.addItem(item)
            }
            return menu
        }

        @objc private func menuOpenFile(_ sender: Any?) {
            guard clickedRow >= 0, clickedRow < files.count else { return }
            onSelectionChange(clickedRow)
            onDoubleClick()
        }

        @objc private func menuRevealInFinder(_ sender: Any?) {
            guard clickedRow >= 0, clickedRow < files.count else { return }
            onSelectionChange(clickedRow)
            onRevealInFinder?()
        }

        @objc private func menuCopyPath(_ sender: Any?) {
            guard clickedRow >= 0, clickedRow < files.count else { return }
            onSelectionChange(clickedRow)
            onCopyPath?()
        }

        @objc private func menuCopyFile(_ sender: Any?) {
            guard clickedRow >= 0, clickedRow < files.count else { return }
            onSelectionChange(clickedRow)
            onCopyFile?()
        }

        @objc private func menuMoveToTrash(_ sender: Any?) {
            guard clickedRow >= 0, clickedRow < files.count else { return }
            let file = files[clickedRow]
            let alert = NSAlert()
            alert.messageText = "Are you sure you want to move \"\(file.name)\" to the Trash?"
            alert.informativeText = "This action cannot be undone."
            alert.addButton(withTitle: "Move to Trash")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                onSelectionChange(clickedRow)
                onMoveToTrash?(clickedRow)
            }
        }

        @objc private func shareViaService(_ sender: NSMenuItem) {
            guard let service = sender.representedObject as? NSSharingService,
                  clickedRow >= 0, clickedRow < files.count else { return }
            let url = URL(fileURLWithPath: files[clickedRow].path)
            service.perform(withItems: [url])
        }

        @objc private func menuRenameFile(_ sender: Any?) {
            beginRenaming(row: clickedRow)
        }

        @objc private func renameSelectedFile() {
            beginRenaming(row: selectedIndex)
        }

        private func beginRenaming(row: Int) {
            guard let tableView = tableView,
                  row >= 0, row < files.count,
                  let cellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: true) as? NSTableCellView,
                  let textField = cellView.textField else { return }
            tableView.scrollRowToVisible(row)
            renamingRow = row
            originalName = files[row].name
            textField.isEditable = true
            textField.delegate = self
            textField.drawsBackground = true
            textField.backgroundColor = .controlBackgroundColor
            textField.textColor = .controlTextColor
            tableView.window?.makeFirstResponder(textField)
            DispatchQueue.main.async {
                textField.currentEditor()?.selectAll(nil)
            }
        }

        // MARK: - Drag and Drop

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard row >= 0, row < files.count else { return nil }
            return NSURL(fileURLWithPath: files[row].path)
        }

        // MARK: - NSTextFieldDelegate

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField,
                  let tableView = tableView,
                  let cellView = textField.superview as? NSTableCellView else { return }
            let row = tableView.row(for: cellView)
            guard row >= 0, row == renamingRow, row < files.count else { return }

            textField.isEditable = false
            textField.drawsBackground = false
            renamingRow = -1

            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty, newName != originalName else {
                textField.stringValue = originalName
                return
            }

            onRenameFile?(row, newName)
            files[row] = FileItem(
                path: (files[row].path as NSString).deletingLastPathComponent + "/" + newName,
                name: newName,
                isDirectory: files[row].isDirectory,
                size: files[row].size,
                dateModified: files[row].dateModified
            )
            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integersIn: 0..<tableView.tableColumns.count))
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            print("✏️ doCommandBy: \(commandSelector)")
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                cancelRename()
                return true
            }
            return false
        }

        @objc private func cancelRenameNotification() {
            cancelRename()
        }

        private func cancelRename() {
            guard renamingRow >= 0, renamingRow < files.count else { return }
            guard let tableView = tableView,
                  let cellView = tableView.view(atColumn: 0, row: renamingRow, makeIfNecessary: false) as? NSTableCellView,
                  let textField = cellView.textField else { return }
            print("✏️ cancelRename: restoring '\(originalName)'")
            textField.stringValue = originalName
            textField.isEditable = false
            textField.drawsBackground = false
            renamingRow = -1
            tableView.window?.makeFirstResponder(tableView)
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            return files.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < files.count, let identifier = tableColumn?.identifier else { return nil }
            let file = files[row]

            // Try to reuse existing cell
            let cellView: NSTableCellView
            if let reusedView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
                cellView = reusedView
            } else {
                // Create new cell only if needed
                cellView = NSTableCellView()
                cellView.identifier = identifier

                let textField = NSTextField()
                textField.isBordered = false
                textField.drawsBackground = false
                textField.isEditable = false
                textField.font = NSFont.systemFont(ofSize: 12)
                textField.lineBreakMode = .byTruncatingMiddle
                textField.translatesAutoresizingMaskIntoConstraints = false

                cellView.addSubview(textField)
                cellView.textField = textField

                // Setup based on column type
                switch identifier.rawValue {
                case "name":
                    textField.delegate = self

                    let imageView = NSImageView()
                    imageView.imageScaling = .scaleProportionallyDown
                    imageView.translatesAutoresizingMaskIntoConstraints = false
                    cellView.addSubview(imageView)
                    cellView.imageView = imageView

                    NSLayoutConstraint.activate([
                        imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                        imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                        imageView.widthAnchor.constraint(equalToConstant: 16),
                        imageView.heightAnchor.constraint(equalToConstant: 16),
                        textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                        textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                        textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
                    ])

                case "path":
                    NSLayoutConstraint.activate([
                        textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                        textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                        textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
                    ])
                    textField.textColor = .secondaryLabelColor

                case "size", "modified":
                    NSLayoutConstraint.activate([
                        textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                        textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
                    ])
                    textField.alignment = .right
                    textField.textColor = .secondaryLabelColor

                default:
                    break
                }
            }

            // Update content (for both new and reused cells)
            switch identifier.rawValue {
            case "name":
                cellView.textField?.stringValue = file.name
                cellView.imageView?.image = file.fileIcon

            case "path":
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                var displayPath = file.path
                if displayPath.hasPrefix(home) {
                    let relative = String(displayPath.dropFirst(home.count))
                    if let lastSlash = relative.lastIndex(of: "/") {
                        displayPath = "~" + String(relative[..<lastSlash])
                    } else {
                        displayPath = "~"
                    }
                } else {
                    if let lastSlash = displayPath.lastIndex(of: "/") {
                        displayPath = String(displayPath[..<lastSlash])
                    }
                }
                cellView.textField?.stringValue = displayPath

            case "size":
                cellView.textField?.stringValue = file.isDirectory ? "" : file.formattedSize

            case "modified":
                cellView.textField?.stringValue = file.formattedDate

            default:
                break
            }

            return cellView
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            return 22
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            // Don't process programmatic selection changes
            guard !isProgrammaticSelection else { return }

            guard let tableView = notification.object as? NSTableView else { return }
            let row = tableView.selectedRow
            if row >= 0 && row < files.count && row != lastKnownSelection {
                lastKnownSelection = row
                selectedIndex = row
                // Defer to avoid modifying @Published/@State during view update
                DispatchQueue.main.async { [weak self] in
                    self?.onSelectionChange(row)
                }
            }
        }

        @objc func tableViewClicked(_ sender: Any?) {
            guard let event = NSApp.currentEvent else { return }
            if event.clickCount == 2 {
                onDoubleClick()
            }
        }
    }
}
