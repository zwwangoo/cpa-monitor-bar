import AppKit
import SwiftUI

@MainActor
final class MonitorPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = true
        isMovableByWindowBackground = false
        isExcludedFromWindowsMenu = true
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
func configureMonitorPanel(_ panel: NSPanel, isPinned: Bool) {
    var behavior = panel.collectionBehavior
    behavior.subtract([
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
        .moveToActiveSpace,
        .stationary,
    ])
    behavior.formUnion(isPinned
        ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        : [.moveToActiveSpace])
    panel.collectionBehavior = behavior
    panel.level = isPinned ? .floating : .statusBar
    panel.hidesOnDeactivate = false
}

@MainActor
func makeMonitorPanelBackground() -> NSVisualEffectView {
    let background = NSVisualEffectView()
    background.material = .popover
    background.blendingMode = .behindWindow
    background.state = .active
    background.wantsLayer = true
    background.layer?.cornerRadius = 12
    background.layer?.masksToBounds = true
    return background
}

@MainActor
final class MonitorPanelDragView: NSView {
    typealias DragAction = (NSWindow, NSEvent) -> Void

    private let dragAction: DragAction

    init(dragAction: @escaping DragAction) {
        self.dragAction = dragAction
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragAction(window, event)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}

@MainActor
struct MonitorPanelDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> MonitorPanelDragView {
        MonitorPanelDragView { window, event in
            window.performDrag(with: event)
        }
    }

    func updateNSView(_ view: MonitorPanelDragView, context: Context) {}
}
