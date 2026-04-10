import AppKit.NSEvent
import Defaults
import Foundation

enum DoubleClickModifierKey: String, CaseIterable, Defaults.Serializable {
  case none
  case option
  case shift
  case control

  static let selectableCases: [Self] = [.option, .shift, .control]

  var displayName: String {
    switch self {
    case .none:
      return ""
    case .option:
      return "Option"
    case .shift:
      return "Shift"
    case .control:
      return "Control"
    }
  }

  var modifierFlags: NSEvent.ModifierFlags {
    switch self {
    case .none:
      return []
    case .option:
      return [.option]
    case .shift:
      return [.shift]
    case .control:
      return [.control]
    }
  }

  static func standaloneKey(for modifiers: NSEvent.ModifierFlags) -> Self? {
    let modifiers = modifiers.intersection(.deviceIndependentFlagsMask)
    return selectableCases.first(where: { $0.modifierFlags == modifiers })
  }
}

struct DoubleClickModifierKeyDetector {
  private let doubleClickInterval: TimeInterval

  private var activeKey: DoubleClickModifierKey = .none
  private var lastStandaloneTap: (key: DoubleClickModifierKey, time: Date)?
  private var currentPressUsedWithChord = false

  init(doubleClickInterval: TimeInterval = 0.35) {
    self.doubleClickInterval = doubleClickInterval
  }

  mutating func reset() {
    activeKey = .none
    lastStandaloneTap = nil
    currentPressUsedWithChord = false
  }

  mutating func handleKeyDown() {
    if activeKey == .none {
      lastStandaloneTap = nil
    } else {
      currentPressUsedWithChord = true
    }
  }

  mutating func handleFlagsChanged(
    _ modifiers: NSEvent.ModifierFlags,
    now: Date = .now
  ) -> DoubleClickModifierKey? {
    let modifiers = modifiers.intersection(.deviceIndependentFlagsMask)

    if activeKey == .none {
      if let key = DoubleClickModifierKey.standaloneKey(for: modifiers) {
        activeKey = key
        currentPressUsedWithChord = false
      } else if !modifiers.isEmpty {
        lastStandaloneTap = nil
      }
      return nil
    }

    if !modifiers.isDisjoint(with: activeKey.modifierFlags) {
      if modifiers != activeKey.modifierFlags {
        currentPressUsedWithChord = true
      }
      return nil
    }

    let releasedKey = activeKey
    activeKey = .none
    defer {
      currentPressUsedWithChord = false
    }

    guard !currentPressUsedWithChord else {
      lastStandaloneTap = nil
      return nil
    }

    if let lastStandaloneTap,
       lastStandaloneTap.key == releasedKey,
       now.timeIntervalSince(lastStandaloneTap.time) < doubleClickInterval {
      self.lastStandaloneTap = nil
      return releasedKey
    }

    lastStandaloneTap = (releasedKey, now)
    return nil
  }
}
