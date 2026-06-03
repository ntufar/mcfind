import SwiftUI
import UniformTypeIdentifiers

struct PreviewPanel: View {
    let file: FileItem

    var body: some View {
        VStack(spacing: 0) {
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
                MetadataRow(label: "Extension", value: file.fileExtension ?? "—")
                MetadataRow(label: "Path", value: file.path)
            }
            .padding(.vertical, 12)

            Spacer()
        }
        .frame(width: 240)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var kindDescription: String {
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
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return formatter.string(from: creationDate)
            }
        } catch {}
        return "—"
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
