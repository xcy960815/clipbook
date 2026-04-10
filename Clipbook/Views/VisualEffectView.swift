import SwiftUI

struct VisualEffectView: NSViewRepresentable {
  let visualEffectView = NSVisualEffectView()

  var material: NSVisualEffectView.Material = .popover
  var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

  func makeNSView(context: Context) -> NSVisualEffectView {
    return visualEffectView
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
  }
}

@available(macOS 26.0, *)
struct GlassEffectView: View {
  // Xcode 16.2 does not expose NSGlassEffectView yet, so fall back to the
  // regular visual effect view while keeping the macOS 26 call sites intact.
  var body: some View {
    VisualEffectView(
      material: .popover,
      blendingMode: .behindWindow
    )
  }
}

#Preview {
  VisualEffectView(
    material: .popover,
    blendingMode: .behindWindow
  )
}
