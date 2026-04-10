import AppKit
import ApplicationServices

struct Accessibility {
  private static var hasAccessibilityAccess: Bool {
    AXIsProcessTrustedWithOptions(nil)
  }

  private static var hasListenEventAccess: Bool {
    if #available(macOS 10.15, *) {
      return CGPreflightListenEventAccess()
    }

    return hasAccessibilityAccess
  }

  private static var hasPostEventAccess: Bool {
    if #available(macOS 10.15, *) {
      return CGPreflightPostEventAccess()
    }

    return hasAccessibilityAccess
  }

  @discardableResult
  static func hasAccess(
    accessibility: Bool = false,
    listenEvent: Bool = false,
    postEvent: Bool = false
  ) -> Bool {
    let needsAccessibilityAccess = accessibility && !hasAccessibilityAccess
    let needsListenEventAccess = listenEvent && !hasListenEventAccess
    let needsPostEventAccess = postEvent && !hasPostEventAccess

    return !(needsAccessibilityAccess || needsListenEventAccess || needsPostEventAccess)
  }

  @discardableResult
  static func check(
    accessibility: Bool = false,
    listenEvent: Bool = false,
    postEvent: Bool = false,
    prompt: Bool = true
  ) -> Bool {
    guard !hasAccess(
      accessibility: accessibility,
      listenEvent: listenEvent,
      postEvent: postEvent
    ) else {
      return true
    }

    let needsAccessibilityAccess = accessibility && !hasAccessibilityAccess
    let needsListenEventAccess = listenEvent && !hasListenEventAccess
    let needsPostEventAccess = postEvent && !hasPostEventAccess

    guard prompt else {
      return false
    }

    if needsAccessibilityAccess {
      let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
      _ = AXIsProcessTrustedWithOptions(options)
    }

    if needsListenEventAccess, #available(macOS 10.15, *) {
      _ = CGRequestListenEventAccess()
    }

    if needsPostEventAccess, #available(macOS 10.15, *) {
      _ = CGRequestPostEventAccess()
    }

    return false
  }
}
