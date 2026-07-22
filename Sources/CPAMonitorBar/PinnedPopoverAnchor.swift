import AppKit

@MainActor
final class PinnedPopoverAnchor {
    let window: NSWindow
    let positioningView: NSView

    private var dragStartOrigin: NSPoint?

    init(frame: NSRect) {
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let positioningView = NSView(
            frame: NSRect(origin: .zero, size: frame.size)
        )

        window.contentView = positioningView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isExcludedFromWindowsMenu = true
        window.isReleasedWhenClosed = false
        window.level = .statusBar
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
        window.orderFrontRegardless()

        self.window = window
        self.positioningView = positioningView
    }

    func drag(translation: CGSize, ended: Bool) {
        let start = dragStartOrigin ?? window.frame.origin
        dragStartOrigin = start
        window.setFrameOrigin(NSPoint(
            x: start.x + translation.width,
            y: start.y - translation.height
        ))
        if ended { dragStartOrigin = nil }
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }
}
