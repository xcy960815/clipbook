import Combine
import Defaults
import Logging
import SwiftUI

enum SlideoutState {
  case opening
  case closing
  case open
  case closed

  var isAnimating: Bool {
    switch self {
    case .closed, .open:
      return false
    case .opening, .closing:
      return true
    }
  }

  var isOpen: Bool {
    switch self {
    case .open, .opening:
      return true
    case .closed, .closing:
      return false
    }
  }

  fileprivate func toggleWithAnimation() -> SlideoutState {
    switch self {
    case .open, .opening:
      return .closing
    case .closed, .closing:
      return .opening
    }
  }

  func animationDone() -> SlideoutState {
    switch self {
    case .open, .opening:
      return .open
    case .closed, .closing:
      return .closed
    }
  }
}

enum SlideoutPlacement {
  case left
  case right
}

enum SlideoutToggleTrigger {
  case autoOpen
  case manual
}

enum ResizingMode {
  case none
  case content
  case slideout
}

final class SlideoutController: ObservableObject {
  let logger = Logger(label: "org.p0deje.Clipbook")
  private static let animationDuration = 0.25

  let onContentResize: (CGFloat) -> Void
  let onSlideoutResize: (CGFloat) -> Void

  let minimumContentWidth: CGFloat = 200
  @Published var contentResizeWidth: CGFloat = 0
  @Published var contentAnimationWidth: CGFloat?

  let minimumSlideoutWidth: CGFloat = 200
  @Published var slideoutResizeWidth: CGFloat = 0

  private var _contentWidth: CGFloat = 0
  var contentWidth: CGFloat {
    get { return _contentWidth }
    set {
      let clampedWidth = max(minimumContentWidth, newValue).rounded()
      guard _contentWidth != clampedWidth else { return }
      objectWillChange.send()
      _contentWidth = clampedWidth
      onContentResize(_contentWidth)
    }
  }
  private var _slideoutWidth: CGFloat = 400
  var slideoutWidth: CGFloat {
    get { return _slideoutWidth }
    set {
      let clampedWidth = max(minimumSlideoutWidth, newValue).rounded()
      guard _slideoutWidth != clampedWidth else { return }
      objectWillChange.send()
      _slideoutWidth = clampedWidth
      onSlideoutResize(_slideoutWidth)
    }
  }

  @Published var placement: SlideoutPlacement = .right
  @Published var state: SlideoutState = .closed
  @Published var resizingMode: ResizingMode = .none

  var nswindow: NSWindow? {
    return AppState.shared.appDelegate?.panel
  }

  private var windowAnimationOrigin: CGPoint?
  private var windowAnimationOriginBaseState: SlideoutState = .closed

  private var autoOpenTask: Task<Void, Never>?
  private var autoOpenSuppressed = false
  private var autoOpenEnabled = true

  init(onContentResize: @escaping (CGFloat) -> Void, onSlideoutResize: @escaping (CGFloat) -> Void) {
    self.onContentResize = onContentResize
    self.onSlideoutResize = onSlideoutResize
  }

  private func togglePreviewStateWithAnimation(windowFrame: NSRect) {
    let newValue = state.toggleWithAnimation()
    if !state.isAnimating && newValue.isAnimating {
      contentAnimationWidth = contentWidth
      windowAnimationOrigin = windowFrame.origin
      windowAnimationOriginBaseState = state
    }
    state = newValue
  }

  func computePlacement(window: NSWindow, for size: NSSize) -> SlideoutPlacement {
    guard let screen = window.screen?.visibleFrame else { return placement }
    let windowFrame = window.frame
    let rightMaxX = windowFrame.minX + size.width
    if rightMaxX <= screen.maxX {
      return .right
    }

    let leftMinX = windowFrame.minX - slideoutWidth
    if leftMinX >= screen.minX {
      return .left
    }

    let rightOverflow = rightMaxX - screen.maxX
    let leftOverflow = screen.minX - leftMinX
    return leftOverflow < rightOverflow ? .left : .right
  }

  func computeSizeWithPreview(_ size: NSSize, state newState: SlideoutState) -> NSSize {
    var newSize = size
    if newState.isOpen {
      newSize.width += slideoutWidth
    }
    let popup = AppState.shared.popup
    newSize.height = popup.preferredHeight(for: popup.height)
    return newSize
  }

  func togglePreview(trigger: SlideoutToggleTrigger = .manual) {
    if !state.isOpen {
      let navigator = AppState.shared.navigator
      guard navigator.leadHistoryItem != nil || navigator.pasteStackSelected else { return }
    }

    if trigger == .manual {
      if state.isOpen {
        autoOpenSuppressed = true
      } else {
        autoOpenSuppressed = false
      }
    }

    cancelAutoOpen()
    withAnimation(.easeInOut(duration: Self.animationDuration)) {
      if let window = nswindow {
        togglePreviewStateWithAnimation(windowFrame: window.frame)
        var newSize = window.frame.size
        newSize.width = contentWidth
        newSize = computeSizeWithPreview(newSize, state: self.state)
        if state.isOpen {
          placement = computePlacement(window: window, for: newSize)
        }

        let expectedAnimationState = state
        NSAnimationContext.runAnimationGroup { (context) in
          var newOrigin = windowAnimationOrigin ?? window.frame.origin
          newOrigin.y += (window.frame.height - newSize.height)

          if placement == .left {
            if windowAnimationOriginBaseState == .closed && state.isOpen {
              newOrigin.x -= slideoutWidth
            } else if windowAnimationOriginBaseState == .open
              && !state.isOpen {
              newOrigin.x += slideoutWidth
            }
            // Otherwise the base is the desired position
          }
          context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
          context.completionHandler = {
            if self.state == expectedAnimationState {
              self.state = expectedAnimationState.animationDone()
            }
          }
          context.duration = Self.animationDuration
          if let visibleFrame = window.screen?.visibleFrame {
            newOrigin = NSRect.clampedOrigin(
              ofSize: newSize,
              in: visibleFrame,
              proposedOrigin: newOrigin
            )
          }
          window.animator().setFrame(
            NSRect(origin: newOrigin, size: newSize),
            display: true
          )
        }
      }
    }
  }

  func startResize(mode: ResizingMode) {
    logger.info("Starting resize with mode \(mode)")
    resizingMode = mode
    contentWidth = contentResizeWidth
    slideoutWidth = slideoutResizeWidth
  }

  func endResize() {
    logger.info("Ended resize. Mode was \(resizingMode)")
    switch resizingMode {
    case .none:
      return
    case .content:
      contentWidth = contentResizeWidth
    case .slideout:
      slideoutWidth = slideoutResizeWidth
    }
    resizingMode = .none
  }

  func startAutoOpen() {
    cancelAutoOpen()

    guard autoOpenEnabled else { return }
    guard !autoOpenSuppressed else { return }
    guard !state.isOpen else { return }

    autoOpenTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: UInt64(Defaults[.previewDelay]) * 1_000_000)
      guard !Task.isCancelled else { return }

      if !state.isOpen {
        togglePreview(trigger: .autoOpen)
      }
    }
  }

  func cancelAutoOpen() {
    autoOpenTask?.cancel()
    autoOpenTask = nil
  }

  func enableAutoOpen() {
    autoOpenEnabled = true
  }

  func disableAutoOpen() {
    autoOpenEnabled = false
    cancelAutoOpen()
  }

  func resetAutoOpenSuppression() {
    autoOpenSuppressed = false
  }
}
