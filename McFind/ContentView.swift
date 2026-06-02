import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SearchViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))

                TextField("Search files...", text: $viewModel.searchText, onCommit: {
                    viewModel.openSelectedFile()
                })
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Size Filter Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(SizeFilter.allCases) { filter in
                        Button(action: {
                            viewModel.selectedSizeFilter = filter
                        }) {
                            Text(filter.displayName)
                                .font(.system(size: 10))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(viewModel.selectedSizeFilter == filter ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                                .foregroundColor(viewModel.selectedSizeFilter == filter ? .white : .secondary)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            Divider()

            // Status Bar
            HStack(spacing: 12) {
                if viewModel.isLoadingFromDisk && viewModel.totalFiles == 0 {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading index...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else if viewModel.isIndexing {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Indexing: \(viewModel.indexedCount) files")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Cancel") {
                        viewModel.cancelIndexing()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                } else {
                    if !viewModel.files.isEmpty {
                        Text("\(viewModel.files.count) results")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if viewModel.totalFiles > 0 {
                        Text("\(viewModel.totalFiles.formatted()) files indexed")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Results List or Empty State
            if viewModel.files.isEmpty && !viewModel.isIndexing && !viewModel.isLoadingFromDisk {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text(viewModel.searchText.isEmpty ? "Start typing to search" : "No files found")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    if !viewModel.searchText.isEmpty {
                        Text("Try a different search term")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Resizable Table View
                ResizableTableView(
                    files: $viewModel.files,
                    selectedIndex: $viewModel.selectedIndex,
                    onDoubleClick: {
                        viewModel.openSelectedFile()
                    },
                    onSelectionChange: { index in
                        viewModel.selectFile(at: index)
                    },
                    onRevealInFinder: {
                        viewModel.revealInFinder()
                    },
                    onCopyPath: {
                        viewModel.copyPath()
                    },
                    onCopyFile: {
                        viewModel.copyFile()
                    },
                    onMoveToTrash: { index in
                        viewModel.moveToTrashFile(at: index)
                    }
                )
            }
        }
        .handleKeyEvents { event in
            switch Int(event.keyCode) {
            case 125: // Down arrow
                viewModel.selectNext()
                return true
            case 126: // Up arrow
                viewModel.selectPrevious()
                return true
            case 53: // Escape
                if !viewModel.searchText.isEmpty {
                    viewModel.searchText = ""
                } else {
                    NSApplication.shared.keyWindow?.close()
                }
                return true
            default:
                return false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReindexFiles"))) { _ in
            viewModel.startIndexing()
        }
    }
}

struct CompactFileRowView: View {
    let file: FileItem
    let isSelected: Bool

    private var relativePath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if file.path.hasPrefix(home) {
            let relative = String(file.path.dropFirst(home.count))
            if relative.hasPrefix("/") {
                return "~" + relative
            }
            return "~/" + relative
        }
        return file.path
    }

    private var parentPath: String {
        let url = URL(fileURLWithPath: file.path)
        let parent = url.deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        if parent.hasPrefix(home) {
            let relative = String(parent.dropFirst(home.count))
            if relative.isEmpty {
                return "~"
            }
            if relative.hasPrefix("/") {
                return "~" + relative
            }
            return "~/" + relative
        }
        return parent
    }

    var body: some View {
        HStack(spacing: 0) {
            // Icon + Name
            HStack(spacing: 6) {
                Image(nsImage: file.fileIcon)
                    .resizable()
                    .frame(width: 16, height: 16)

                Text(file.name)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(width: 200, alignment: .leading)

            // Path
            Text(parentPath)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Size
            Text(file.isDirectory ? "" : file.formattedSize)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)

            // Modified Date
            Text(file.formattedDate)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(isSelected ? Color.accentColor.opacity(0.2) : (file.id.hashValue % 2 == 0 ? Color.clear : Color(NSColor.controlBackgroundColor).opacity(0.3)))
        .overlay(
            Rectangle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(width: 2)
                .frame(maxHeight: .infinity)
            , alignment: .leading
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
