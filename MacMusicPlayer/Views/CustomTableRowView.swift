import Cocoa

class CustomTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        if self.selectionHighlightStyle != .none {
            super.drawSelection(in: dirtyRect)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bottomLine = NSBezierPath()
        NSColor.separatorColor.withAlphaComponent(0.2).setStroke()
        bottomLine.lineWidth = 0.5
        bottomLine.move(to: NSPoint(x: 10, y: 0))
        bottomLine.line(to: NSPoint(x: self.bounds.width - 10, y: 0))
        bottomLine.stroke()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        for trackingArea in self.trackingAreas {
            self.removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        self.wantsLayer = true

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        })
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().layer?.backgroundColor = NSColor.clear.cgColor
        })
    }
}
