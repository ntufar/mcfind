import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = IndexSettings.shared
    @ObservedObject private var appSettings = AppSettings()
    @AppStorage("showPreviewPanel") private var showPreviewPanel = true
    @State private var showReindexAlert = false
    @State private var hasChanges = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Indexed Folders")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Choose which top-level folders in your home directory to include in the search index.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 8) {
                            ForEach(getAllIndexPaths(), id: \.path) { indexPath in
                                FolderToggleRow(
                                    folderName: indexPath.displayName,
                                    isEnabled: !settings.isExcluded(indexPath.path),
                                    isIndented: !indexPath.isTopLevel,
                                    onToggle: {
                                        togglePath(indexPath.path)
                                    }
                                )
                            }
                        }
                        .padding(.top, 8)
                    }

                    Divider()

                    // Indexing Options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Indexing Options")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)

                        HStack {
                            Text("Index dot files and directories")
                                .font(.system(size: 12))
                            Spacer()
                            Toggle("", isOn: $appSettings.indexDotFiles)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .onChange(of: appSettings.indexDotFiles) { _ in
                                    hasChanges = true
                                }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        )
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Display Options")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)

                        HStack {
                            Text("Show preview panel")
                                .font(.system(size: 12))
                            Spacer()
                            Toggle("", isOn: $showPreviewPanel)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        )
                    }

                    Divider()

                    // Info section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                            Text("After changing settings, re-index to apply changes")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)

                        Button("Reset to Defaults") {
                            settings.resetToDefaults()
                            hasChanges = true
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                if hasChanges {
                    Button("Re-index Now") {
                        showReindexAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 500)
        .alert("Re-index Files?", isPresented: $showReindexAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Re-index") {
                NotificationCenter.default.post(name: NSNotification.Name("ReindexFiles"), object: nil)
                hasChanges = false
            }
        } message: {
            Text("This will clear the current index and scan all selected folders. This may take a few minutes.")
        }
    }

    private func getAllIndexPaths() -> [IndexPath] {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let fileManager = FileManager.default

        var allPaths: [IndexPath] = []

        // Add predefined paths (Library and its subfolders)
        allPaths.append(contentsOf: IndexSettings.predefinedPaths)

        // Get actual top-level folders
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: homeURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )

            let foundFolders = contents
                .filter { url in
                    (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                }
                .map { $0.lastPathComponent }
                .filter { folderName in
                    !folderName.hasPrefix(".") && // Skip dot-files
                    folderName != "Library" // Already in predefined paths
                }

            // Add other top-level folders
            for folder in foundFolders {
                allPaths.append(IndexPath(
                    path: folder,
                    displayName: folder,
                    isTopLevel: true,
                    defaultEnabled: true
                ))
            }
        } catch {
            Log.ui.debug("Error reading home directory: \(error)")
        }

        // Sort: top-level folders first (alphabetically), then Library, then Library subfolders
        return allPaths.sorted { a, b in
            if a.sortOrder != b.sortOrder {
                return a.sortOrder < b.sortOrder
            }
            return a.displayName < b.displayName
        }
    }

    private func togglePath(_ path: String) {
        if settings.isExcluded(path) {
            settings.excludedPaths.remove(path)
        } else {
            settings.excludedPaths.insert(path)
        }
        hasChanges = true
    }
}

struct FolderToggleRow: View {
    let folderName: String
    let isEnabled: Bool
    let isIndented: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if isIndented {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            } else {
                Image(systemName: "folder")
                    .font(.system(size: 16))
                    .foregroundColor(isEnabled ? .blue : .secondary)
                    .frame(width: 20)
            }

            Text(folderName)
                .font(.system(size: isIndented ? 11 : 12))
                .foregroundColor(isEnabled ? .primary : .secondary)

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .padding(.leading, isIndented ? 24 : 0)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor).opacity(isIndented ? 0.3 : 0.5))
        )
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
