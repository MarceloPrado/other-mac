import AppKit

enum MenuBarIcon {
  static func make() -> NSImage {
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
      NSColor.black.setStroke()

      let left = NSBezierPath(
        roundedRect: NSRect(x: 1.2, y: 4.6, width: 6.1, height: 7.2),
        xRadius: 1.4,
        yRadius: 1.4
      )
      left.lineWidth = 1.5
      left.stroke()

      let right = NSBezierPath(
        roundedRect: NSRect(x: 10.7, y: 4.6, width: 6.1, height: 7.2),
        xRadius: 1.4,
        yRadius: 1.4
      )
      right.lineWidth = 1.5
      right.stroke()

      let hop = NSBezierPath()
      hop.move(to: NSPoint(x: 6.5, y: 12.4))
      hop.curve(
        to: NSPoint(x: 12.1, y: 12.4),
        controlPoint1: NSPoint(x: 7.8, y: 16.2),
        controlPoint2: NSPoint(x: 10.8, y: 16.2)
      )
      hop.lineWidth = 1.5
      hop.lineCapStyle = .round
      hop.stroke()

      let arrow = NSBezierPath()
      arrow.move(to: NSPoint(x: 10.2, y: 13.3))
      arrow.line(to: NSPoint(x: 12.3, y: 12.3))
      arrow.line(to: NSPoint(x: 11.1, y: 10.5))
      arrow.lineWidth = 1.5
      arrow.lineCapStyle = .round
      arrow.lineJoinStyle = .round
      arrow.stroke()

      return rect.width > 0
    }

    image.isTemplate = true
    image.accessibilityDescription = "Other Mac"
    return image
  }
}
