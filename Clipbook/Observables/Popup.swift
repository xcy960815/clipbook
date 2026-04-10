import AppKit.NSRunningApplication
import CoreGraphics
import Defaults
import KeyboardShortcuts
import Observation

enum PopupState {
  // Default; shortcut will toggle the popup
  case toggle
  // In this mode, every additional press of the main key
  // will cycle to the next item in the paste history list.
  // Releasing the modifier keys will accept selection and close the popup
  case cycle
  // Transition state when the shortcut is first pressed and
  // we don't know whether we are in "toggle" or "cycle" mode.
  case opening
}

enum PopupOpenTriggerConfiguration: Equatable {
  case disabled
  case regularShortcut
  case doubleClick
}

@Observable
class Popup {
  static let verticalSeparatorPadding = 6.0
  static let horizontalSeparatorPadding = 6.0
  static let verticalPadding: CGFloat = 5
  static let horizontalPadding: CGFloat = 5
  static let minimumPreviewHeight: CGFloat = 150

  // Radius used for items inset by the padding. Ensures they visually have the same curvature
  // as the menu.
  static let cornerRadius: CGFloat = if #available(macOS 26.0, *) {
    7
  } else {
    4
  }

  static let itemHeight: CGFloat = if #available(macOS 26.0, *) {
    24
  } else {
    22
  }

  var needsResize = false
  var height: CGFloat = 0
  var headerHeight: CGFloat = 0
  var extraTopHeight: CGFloat = 0
  var extraBottomHeight: CGFloat = 0
  var footerHeight: CGFloat = 0

  @ObservationIgnored
  private var popupEventsMonitor: Any?

  @ObservationIgnored
  private var doubleClickLocalMonitor: Any?

  @ObservationIgnored
  private var doubleClickGlobalMonitor = DoubleClickGlobalMonitor()

  @ObservationIgnored
  private var appDidBecomeActiveObserver: NSObjectProtocol?

  private var state: PopupState = .toggle
  private var isSettingsWindowPresented = false

  @ObservationIgnored
  private var doubleClickKeyDetector = DoubleClickModifierKeyDetector()

  private var isDoubleClickPopupRequested: Bool {
    Defaults[.doubleClickPopupEnabled] || CommandLine.arguments.contains("enable-double-click-option-key")
  }

  private var doubleClickModifierKey: DoubleClickModifierKey {
    if CommandLine.arguments.contains("enable-double-click-option-key") {
      return .option
    }

    return Defaults[.doubleClickModifierKey]
  }

  private var hasDoubleClickAccess: Bool {
    Accessibility.hasAccess(accessibility: true, listenEvent: true)
  }

  private var openTriggerConfiguration: PopupOpenTriggerConfiguration {
    Self.openTriggerConfiguration(
      isSettingsWindowPresented: isSettingsWindowPresented,
      isDoubleClickPopupRequested: isDoubleClickPopupRequested,
      doubleClickModifierKey: doubleClickModifierKey,
      hasDoubleClickAccess: hasDoubleClickAccess
    )
  }

  init() {
    KeyboardShortcuts.onKeyDown(for: .popup, action: handleFirstKeyDown)
    initEventsMonitor()
    refreshOpenTriggerConfiguration()

    Task { @MainActor in
      for await _ in Defaults.updates(.doubleClickPopupEnabled, initial: false) {
        refreshOpenTriggerConfiguration()
      }
    }

    Task { @MainActor in
      for await _ in Defaults.updates(.doubleClickModifierKey, initial: false) {
        refreshOpenTriggerConfiguration()
      }
    }

    appDidBecomeActiveObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.refreshOpenTriggerConfiguration()
    }
  }

  deinit {
    deinitEventsMonitor()
    deinitDoubleClickMonitors()
    if let appDidBecomeActiveObserver {
      NotificationCenter.default.removeObserver(appDidBecomeActiveObserver)
    }
  }

  func initEventsMonitor() {
    guard popupEventsMonitor == nil else { return }

    self.popupEventsMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.flagsChanged, .keyDown],
      handler: handleEvent
    )
  }

  func deinitEventsMonitor() {
    guard let popupEventsMonitor else { return }

    NSEvent.removeMonitor(popupEventsMonitor)
    self.popupEventsMonitor = nil
  }

  func initDoubleClickMonitors() {
    if doubleClickLocalMonitor == nil {
      doubleClickLocalMonitor = NSEvent.addLocalMonitorForEvents(
        matching: [.flagsChanged, .keyDown]
      ) { [weak self] event in
        self?.handleDoubleClickMonitorEvent(event)
        return event
      }
    }

    doubleClickGlobalMonitor.onKeyDown = { [weak self] in
      self?.handleDoubleClickKeyDown()
    }
    doubleClickGlobalMonitor.onFlagsChanged = { [weak self] modifierFlags in
      self?.handleDoubleClickFlagsChanged(modifierFlags)
    }

    guard !doubleClickGlobalMonitor.isRunning else { return }
    guard Accessibility.check(accessibility: true, listenEvent: true) else { return }

    doubleClickGlobalMonitor.start()
  }

  func deinitDoubleClickMonitors() {
    if let doubleClickLocalMonitor {
      NSEvent.removeMonitor(doubleClickLocalMonitor)
      self.doubleClickLocalMonitor = nil
    }

    doubleClickGlobalMonitor.stop()
    doubleClickKeyDetector.reset()
  }

  func refreshOpenTriggerConfiguration() {
    switch openTriggerConfiguration {
    case .disabled:
      KeyboardShortcuts.disable(.popup)
      deinitDoubleClickMonitors()
    case .regularShortcut:
      KeyboardShortcuts.enable(.popup)
      deinitDoubleClickMonitors()
    case .doubleClick:
      KeyboardShortcuts.disable(.popup)
      initDoubleClickMonitors()
    }
  }

  func setSettingsWindowPresented(_ isPresented: Bool) {
    isSettingsWindowPresented = isPresented
    refreshOpenTriggerConfiguration()
  }

  func open(height: CGFloat, at popupPosition: PopupPosition = Defaults[.popupPosition]) {
    AppState.shared.appDelegate?.panel.open(height: height, at: popupPosition)
  }

  func reset() {
    state = .toggle
    refreshOpenTriggerConfiguration()
  }

  func close() {
    AppState.shared.appDelegate?.panel.close()  // close() calls reset
  }

  func isClosed() -> Bool {
    AppState.shared.appDelegate?.panel.isPresented != true
  }

  func preferredHeight(for newHeight: CGFloat) -> CGFloat {
    var height = newHeight

    var minimumHeight = 0.0
    // If the preview is non-empty make sure the window accomodates for it to be visible.
    if AppState.shared.preview.state.isOpen && AppState.shared.navigator.leadSelection != nil {
      minimumHeight += Self.minimumPreviewHeight
    }
    minimumHeight = max(headerHeight + Self.verticalPadding, minimumHeight)

    height = max(height, minimumHeight)
    height = min(height, Defaults[.windowSize].height)
    return height
  }

  func resize(height: CGFloat) {
    self.height = height + headerHeight + extraTopHeight + extraBottomHeight + footerHeight
    AppState.shared.appDelegate?.panel.verticallyResize(to: preferredHeight(for: self.height))
    needsResize = false
  }

  private func handleFirstKeyDown() {
    guard openTriggerConfiguration == .regularShortcut else {
      return
    }

    if isClosed() {
      open(height: height)
      state = .opening
      KeyboardShortcuts.disable(.popup)  // Handle events via eventsMonitor. Re-enable on popup close
      return
    }

    // Clipbook was not opened via shortcut. We assume toggle mode and close it
    close()
  }

  private func handleEvent(_ event: NSEvent) -> NSEvent? {
    switch event.type {
    case .keyDown:
      return handleKeyDown(event)
    case .flagsChanged:
      return handleFlagsChanged(event)
    default:
      return event
    }
  }

  private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
    guard openTriggerConfiguration == .regularShortcut else {
      return event
    }

    if isHotKeyCode(Int(event.keyCode)) {
      if let item = History.shared.pressedShortcutItem {
        AppState.shared.navigator.select(item: item)
        Task { @MainActor in
          AppState.shared.history.select(item)
        }
        return nil
      }

      if state == .opening {
        state = .cycle
        // Next 'if' will highlight next item and then return nil
      }

      if state == .cycle {
        AppState.shared.navigator.highlightNext(allowCycle: true)
        return nil
      }

      if state == .toggle && isHotKeyModifiers(event.modifierFlags) {
        close()
        return nil
      }
    }

    return event
  }

  private func handleDoubleClickMonitorEvent(_ event: NSEvent) {
    switch event.type {
    case .keyDown:
      handleDoubleClickKeyDown()
    case .flagsChanged:
      handleDoubleClickFlagsChanged(event.modifierFlags)
    default:
      break
    }
  }

  private func handleDoubleClickKeyDown() {
    guard openTriggerConfiguration == .doubleClick else {
      return
    }

    doubleClickKeyDetector.handleKeyDown()
  }

  private func handleDoubleClickFlagsChanged(_ modifierFlags: NSEvent.ModifierFlags) {
    guard openTriggerConfiguration == .doubleClick else {
      return
    }

    if let key = doubleClickKeyDetector.handleFlagsChanged(modifierFlags),
       key == doubleClickModifierKey,
       key != .none {
      DispatchQueue.main.async {
        self.toggleWithDoubleClickKey()
      }
    }
  }

  private func toggleWithDoubleClickKey() {
    if isClosed() {
      open(height: height)
    } else {
      close()
    }
  }

  private func handleFlagsChanged(_ event: NSEvent) -> NSEvent? {
    guard openTriggerConfiguration == .regularShortcut else {
      return event
    }

    // If we are in cycle mode, releasing modifiers triggers a selection
    if state == .cycle && allModifiersReleased(event) {
      DispatchQueue.main.async {
        AppState.shared.select()
      }
      return nil
    }

    // Otherwise if in opening mode, enter toggle mode
    if state == .opening && allModifiersReleased(event) {
      state = .toggle
      return event
    }

    return event
  }

  private func isHotKeyCode(_ keyCode: Int) -> Bool {
    guard let shortcut = KeyboardShortcuts.Name.popup.shortcut else {
      return false
    }

    return shortcut.key?.rawValue == keyCode
  }

  private func isHotKeyModifiers(_ modifiers: NSEvent.ModifierFlags) -> Bool {
    guard let shortcut = KeyboardShortcuts.Name.popup.shortcut else {
      return false
    }

    return modifiers.intersection(.deviceIndependentFlagsMask) ==
      shortcut.modifiers.intersection(.deviceIndependentFlagsMask)
  }

  private func allModifiersReleased(_ event: NSEvent) -> Bool {
    return event.modifierFlags.isDisjoint(with: .deviceIndependentFlagsMask)
  }

  static func openTriggerConfiguration(
    isSettingsWindowPresented: Bool,
    isDoubleClickPopupRequested: Bool,
    doubleClickModifierKey: DoubleClickModifierKey,
    hasDoubleClickAccess: Bool
  ) -> PopupOpenTriggerConfiguration {
    if isSettingsWindowPresented {
      return .disabled
    }

    if isDoubleClickPopupRequested,
       doubleClickModifierKey != .none,
       hasDoubleClickAccess {
      return .doubleClick
    }

    return .regularShortcut
  }
}

private final class DoubleClickGlobalMonitor {
  var onKeyDown: (() -> Void)?
  var onFlagsChanged: ((NSEvent.ModifierFlags) -> Void)?

  var isRunning: Bool {
    eventTap != nil || fallbackMonitor != nil
  }

  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var fallbackMonitor: Any?

  func start() {
    guard !isRunning else { return }

    if startEventTap() {
      return
    }

    fallbackMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.flagsChanged, .keyDown]
    ) { [weak self] event in
      self?.handleFallbackEvent(event)
    }
  }

  func stop() {
    if let fallbackMonitor {
      NSEvent.removeMonitor(fallbackMonitor)
      self.fallbackMonitor = nil
    }

    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
      self.runLoopSource = nil
    }

    if let eventTap {
      CFMachPortInvalidate(eventTap)
      self.eventTap = nil
    }

    onKeyDown = nil
    onFlagsChanged = nil
  }

  private func startEventTap() -> Bool {
    let eventMask =
      (CGEventMask(1) << CGEventType.flagsChanged.rawValue) |
      (CGEventMask(1) << CGEventType.keyDown.rawValue)

    guard let eventTap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .listenOnly,
      eventsOfInterest: eventMask,
      callback: { _, type, event, userInfo in
        guard let userInfo else {
          return Unmanaged.passUnretained(event)
        }

        let monitor = Unmanaged<DoubleClickGlobalMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        return monitor.handleEventTapEvent(type: type, event: event)
      },
      userInfo: Unmanaged.passUnretained(self).toOpaque()
    ) else {
      return false
    }

    guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
      CFMachPortInvalidate(eventTap)
      return false
    }

    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)

    self.eventTap = eventTap
    self.runLoopSource = runLoopSource
    return true
  }

  private func handleFallbackEvent(_ event: NSEvent) {
    switch event.type {
    case .keyDown:
      onKeyDown?()
    case .flagsChanged:
      onFlagsChanged?(event.modifierFlags)
    default:
      break
    }
  }

  private func handleEventTapEvent(
    type: CGEventType,
    event: CGEvent
  ) -> Unmanaged<CGEvent>? {
    switch type {
    case .keyDown:
      onKeyDown?()
    case .flagsChanged:
      onFlagsChanged?(NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue)))
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
      if let eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }
    default:
      break
    }

    return Unmanaged.passUnretained(event)
  }
}
