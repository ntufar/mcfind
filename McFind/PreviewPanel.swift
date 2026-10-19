import SwiftUI
import UniformTypeIdentifiers
import QuickLookThumbnailing

struct PreviewPanel: View {
    let files: [FileItem]
    let onOpen: ([FileItem]) -> Void
    let onReveal: ([FileItem]) -> Void
    let onCopyPaths: ([FileItem]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if files.count > 1 {
                multiSelection
            } else if let file = files.last {
                singleSelection(file)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 292)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - One file

    private func singleSelection(_ file: FileItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            FileThumbnail(file: file)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Text(summaryLine(for: file))
                    .font(Typo.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 6) {
                Button("Open") { onOpen([file]) }
                    .buttonStyle(ActionButtonStyle(prominent: true))
                Button("Reveal") { onReveal([file]) }
                    .buttonStyle(ActionButtonStyle())
                    .help("Reveal in Finder")
                Button("Copy path") { onCopyPaths([file]) }
                    .buttonStyle(ActionButtonStyle())
            }
            .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .topLeading, horizontalSpacing: 10, verticalSpacing: 7) {
                MetadataRow(label: "Modified", value: Self.fullDate(file.dateModified))
                if let created = creationDate(of: file) {
                    MetadataRow(label: "Created", value: Self.fullDate(created))
                }
                MetadataRow(label: "Folder", value: folderDisplay(for: file))
            }
        }
    }

    // MARK: - Several files

    private var multiSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(files.count) files selected")
                    .font(.system(size: 15, weight: .semibold))
                let total = files.reduce(Int64(0)) { $0 + ($1.isDirectory ? 0 : $1.size) }
                if total > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                        .font(Typo.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 6) {
                Button("Open \(files.count)") { onOpen(files) }
                    .buttonStyle(ActionButtonStyle(prominent: true))
                Button("Reveal") { onReveal(files) }
                    .buttonStyle(ActionButtonStyle())
                Button("Copy paths") { onCopyPaths(files) }
                    .buttonStyle(ActionButtonStyle())
            }
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(files.prefix(5)) { file in
                    HStack(spacing: 8) {
                        Image(nsImage: file.fileIcon)
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text(file.name)
                            .font(Typo.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                if files.count > 5 {
                    Text("and \(files.count - 5) more")
                        .font(Typo.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Formatting

    private func summaryLine(for file: FileItem) -> String {
        let kind = kindDescription(for: file)
        let size = file.formattedSize
        return size.isEmpty ? kind : "\(kind) \u{00B7} \(size)"
    }

    private func kindDescription(for file: FileItem) -> String {
        if file.isDirectory { return "Folder" }
        if let ext = file.fileExtension,
           let type = UTType(filenameExtension: ext),
           let description = type.localizedDescription {
            return description.prefix(1).uppercased() + description.dropFirst()
        }
        return "Document"
    }

    private func folderDisplay(for file: FileItem) -> String {
        let folder = (file.path as NSString).deletingLastPathComponent
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if folder == home { return "~" }
        return folder.hasPrefix(home + "/") ? "~" + folder.dropFirst(home.count) : folder
    }

    private func creationDate(of file: FileItem) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
        return attributes?[.creationDate] as? Date
    }

    private static func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("dMMMyyyy jmm")
        return formatter.string(from: date)
    }
}

// MARK: - Thumbnail

/// A Quick Look thumbnail of the file's contents. Falls back to the file icon while loading,
/// and for files with no thumbnail.
private struct FileThumbnail: View {
    let file: FileItem
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.hairline, lineWidth: 1)

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    .padding(14)
            } else {
                Image(nsImage: file.fileIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
            }
        }
        .frame(height: 176)
        .accessibilityHidden(true)
        .task(id: file.path) {
            image = nil
            guard !file.isDirectory else { return }
            let loaded = await Self.thumbnail(for: file)
            if !Task.isCancelled { image = loaded }
        }
    }

    private static func thumbnail(for file: FileItem) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: URL(fileURLWithPath: file.path),
            size: CGSize(width: 244, height: 148),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )
        let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
        return representation?.nsImage
    }
}

// MARK: - Metadata

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(label)
                .font(Typo.caption)
                .foregroundColor(.secondary.opacity(0.8))
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(Typo.caption.monospacedDigit())
                .lineLimit(2)
                .truncationMode(.head)
                .textSelection(.enabled)
                .help(value)
        }
    }
}
