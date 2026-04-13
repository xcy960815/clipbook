import SwiftUI

private struct HoverSelectionModifier: ViewModifier {
  @EnvironmentObject private var appState: AppState
  var id: UUID

  func body(content: Content) -> some View {
    content.onHover { hovering in
      guard hovering else { return }
      guard !appState.navigator.isMultiSelectInProgress else { return }

      if appState.navigator.isKeyboardNavigating {
        // Switch to mouse-driven selection immediately so the highlight
        // follows the pointer without waiting for a separate mouse-move event.
        appState.navigator.hoverSelectionWhileKeyboardNavigating = nil
        appState.navigator.isKeyboardNavigating = false
      }

      appState.navigator.selectWithoutScrolling(id: id)
    }
  }
}

extension View {
  func hoverSelectionId(_ id: UUID) -> some View {
    modifier(HoverSelectionModifier(id: id))
  }
}
