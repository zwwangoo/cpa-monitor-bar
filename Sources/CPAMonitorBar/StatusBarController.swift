import AppKit
import Combine
import SwiftUI

enum PanelDisplayAnchor {
    case statusItem
    case pointer
}

@MainActor
final class StatusBarController: NSObject, NSWindowDelegate {
    let panel = MonitorPanel()

    private let statusItem: NSStatusItem
    private let model: MonitorViewModel
    private let presentation: MonitorWindowPresentation
    private var hostingController: NSHostingController<MonitorPanelContent>?
    private var cancellables = Set<AnyCancellable>()

    init(
        model: MonitorViewModel,
        presentation: MonitorWindowPresentation
    ) {
        self.model = model
        self.presentation = presentation
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureMonitorPanel(panel, isPinned: presentation.isPinned)
        let content = MonitorPanelContent(
            model: model,
            windowPresentation: presentation,
            onTogglePin: { [weak self] in self?.togglePin() }
        )
        let hostingController = NSHostingController(rootView: content)
        hostingController.sizingOptions = [.preferredContentSize]
        self.hostingController = hostingController
        installContentView(hostingController.view)
        panel.delegate = self

        configureStatusButton()
        observeModelStatus()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func togglePin() {
        presentation.togglePin()
        configureMonitorPanel(panel, isPinned: presentation.isPinned)
        if !presentation.isPinned, panel.isVisible {
            positionPanelUnderStatusItem()
        }
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePanel as () -> Void)
        button.sendAction(on: [.leftMouseUp])
        updateStatusButton()
    }

    private func observeModelStatus() {
        model.objectWillChange
            .sink { [weak self] in
                DispatchQueue.main.async {
                    self?.updateStatusButton()
                    self?.resizePanelToFit()
                }
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

    @objc func togglePanel() {
        togglePanel(anchor: .statusItem)
    }

    func togglePanel(anchor: PanelDisplayAnchor) {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel(anchor: anchor)
        }
    }

    private func showPanel(anchor: PanelDisplayAnchor) {
        resizePanelToFit()
        if !presentation.isPinned {
            switch anchor {
            case .statusItem:
                positionPanelUnderStatusItem()
            case .pointer:
                positionPanelNearPointer()
            }
        }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func installContentView(_ hostedView: NSView) {
        let background = makeMonitorPanelBackground()
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: background.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        panel.contentView = background
        resizePanelToFit()
    }

    private func resizePanelToFit() {
        guard let hostedView = hostingController?.view else { return }
        hostedView.layoutSubtreeIfNeeded()
        let fittingSize = hostedView.fittingSize
        guard fittingSize.width > 0, fittingSize.height > 0 else { return }
        panel.setContentSize(NSSize(
            width: ceil(fittingSize.width),
            height: ceil(fittingSize.height)
        ))
    }

    private func positionPanelUnderStatusItem() {
        guard let button = statusItem.button else { return }
        let pointer = NSEvent.mouseLocation
        guard let screen = button.window?.screen
            ?? NSScreen.screens.first(where: { $0.frame.contains(pointer) })
            ?? NSScreen.main else { return }
        let buttonFrame = screenFrame(of: button)
        let anchorFrame = if let buttonFrame,
                             buttonFrame.maxY >= screen.visibleFrame.maxY - 1 {
            buttonFrame
        } else {
            NSRect(
                x: pointer.x,
                y: screen.visibleFrame.maxY,
                width: 0,
                height: 0
            )
        }
        let visibleFrame = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let proposedX = anchorFrame.midX - panel.frame.width / 2
        let x = min(max(proposedX, visibleFrame.minX), visibleFrame.maxX - panel.frame.width)
        let proposedY = anchorFrame.minY - panel.frame.height - 6
        let y = max(proposedY, visibleFrame.minY)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func positionPanelNearPointer() {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) })
            ?? NSScreen.main else { return }
        let origin = PanelPointerPlacement.origin(
            panelSize: panel.frame.size,
            pointer: pointer,
            visibleFrame: screen.visibleFrame
        )
        panel.setFrameOrigin(origin)
    }

    private func screenFrame(of view: NSView) -> NSRect? {
        guard let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }

    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  !presentation.isPinned,
                  !panel.isKeyWindow else { return }
            panel.orderOut(nil)
        }
    }
}
