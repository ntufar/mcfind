import SwiftUI
import AppKit

private func isSearchFieldActive() -> Bool {
    guard let window = NSApp.keyWindow,
          let responder = window.firstResponder else { return false }
    return responder is NSTextView || responder is NSTextField
}

struct ContentView: View {
    @StateObject private var viewModel = SearchViewModel()
    @AppStorage("showPreviewPanel") private var showPreviewPanel = true
    @State private var focusResults = false

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterBar
            Divider()
            content
            Divider()
            statusBar
        }
        .handleKeyEvents { event in
            switch Int(event.keyCode) {
            case 125: // Down arrow
                viewModel.selectNext()
                if !viewModel.files.isEmpty { focusResults = true }
                return true
            case 126: // Up arrow
                viewModel.selectPrevious()
                if !viewModel.files.isEmpty { focusResults = true }
                return true
            case 36: // Return
                // If editing a text field in a table cell (rename mode), end editing
                if let window = NSApp.keyWindow,
                   let firstResponder = window.firstResponder as? NSTextView,
                   let textField = firstResponder.delegate as? NSTextField,
                   textField.superview is NSTableCellView {
                    window.makeFirstResponder(nil)
                    return true
                }
                // If table has focus, start renaming the selected file
                if NSApp.keyWindow?.firstResponder is NSTableView {
                    NotificationCenter.default.post(name: .mcfindRenameSelected, object: nil)
                    return true
                }
                viewModel.openSelectedFiles()
                return true
            case 49: // Space
                if isSearchFieldActive() { return false }
                viewModel.toggleQuickLook()
                return true
            case 53: // Escape
                if viewModel.isQuickLookVisible { return false }
                // If editing a text field in a table cell (rename mode), cancel rename
                if let window = NSApp.keyWindow,
                   let firstResponder = window.firstResponder as? NSTextView,
                   let textField = firstResponder.delegate as? NSTextField,
                   textField.superview is NSTableCellView {
                    NotificationCenter.default.post(name: .mcfindRenameCancel, object: nil)
                    return true
                }
                if !viewModel.searchText.isEmpty {
                    viewModel.searchText = ""
                } else {
                    NSApplication.shared.keyWindow?.close()
                }
                return true
            case 0: // 'a'
                if event.modifierFlags.contains(.command) {
                    if isSearchFieldActive() { return false }
                    viewModel.selectAll()
                    return true
                }
                return false
            default:
                return false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReindexFiles"))) { _ in
            viewModel.startIndexing()
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.secondary.opacity(0.7))

            TextField(viewModel.totalFiles > 0 ? "Search \(Format.count(viewModel.totalFiles)) files" : "Search files",
                      text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(Typo.query)

            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Kbd("esc")
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    // MARK: - Filters

    private var filterBar: some View {
        HStack(spacing: 8) {
            FilterControl(
                title: "Size",
                activeLabel: viewModel.activeLabel(for: .size),
                fromQuery: viewModel.isFromToken(.size),
                options: SizeRange.presets.map { range in
                    .init(id: range.label, label: range.label,
                          isSelected: viewModel.effectiveFilters.size == range,
                          action: { viewModel.setSize(range) })
                },
                onClear: { viewModel.clearFilter(.size) }
            )

            FilterControl(
                title: "Kind",
                activeLabel: viewModel.activeLabel(for: .kind),
                fromQuery: viewModel.isFromToken(.kind),
                options: KindFilter.allCases.filter { $0 != .any }.map { kind in
                    .init(id: kind.rawValue, label: kind.displayName,
                          isSelected: viewModel.effectiveFilters.kind == kind && viewModel.effectiveFilters.extensions.isEmpty,
                          action: { viewModel.setKind(kind) })
                },
                onClear: { viewModel.clearFilter(.kind) }
            )

            FilterControl(
                title: "Modified",
                activeLabel: viewModel.activeLabel(for: .modified),
                fromQuery: viewModel.isFromToken(.modified),
                options: ModifiedFilter.presets.map { window in
                    .init(id: window.label, label: window.label,
                          isSelected: viewModel.effectiveFilters.modified == window,
                          action: { viewModel.setModified(window) })
                },
                onClear: { viewModel.clearFilter(.modified) }
            )

            Spacer(minLength: 12)

            if viewModel.hasActiveFilters {
                Button("Clear all") { viewModel.clearFilters() }
                    .buttonStyle(LinkButtonStyle())
                    .font(Typo.caption)
            } else {
                Text("Try size:>10mb kind:pdf modified:week")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(-1)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
    }

    // MARK: - Results

    @ViewBuilder
    private var content: some View {
        if viewModel.files.isEmpty {
            if !viewModel.hasQuery {
                WelcomeView(viewModel: viewModel)
            } else if viewModel.isLoadingFromDisk {
                Color.clear
            } else {
                NoResultsView(viewModel: viewModel)
            }
        } else {
            HStack(spacing: 0) {
                ResizableTableView(
                    files: $viewModel.files,
                    selectedIndices: $viewModel.selectedIndices,
                    focusResults: $focusResults,
                    query: viewModel.resultsQuery,
                    onDoubleClick: { viewModel.openSelectedFiles() },
                    onSelectionChange: { _ in },
                    onRevealInFinder: { viewModel.revealInFinder() },
                    onCopyPath: { viewModel.copyPaths() },
                    onCopyFile: { viewModel.copyFiles() },
                    onOpenTerminal: { viewModel.openTerminal() },
                    onCopyPathEscaped: { viewModel.copyPathsEscaped() },
                    onMoveToTrash: { indices in viewModel.moveToTrashFiles(at: indices) },
                    onRenameFile: { index, newName in viewModel.renameFile(at: index, to: newName) }
                )

                if showPreviewPanel, !viewModel.selectedFiles.isEmpty {
                    Divider()
                    PreviewPanel(
                        files: viewModel.selectedFiles,
                        onOpen: { viewModel.open($0) },
                        onReveal: { viewModel.reveal($0) },
                        onCopyPaths: { viewModel.copyPaths(of: $0) }
                    )
                }
            }
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 10) {
            if viewModel.isLoadingFromDisk && viewModel.totalFiles == 0 {
                ProgressView().controlSize(.small)
                Text("Loading index\u{2026}")
            } else if viewModel.isIndexing {
                if let fraction = viewModel.indexingFraction {
                    ProgressView(value: fraction)
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                        .frame(width: 140)
                    Text("Indexing \(Format.count(viewModel.indexedCount)) of about \(Format.count(viewModel.totalFiles))")
                } else {
                    ProgressView().controlSize(.small)
                    Text(viewModel.statusMessage.isEmpty
                         ? "Indexing \(Format.count(viewModel.indexedCount)) files"
                         : viewModel.statusMessage)
                }

                Spacer()

                Button("Cancel") { viewModel.cancelIndexing() }
                    .buttonStyle(LinkButtonStyle())
            } else {
                if !viewModel.files.isEmpty {
                    let selectedCount = viewModel.selectedIndices.count
                    if selectedCount > 1 {
                        Text("\(selectedCount) of \(Format.count(viewModel.files.count)) selected")
                    } else {
                        Text(viewModel.files.count >= 1000
                             ? "1,000+ results"
                             : "\(Format.count(viewModel.files.count)) results")
                    }
                }

                Spacer()

                if viewModel.totalFiles > 0 {
                    indexHealth
                }
            }
        }
        .font(Typo.micro)
        .monospacedDigit()
        .foregroundColor(.secondary)
        .padding(.horizontal, 22)
        .frame(height: 32)
    }

    private var indexHealth: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.good)
                    .frame(width: 6, height: 6)
                Text(indexHealthText)
            }
        }
    }

    private var indexHealthText: String {
        var text = "\(Format.count(viewModel.totalFiles)) files indexed"
        if let updated = viewModel.lastIndexedAt {
            text += " \u{00B7} updated \(Format.relative(updated))"
        }
        return text
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
