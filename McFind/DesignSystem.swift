import SwiftUI
import AppKit

// MARK: - Type scale

/// The four text styles McFind uses. Change sizes here, not at call sites.
enum Typo {
    static let query = Font.system(size: 22, weight: .regular)
    static let body = Font.system(size: 13)
    static let caption = Font.system(size: 12)
    static let micro = Font.system(size: 11)
    static let key = Font.system(size: 10.5, weight: .medium, design: .monospaced)
}

// MARK: - Colors

extension NSColor {
    convenience init(light: NSColor, dark: NSColor) {
        self.init(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum Theme {
    /// Pale yellow behind the part of a name that matched the query.
    static let matchBackgroundNS = NSColor(light: NSColor(hex: 0xFBF3DB), dark: NSColor(hex: 0x3A3218))
    static let matchForegroundNS = NSColor(light: NSColor(hex: 0x956400), dark: NSColor(hex: 0xF0C969))
    static let matchBackground = Color(nsColor: matchBackgroundNS)
    static let matchForeground = Color(nsColor: matchForegroundNS)

    static let ink = Color(nsColor: .labelColor)
    static let onInk = Color(nsColor: .windowBackgroundColor)
    static let hairline = Color(nsColor: .separatorColor)
    static let softFill = Color(nsColor: .labelColor).opacity(0.06)
    static let softFillHover = Color(nsColor: .labelColor).opacity(0.10)
    static let good = Color(nsColor: NSColor(light: NSColor(hex: 0x346538), dark: NSColor(hex: 0x9ED0A4)))
}

// MARK: - Query highlighting

enum QueryHighlighter {
    /// Ranges of `text` to highlight for `query`. Plain queries highlight the first match,
    /// wildcard queries highlight each literal piece in order, regex queries highlight nothing.
    static func ranges(in text: String, query: String) -> [Range<String.Index>] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        if q.count > 2, q.hasPrefix("/"), q.hasSuffix("/") { return [] }

        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let pieces: [String]
        if q.contains("*") || q.contains("?") {
            pieces = q.split(whereSeparator: { $0 == "*" || $0 == "?" }).map(String.init)
        } else {
            pieces = [q]
        }

        var result: [Range<String.Index>] = []
        var cursor = text.startIndex
        for piece in pieces where !piece.isEmpty {
            guard let found = text.range(of: piece, options: options, range: cursor..<text.endIndex) else { continue }
            result.append(found)
            cursor = found.upperBound
        }
        return result
    }

    static func attributed(_ text: String, query: String, font: NSFont, color: NSColor) -> NSAttributedString {
        // Attributed strings carry their own line breaking, so truncation has to be set here.
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let result = NSMutableAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
        let bold = NSFont.systemFont(ofSize: font.pointSize, weight: .semibold)
        for range in ranges(in: text, query: query) {
            result.addAttributes([
                .backgroundColor: Theme.matchBackgroundNS,
                .foregroundColor: Theme.matchForegroundNS,
                .font: bold
            ], range: NSRange(range, in: text))
        }
        return result
    }
}

// MARK: - Small components

/// A keyboard key, drawn as a physical key cap.
struct Kbd: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Typo.key)
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .accessibilityLabel(text)
    }
}

/// A filter menu. Idle it is a quiet outlined button; with a filter on it shows the value and a clear button.
struct FilterControl: View {
    struct Option: Identifiable {
        let id: String
        let label: String
        let isSelected: Bool
        let action: () -> Void
    }

    let title: String
    let activeLabel: String?
    let fromQuery: Bool
    let options: [Option]
    let onClear: () -> Void
    @State private var hoveringClear = false

    var body: some View {
        HStack(spacing: 4) {
            Menu {
                ForEach(options) { option in
                    Button(action: option.action) {
                        if option.isSelected {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
                if activeLabel != nil {
                    Divider()
                    Button("Clear \(title.lowercased()) filter", action: onClear)
                }
            } label: {
                Text(activeLabel.map { "\(title): \($0)" } ?? title)
                    .font(Typo.caption.weight(activeLabel == nil ? .regular : .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if activeLabel != nil {
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(hoveringClear ? Theme.softFillHover : Color.clear))
                }
                .buttonStyle(.plain)
                .onHover { hoveringClear = $0 }
                .accessibilityLabel("Clear \(title.lowercased()) filter")
                .help(fromQuery ? "Remove this filter from the search box" : "Clear this filter")
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, activeLabel == nil ? 8 : 5)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 6).fill(activeLabel == nil ? Color.clear : Theme.softFill))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.hairline, lineWidth: 1))
    }
}

/// Outlined action button. Set `prominent` for the primary action in a group.
struct ActionButtonStyle: ButtonStyle {
    var prominent = false
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.caption.weight(.medium))
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .foregroundColor(prominent ? Theme.onInk : .primary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(prominent ? Theme.ink.opacity(hovering ? 0.82 : 1) : (hovering ? Theme.softFill : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(prominent ? Color.clear : Theme.hairline, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { hovering = $0 }
    }
}

/// Text-only button in the system accent color, for secondary actions in the status bar.
struct LinkButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.accentColor)
            .underline(hovering)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .onHover { hovering = $0 }
    }
}

// MARK: - Number and time formatting

enum Format {
    static func count(_ value: Int) -> String {
        value.formatted(.number)
    }

    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Empty states

/// Shown before the first query: how much is searchable, recent files, and the keyboard shortcuts.
struct WelcomeView: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Find any file in your home folder")
                    .font(.system(size: 21, weight: .medium))
                    .padding(.bottom, 4)

                Text(viewModel.totalFiles > 0
                     ? "\(Format.count(viewModel.totalFiles)) files are searchable. Type a name or part of a path."
                     : "Type a name or part of a path. Results appear as you type.")
                    .font(Typo.body)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 28)

                if !viewModel.recentFiles.isEmpty {
                    Text("RECENTLY OPENED")
                        .font(Typo.key)
                        .tracking(0.5)
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        ForEach(viewModel.recentFiles) { file in
                            RecentRow(file: file) { viewModel.open([file]) }
                        }
                    }
                    .padding(.bottom, 28)
                }

                Text("FILTERS")
                    .font(Typo.key)
                    .tracking(0.5)
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.bottom, 6)

                VStack(spacing: 0) {
                    ForEach(FilterExample.all) { example in
                        FilterExampleRow(example: example) { viewModel.insertQuerySnippet(example.snippet) }
                    }
                }
                .padding(.bottom, 28)

                Text("SHORTCUTS")
                    .font(Typo.key)
                    .tracking(0.5)
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.bottom, 10)

                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 10) {
                    ShortcutHint(keys: ["\u{2191}", "\u{2193}"], label: "Move through results")
                    ShortcutHint(keys: ["\u{23CE}"], label: "Open the selected file")
                    ShortcutHint(keys: ["space"], label: "Quick Look")
                    ShortcutHint(keys: ["esc"], label: "Clear the search")
                    ShortcutHint(keys: ["\u{2318}", "\u{21E7}", "R"], label: "Re-index files")
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
    }
}

private struct RecentRow: View {
    let file: FileItem
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(nsImage: file.fileIcon)
                    .resizable()
                    .frame(width: 18, height: 18)
                Text(file.name)
                    .font(Typo.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 12)
                Text(file.formattedDate)
                    .font(Typo.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Theme.softFill : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(file.path)
    }
}

private struct FilterExample: Identifiable {
    let snippet: String
    let meaning: String
    var id: String { snippet }

    static let all = [
        FilterExample(snippet: "size:>10mb", meaning: "Files over 10 MB"),
        FilterExample(snippet: "kind:pdf", meaning: "Only PDFs. Also kind:images or ext:png,jpg"),
        FilterExample(snippet: "modified:week", meaning: "Changed in the past week. Also 3d, 2w, 6m"),
        FilterExample(snippet: "size:1mb..50mb", meaning: "Between 1 and 50 MB")
    ]
}

private struct FilterExampleRow: View {
    let example: FilterExample
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(example.snippet)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(width: 150, alignment: .leading)
                Text(example.meaning)
                    .font(Typo.caption)
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Theme.softFill : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Add \(example.snippet) to the search")
    }
}

private struct ShortcutHint: View {
    let keys: [String]
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { Kbd($0) }
            }
            Text(label)
                .font(Typo.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Shown when a query returns nothing. Says whether a filter is the cause and offers to clear it.
struct NoResultsView: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.parsedQuery.text.isEmpty
                 ? "No files match these filters"
                 : "No files match \u{201C}\(viewModel.parsedQuery.text)\u{201D}")
                .font(.system(size: 17, weight: .medium))

            if viewModel.hasActiveFilters && viewModel.matchesWithoutFilters > 0 {
                HStack(spacing: 4) {
                    Text("\(Format.count(viewModel.matchesWithoutFilters)) files match without the filters (\(viewModel.activeFilterSummary)).")
                        .foregroundColor(.secondary)
                    Button("Clear filters") { viewModel.clearFilters() }
                        .buttonStyle(LinkButtonStyle())
                }
                .font(Typo.body)
            } else if viewModel.hasActiveFilters {
                HStack(spacing: 4) {
                    Text("Active filters: \(viewModel.activeFilterSummary).")
                        .foregroundColor(.secondary)
                    Button("Clear filters") { viewModel.clearFilters() }
                        .buttonStyle(LinkButtonStyle())
                }
                .font(Typo.body)
            } else {
                Text(viewModel.isIndexing
                     ? "McFind is still indexing, so some files may not appear yet."
                     : "Check the spelling, or search for part of the name. Use * as a wildcard, for example report*.pdf.")
                    .font(Typo.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: 440, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 22)
    }
}
