import AppKit
import SwiftUI
import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Settings

struct GeneralSettingsPane: View {
  private let notificationsURL = URL(
    string: "x-apple.systempreferences:com.apple.preference.notifications?id=\(Bundle.main.bundleIdentifier ?? "")"
  )
  private let doubleClickLabel = NSLocalizedString(
    "DoubleClickOpen",
    tableName: "GeneralSettings",
    bundle: .main,
    value: "Double-click to open",
    comment: "Label for enabling double-click modifier key mode"
  )
  private let doubleClickPlaceholder = NSLocalizedString(
    "DoubleClickPlaceholder",
    tableName: "GeneralSettings",
    bundle: .main,
    value: "Set shortcut",
    comment: "Placeholder shown while waiting for a double-click modifier key"
  )
  private let resetSettingsTitle = NSLocalizedString(
    "ResetSettings",
    tableName: "GeneralSettings",
    bundle: .main,
    value: "Reset settings",
    comment: "Button label for resetting preferences"
  )
  private let resetSettingsMessage = NSLocalizedString(
    "ResetSettingsMessage",
    tableName: "GeneralSettings",
    bundle: .main,
    value: "Reset all settings to their defaults? Clipboard history will be kept.",
    comment: "Confirmation message for resetting settings"
  )
  private let resetSettingsConfirm = NSLocalizedString(
    "ResetSettingsConfirm",
    tableName: "GeneralSettings",
    bundle: .main,
    value: "Reset",
    comment: "Confirmation button title for resetting settings"
  )
  private let resetSettingsCancel = NSLocalizedString(
    "ResetSettingsCancel",
    tableName: "GeneralSettings",
    bundle: .main,
    value: "Cancel",
    comment: "Cancel button title for resetting settings"
  )

  @Default(.doubleClickPopupEnabled) private var doubleClickPopupEnabled
  @Default(.doubleClickModifierKey) private var doubleClickModifierKey
  @Default(.searchMode) private var searchMode

  @State private var copyModifier = HistoryItemAction.copy.modifierFlags.description
  @State private var pasteModifier = HistoryItemAction.paste.modifierFlags.description
  @State private var pasteWithoutFormatting = HistoryItemAction.pasteWithoutFormatting.modifierFlags.description

  @State private var doubleClickRecorder = DoubleClickModifierRecorder()
  @State private var showResetSettingsConfirmation = false
  @State private var updater = SoftwareUpdater()

  var body: some View {
    Settings.Container(contentWidth: 450) {
      Settings.Section(title: "", bottomDivider: true) {
        LaunchAtLogin.Toggle {
          Text("LaunchAtLogin", tableName: "GeneralSettings")
        }
        Toggle(isOn: $updater.automaticallyChecksForUpdates) {
          Text("CheckForUpdates", tableName: "GeneralSettings")
        }
        HStack(spacing: 8) {
          Button(
            action: { updater.checkForUpdates() },
            label: { Text("CheckNow", tableName: "GeneralSettings") }
          )
          Button(resetSettingsTitle, role: .destructive) {
            showResetSettingsConfirmation = true
          }
          Spacer(minLength: 0)
        }
      }

      Settings.Section(label: { Text("Open", tableName: "GeneralSettings") }) {
        HStack {
          if doubleClickPopupEnabled {
            ZStack(alignment: .trailing) {
              DoubleClickRecorderField(
                text: doubleClickModifierKey.displayName,
                placeholder: doubleClickPlaceholder
              )

              if doubleClickModifierKey != .none {
                Button(action: clearDoubleClickSelection) {
                  Color.clear
                    .frame(width: 24, height: 20)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
              }
            }
            .frame(width: DoubleClickRecorderField.minimumWidth)
          } else {
            KeyboardShortcuts.Recorder(for: .popup, onChange: { newShortcut in
              if newShortcut == nil {
                // No shortcut is recorded. Remove keys monitor
                AppState.shared.popup.deinitEventsMonitor()
              } else {
                // User is using shortcut. Ensure keys monitor is initialized
                AppState.shared.popup.initEventsMonitor()
              }
            })
              .help(Text("OpenTooltip", tableName: "GeneralSettings"))
          }

          Toggle(isOn: $doubleClickPopupEnabled) {
            EmptyView()
          }
          .toggleStyle(.switch)
          .controlSize(.small)
          .onChange(of: doubleClickPopupEnabled, initial: false) { _, isEnabled in
            updateDoubleClickMode(isEnabled)
          }
          Text(doubleClickLabel)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Settings.Section(label: { Text("Pin", tableName: "GeneralSettings") }) {
        KeyboardShortcuts.Recorder(for: .pin)
          .help(Text("PinTooltip", tableName: "GeneralSettings"))
      }
      Settings.Section(label: { Text("Delete", tableName: "GeneralSettings") }
      ) {
        KeyboardShortcuts.Recorder(for: .delete)
          .help(Text("DeleteTooltip", tableName: "GeneralSettings"))
      }
      Settings.Section(
        bottomDivider: true,
        label: { Text("ShowPreview", tableName: "GeneralSettings") }
      ) {
        KeyboardShortcuts.Recorder(for: .togglePreview)
          .help(Text("ShowPreviewTooltip", tableName: "GeneralSettings"))
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("Search", tableName: "GeneralSettings") }
      ) {
        Picker("", selection: $searchMode) {
          ForEach(Search.Mode.allCases) { mode in
            Text(mode.description)
          }
        }
        .labelsHidden()
        .frame(width: 180, alignment: .leading)
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("Behavior", tableName: "GeneralSettings") }
      ) {
        Defaults.Toggle(key: .pasteByDefault) {
          Text("PasteAutomatically", tableName: "GeneralSettings")
        }
        .onChange(refreshModifiers)
        .fixedSize()

        Defaults.Toggle(key: .removeFormattingByDefault) {
          Text("PasteWithoutFormatting", tableName: "GeneralSettings")
        }
        .onChange(refreshModifiers)
        .fixedSize()

        Text(String(
          format: NSLocalizedString("Modifiers", tableName: "GeneralSettings", comment: ""),
          copyModifier, pasteModifier, pasteWithoutFormatting
        ))
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
      }

      Settings.Section(title: "") {
        if let notificationsURL = notificationsURL {
          Link(destination: notificationsURL, label: {
            Text("NotificationsAndSounds", tableName: "GeneralSettings")
          })
        }
      }
    }
    .onAppear {
      doubleClickRecorder.onSelection = { key in
        doubleClickModifierKey = key
      }
      syncDoubleClickRecorderState()
    }
    .onDisappear {
      doubleClickRecorder.stop()
    }
    .confirmationDialog(resetSettingsMessage, isPresented: $showResetSettingsConfirmation) {
      Button(resetSettingsConfirm, role: .destructive) {
        resetSettings()
      }
      Button(resetSettingsCancel, role: .cancel) {}
    }
  }

  private func refreshModifiers(_ sender: Sendable) {
    copyModifier = HistoryItemAction.copy.modifierFlags.description
    pasteModifier = HistoryItemAction.paste.modifierFlags.description
    pasteWithoutFormatting = HistoryItemAction.pasteWithoutFormatting.modifierFlags.description
  }

  private func updateDoubleClickMode(_ isEnabled: Bool) {
    if isEnabled {
      Accessibility.check(accessibility: true, listenEvent: true)
      doubleClickModifierKey = .none
    }

    syncDoubleClickRecorderState()
  }

  private func resetSettings() {
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
      return
    }

    UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
    LaunchAtLogin.isEnabled = false
    updater.automaticallyChecksForUpdates = false
    doubleClickRecorder.stop()
  }

  private func syncDoubleClickRecorderState() {
    if doubleClickPopupEnabled {
      doubleClickRecorder.start()
    } else {
      doubleClickRecorder.stop()
    }
  }

  private func clearDoubleClickSelection() {
    doubleClickModifierKey = .none
  }
}

private struct DoubleClickRecorderField: NSViewRepresentable {
  static let minimumWidth: CGFloat = 130
  typealias NSViewType = KeyboardShortcuts.RecorderCocoa

  let text: String
  let placeholder: String

  func makeNSView(context: Context) -> NSViewType {
    let field = KeyboardShortcuts.RecorderCocoa(for: .doubleClickModifierPresentation)
    configure(field)
    update(field)
    return field
  }

  func updateNSView(_ nsView: NSViewType, context: Context) {
    configure(nsView)
    update(nsView)
  }

  private func configure(_ field: NSViewType) {
    field.refusesFirstResponder = true
    field.isEditable = false
    field.isSelectable = false
    field.focusRingType = .none

    if let cell = field.cell as? NSSearchFieldCell {
      cell.lineBreakMode = .byTruncatingTail
    }
  }

  private func update(_ field: NSViewType) {
    field.placeholderString = placeholder
    field.stringValue = text
  }
}

private extension KeyboardShortcuts.Name {
  static let doubleClickModifierPresentation = Self("doubleClickModifierPresentation")
}

@Observable
private final class DoubleClickModifierRecorder {
  var onSelection: ((DoubleClickModifierKey) -> Void)?

  private var monitor: Any?
  private var detector = DoubleClickModifierKeyDetector()

  func start() {
    detector.reset()
    guard monitor == nil else { return }

    monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
      self?.handle(event)
      return event
    }
  }

  func stop() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
    detector.reset()
  }

  private func handle(_ event: NSEvent) {
    switch event.type {
    case .keyDown:
      detector.handleKeyDown()
    case .flagsChanged:
      if let key = detector.handleFlagsChanged(event.modifierFlags), key != .none {
        onSelection?(key)
      }
    default:
      break
    }
  }
}

#Preview {
  GeneralSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
