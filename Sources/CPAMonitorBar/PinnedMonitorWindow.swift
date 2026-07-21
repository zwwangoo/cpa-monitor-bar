import AppKit
import SwiftUI

@MainActor
func configurePinnedMonitorWindow(_ window: NSWindow) {
    window.identifier = NSUserInterfaceItemIdentifier(MonitorWindowPresentation.pinnedWindowID)
    window.styleMask.insert(.fullSizeContentView)
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.level = .floating
    window.isMovableByWindowBackground = true
    window.collectionBehavior.insert([.moveToActiveSpace, .fullScreenAuxiliary])
    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
}

struct PinnedMonitorWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configureWhenAttached(view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        configureWhenAttached(view)
    }

    private func configureWhenAttached(_ view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configurePinnedMonitorWindow(window)
        }
    }
}
