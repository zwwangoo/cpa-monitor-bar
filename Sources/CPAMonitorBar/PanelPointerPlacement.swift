import AppKit

enum PanelPointerPlacement {
    private static let screenMargin: CGFloat = 8
    private static let pointerGap: CGFloat = 12

    static func origin(
        panelSize: NSSize,
        pointer: NSPoint,
        visibleFrame: NSRect
    ) -> NSPoint {
        let horizontalBounds = bounds(
            minimum: visibleFrame.minX + screenMargin,
            maximum: visibleFrame.maxX - screenMargin - panelSize.width
        )
        let verticalBounds = bounds(
            minimum: visibleFrame.minY + screenMargin,
            maximum: visibleFrame.maxY - screenMargin - panelSize.height
        )
        let proposedX = pointer.x - panelSize.width / 2
        let belowPointer = pointer.y - pointerGap - panelSize.height
        let abovePointer = pointer.y + pointerGap
        let proposedY = belowPointer >= verticalBounds.lowerBound
            ? belowPointer
            : abovePointer

        return NSPoint(
            x: clamp(proposedX, to: horizontalBounds),
            y: clamp(proposedY, to: verticalBounds)
        )
    }

    private static func bounds(minimum: CGFloat, maximum: CGFloat) -> ClosedRange<CGFloat> {
        minimum...max(minimum, maximum)
    }

    private static func clamp(_ value: CGFloat, to bounds: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, bounds.lowerBound), bounds.upperBound)
    }
}
