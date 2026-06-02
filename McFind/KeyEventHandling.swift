import SwiftUI
import AppKit

struct KeyEventHandler: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> NSView {
        let view = KeyHandlerView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? KeyHandlerView {
            view.onKeyDown = onKeyDown
        }
    }

    class KeyHandlerView: NSView {
        var onKeyDown: ((NSEvent) -> Bool)?
        private var eventMonitor: Any?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            setupEventMonitor()
            if let searchField = findSearchField() {
                window?.makeFirstResponder(searchField)
            }
        }

        private func setupEventMonitor() {
            guard let window = window, eventMonitor == nil else { return }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { return event }

                // Let command-key combos through (cmd+Q, cmd+W, cmd+C, etc.)
                if event.modifierFlags.contains(.command) {
                    return event
                }

                // Try the custom handler first (arrows, escape)
                if let handler = self.onKeyDown, handler(event) {
                    return nil
                }

                // If a text field is being edited (e.g., rename, search field), don't redirect
                if window.firstResponder is NSTextView {
                    return event
                }

                // Redirect printable character input to search field
                if let searchField = self.findSearchField() {
                    let isActive = window.firstResponder === searchField ||
                        window.firstResponder === searchField.currentEditor()
                    if !isActive {
                        window.makeFirstResponder(searchField)
                    }
                }

                return event
            }
        }

        deinit {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        private func findSearchField() -> NSTextField? {
            guard let contentView = window?.contentView else { return nil }
            return findTextField(in: contentView)
        }

        private func findTextField(in view: NSView) -> NSTextField? {
            for subview in view.subviews {
                if let textField = subview as? NSTextField, textField.isEditable {
                    return textField
                }
                if let found = findTextField(in: subview) {
                    return found
                }
            }
            return nil
        }
    }
}

extension View {
    func handleKeyEvents(_ handler: @escaping (NSEvent) -> Bool) -> some View {
        self.background(KeyEventHandler(onKeyDown: handler))
    }
}
