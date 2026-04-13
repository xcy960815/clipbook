import Foundation

extension NSRect {
  static func centered(ofSize size: NSSize, in frame: NSRect) -> NSRect {
    let bottomLeftX = (frame.width - size.width) / 2 + frame.minX
    let bottomLeftY = (frame.height - size.height) / 2 + frame.minY

    return NSRect(x: bottomLeftX + 1.0, y: bottomLeftY + 1.0, width: size.width, height: size.height)
  }

  static func clampedOrigin(ofSize size: NSSize, in frame: NSRect, proposedOrigin: NSPoint) -> NSPoint {
    let maxX = max(frame.minX, frame.maxX - size.width)
    let maxY = max(frame.minY, frame.maxY - size.height)

    return NSPoint(
      x: min(max(proposedOrigin.x, frame.minX), maxX),
      y: min(max(proposedOrigin.y, frame.minY), maxY)
    )
  }
}
