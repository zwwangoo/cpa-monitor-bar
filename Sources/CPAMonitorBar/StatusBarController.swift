import AppKit
import Combine
import SwiftUI

@MainActor
func configureMonitorPopoverWindow(_ window: NSWindow, isPinned: Bool) {
    var behavior = window.collectionBehavior
    behavior.subtract([.canJoinAllSpaces, .fullScreenAuxiliary, .moveToActiveSpace])
    behavior.formUnion(isPinned
        ? [.canJoinAllSpaces, .fullScreenAuxiliary]
        : [.moveToActiveSpace])
    window.collectionBehavior = behavior
    window.isMovable = false
}

@MainActor
final class StatusBarController: NSObject {
    let popover = NSPopover()

    private let statusItem: NSStatusItem
    private let model: MonitorViewModel
    private let presentation: MonitorWindowPresentation
    private var hostingController: NSHostingController<MonitorPopover>?
    private var pinnedAnchor: PinnedPopoverAnchor?
    private var cancellables = Set<AnyCancellable>()

    init(
        model: MonitorViewModel,
        presentation: MonitorWindowPresentation
    ) {
        self.model = model
        self.presentation = presentation
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureMonitorPopover(popover, isPinned: presentation.isPinned)
        popover.animates = true
        let content = MonitorPopover(
            model: model,
            windowPresentation: presentation,
            onTogglePin: { [weak self] in self?.togglePin() },
            onDragPinnedWindow: { [weak self] translation, ended in
                self?.pinnedAnchor?.drag(translation: translation, ended: ended)
            }
        )
        let hostingController = NSHostingController(rootView: content)
        hostingController.sizingOptions = [.preferredContentSize]
        self.hostingController = hostingController
        popover.contentViewController = hostingController

        configureStatusButton()
        observeModelStatus()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func togglePin() {
        presentation.togglePin()
        configureMonitorPopover(popover, isPinned: presentation.isPinned)
        if presentation.isPinned {
            installPinnedAnchorIfPossible()
        } else {
            restoreStatusItemAnchor()
        }
        configurePopoverWindowIfAvailable()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp])
        updateStatusButton()
    }

    private func observeModelStatus() {
        model.objectWillChange
            .sink { [weak self] in
                DispatchQueue.main.async { self?.updateStatusButton() }
            }
            .store(in: &cancellables)
    }

    private func updateStatusButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(
            systemSymbolName: model.statusSymbol,
            accessibilityDescription: model.statusText
        )
        image?.isTemplate = true
        button.image = image
        button.toolTip = "CPA Monitor Bar · \(model.statusText)"
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        if presentation.isPinned {
            installPinnedAnchorIfPossible()
        }
        if let pinnedAnchor {
            showPopover(relativeTo: pinnedAnchor.positioningView)
        } else {
            showPopover(relativeTo: button)
        }
        configurePopoverWindowIfAvailable()
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showPopover(relativeTo view: NSView) {
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    private func installPinnedAnchorIfPossible() {
        guard pinnedAnchor == nil,
              let button = statusItem.button,
              let frame = screenFrame(of: button) else { return }
        let anchor = PinnedPopoverAnchor(frame: frame)
        pinnedAnchor = anchor
        if popover.isShown {
            showPopover(relativeTo: anchor.positioningView)
        }
    }

    private func restoreStatusItemAnchor() {
        if popover.isShown, let button = statusItem.button {
            showPopover(relativeTo: button)
        }
        pinnedAnchor?.close()
        pinnedAnchor = nil
    }

    private func screenFrame(of view: NSView) -> NSRect? {
        guard let window = view.window else { return nil }
        let frameInWindow = view.convert(view.bounds, to: nil)
        return window.convertToScreen(frameInWindow)
    }

    private func configurePopoverWindowIfAvailable() {
        guard let window = popover.contentViewController?.view.window else { return }
        configureMonitorPopoverWindow(window, isPinned: presentation.isPinned)
    }
}
