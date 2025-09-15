import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search files...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onKeyPress(.return) {
                        viewModel.openSelectedFile()
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        viewModel.selectPrevious()
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        viewModel.selectNext()
                        return .handled
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button("Clear") {
                        viewModel.searchText = ""
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding()
            
            // Progress Bar (when indexing)
            if viewModel.isIndexing {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Indexing files...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(viewModel.indexedCount) files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Results List
            if viewModel.files.isEmpty && !viewModel.isIndexing {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No files found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    if viewModel.searchText.isEmpty {
                        Text("Start typing to search your files")
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Try a different search term")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(Array(viewModel.files.enumerated()), id: \.element.id) { index, file in
                    FileRowView(
                        file: file,
                        isSelected: index == viewModel.selectedIndex
                    )
                    .onTapGesture {
                        viewModel.selectFile(at: index)
                    }
                    .onTapGesture(count: 2) {
                        viewModel.openSelectedFile()
                    }
                    .contextMenu {
                        Button("Open") {
                            viewModel.openSelectedFile()
                        }
                        
                        Button("Reveal in Finder") {
                            viewModel.revealInFinder()
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            isSearchFocused = true
        }
    }
}

struct FileRowView: View {
    let file: FileItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // File Icon
            Image(nsImage: file.fileIcon)
                .resizable()
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                // File Name
                Text(file.displayName)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // File Path
                Text(file.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                // File Size
                if !file.isDirectory {
                    Text(file.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Date Modified
                Text(file.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
    }
}

#Preview {
    ContentView()
}
