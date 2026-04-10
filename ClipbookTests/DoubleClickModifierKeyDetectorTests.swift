import AppKit
import XCTest
@testable import Clipbook

class DoubleClickModifierKeyDetectorTests: XCTestCase {
  func testDoubleOptionTapTriggersOption() {
    var detector = DoubleClickModifierKeyDetector()

    XCTAssertNil(detector.handleFlagsChanged([.option], now: .init(timeIntervalSince1970: 0)))
    XCTAssertNil(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 0.1)))
    XCTAssertNil(detector.handleFlagsChanged([.option], now: .init(timeIntervalSince1970: 0.2)))
    XCTAssertEqual(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 0.3)), .option)
  }

  func testDoubleShiftTapTriggersShift() {
    var detector = DoubleClickModifierKeyDetector()

    XCTAssertNil(detector.handleFlagsChanged([.shift], now: .init(timeIntervalSince1970: 0)))
    XCTAssertNil(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 0.1)))
    XCTAssertNil(detector.handleFlagsChanged([.shift], now: .init(timeIntervalSince1970: 0.2)))
    XCTAssertEqual(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 0.3)), .shift)
  }

  func testDoubleControlTapTriggersControl() {
    var detector = DoubleClickModifierKeyDetector()

    XCTAssertNil(detector.handleFlagsChanged([.control], now: .init(timeIntervalSince1970: 0)))
    XCTAssertNil(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 0.1)))
    XCTAssertNil(detector.handleFlagsChanged([.control], now: .init(timeIntervalSince1970: 0.2)))
    XCTAssertEqual(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 0.3)), .control)
  }

  func testSlowDoubleTapDoesNotTrigger() {
    var detector = DoubleClickModifierKeyDetector()

    XCTAssertNil(detector.handleFlagsChanged([.option], now: .init(timeIntervalSince1970: 0)))
    XCTAssertNil(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 0.1)))
    XCTAssertNil(detector.handleFlagsChanged([.option], now: .init(timeIntervalSince1970: 1.0)))
    XCTAssertNil(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 1.1)))
  }

  func testModifierShortcutDoesNotTriggerDoubleTap() {
    var detector = DoubleClickModifierKeyDetector()

    XCTAssertNil(detector.handleFlagsChanged([.option], now: .init(timeIntervalSince1970: 0)))
    detector.handleKeyDown()
    XCTAssertNil(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 0.1)))

    XCTAssertNil(detector.handleFlagsChanged([.option], now: .init(timeIntervalSince1970: 0.2)))
    XCTAssertNil(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 0.3)))
    XCTAssertNil(detector.handleFlagsChanged([.option], now: .init(timeIntervalSince1970: 0.4)))
    XCTAssertEqual(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 0.5)), .option)
  }

  func testDifferentModifiersDoNotMix() {
    var detector = DoubleClickModifierKeyDetector()

    XCTAssertNil(detector.handleFlagsChanged([.option], now: .init(timeIntervalSince1970: 0)))
    XCTAssertNil(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 0.1)))
    XCTAssertNil(detector.handleFlagsChanged([.shift], now: .init(timeIntervalSince1970: 0.2)))
    XCTAssertNil(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 0.3)))
  }

  func testUnsupportedModifierDoubleTapDoesNotTrigger() {
    var detector = DoubleClickModifierKeyDetector()

    XCTAssertNil(detector.handleFlagsChanged([.command], now: .init(timeIntervalSince1970: 0)))
    XCTAssertNil(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 0.1)))
    XCTAssertNil(detector.handleFlagsChanged([.command], now: .init(timeIntervalSince1970: 0.2)))
    XCTAssertNil(detector.handleFlagsChanged([], now: .init(timeIntervalSince1970: 0.3)))
  }

  func testSettingsWindowDisablesAllOpenTriggers() {
    XCTAssertEqual(
      Popup.openTriggerConfiguration(
        isSettingsWindowPresented: true,
        isDoubleClickPopupRequested: false,
        doubleClickModifierKey: .none,
        hasDoubleClickAccess: false
      ),
      .disabled
    )
    XCTAssertEqual(
      Popup.openTriggerConfiguration(
        isSettingsWindowPresented: true,
        isDoubleClickPopupRequested: true,
        doubleClickModifierKey: .option,
        hasDoubleClickAccess: true
      ),
      .disabled
    )
  }

  func testUnassignedDoubleClickFallsBackToRegularShortcut() {
    XCTAssertEqual(
      Popup.openTriggerConfiguration(
        isSettingsWindowPresented: false,
        isDoubleClickPopupRequested: true,
        doubleClickModifierKey: .none,
        hasDoubleClickAccess: true
      ),
      .regularShortcut
    )
  }

  func testMissingDoubleClickAccessFallsBackToRegularShortcut() {
    XCTAssertEqual(
      Popup.openTriggerConfiguration(
        isSettingsWindowPresented: false,
        isDoubleClickPopupRequested: true,
        doubleClickModifierKey: .control,
        hasDoubleClickAccess: false
      ),
      .regularShortcut
    )
  }

  func testAssignedDoubleClickUsesDoubleClickTrigger() {
    XCTAssertEqual(
      Popup.openTriggerConfiguration(
        isSettingsWindowPresented: false,
        isDoubleClickPopupRequested: true,
        doubleClickModifierKey: .control,
        hasDoubleClickAccess: true
      ),
      .doubleClick
    )
  }
}
