import SwiftUI
import UniformTypeIdentifiers

struct PreviewPanel: View {
    let file: FileItem?
    let files: [FileItem]
    let selectedCount: Int

    init(file: FileItem) {
        self.file = file
        self.files = [file]
        self.selectedCount = 1
    }

    init(files: [FileItem], selectedCount: Int) {
        self.file = files.last
        self.files = files
        self.selectedCount = selectedCount
    }

    var body: some View {
        VStack(spacing: 0) {
            if selectedCount > 1 {
                // Multi-select summary
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    Text("\(selectedCount) items selected")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    let totalSize = files.reduce(Int64(0)) { $0 + $1.size }
                    if totalSize > 0 {
                        Text(formatTotalSize(totalSize))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)

                Divider()

                // Show last-selected file details
                if let file = file {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Selected")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 12)

                        HStack(spacing: 8) {
                            Image(nsImage: file.fileIcon)
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text(file.name)
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let file = file {
                // Header with icon and name
                VStack(spacing: 12) {
                    Image(nsImage: file.fileIcon)
                        .resizable()
                        .frame(width: 64, height: 64)

                    Text(file.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .truncationMode(.middle)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)

                Divider()

                // Metadata list
                VStack(spacing: 0) {
                    MetadataRow(label: "Kind", value: kindDescription)
                    MetadataRow(label: "Size", value: file.formattedSize)
                    MetadataRow(label: "Created", value: formattedCreationDate)
                    MetadataRow(label: "Modified", value: file.formattedDate)
                    MetadataRow(label: "Extension", value: file.fileExtension ?? "\u{2014}")
                    MetadataRow(label: "Path", value: file.path)
                }
                .padding(.vertical, 12)
            }

            Spacer()
        }
        .frame(width: 240)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var kindDescription: String {
        guard let file = file else { return "\u{2014}" }
        if file.isDirectory {
            return "Folder"
        }
        if let ext = file.fileExtension,
           let type = UTType(filenameExtension: ext),
           let description = type.localizedDescription {
            return description
        }
        return "Unknown"
    }

    private var formattedCreationDate: String {
        guard let file = file else { return "\u{2014}" }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return formatter.string(from: creationDate)
            }
        } catch {}
        return "\u{2014}"
    }

    private func formatTotalSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)

            SelectableLabel(text: value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

private struct SelectableLabel: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.isEditable = false
        field.isSelectable = true
        field.isBordered = false
        field.drawsBackground = false
        field.font = .systemFont(ofSize: 11)
        field.textColor = .labelColor
        field.maximumNumberOfLines = 0
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextField, context: Context) -> CGSize? {
        let width = proposal.width ?? 138
        nsView.preferredMaxLayoutWidth = width
        let size = nsView.intrinsicContentSize
        return CGSize(width: width, height: size.height)
    }
}
