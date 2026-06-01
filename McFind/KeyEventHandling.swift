import SwiftUI
import AppKit

struct KeyEventHandler: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> NSView {
        let view = KeyHandlerView()
        view.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? KeyHandlerView {
            view.onKeyDown = onKeyDown
        }
    }

    class KeyHandlerView: NSView {
        var onKeyDown: ((NSEvent) -> Bool)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            if let handler = onKeyDown, handler(event) {
                return
            }
            super.keyDown(with: event)
        }
    }
}

extension View {
    func handleKeyEvents(_ handler: @escaping (NSEvent) -> Bool) -> some View {
        self.background(KeyEventHandler(onKeyDown: handler))
    }
}
