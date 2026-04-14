import Cocoa

class About {
  private var links: NSMutableAttributedString {
    let string = NSMutableAttributedString(string: "GitHub│Support",
                                           attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
    string.addAttribute(.link, value: "https://github.com/xcy960815/Clipbook", range: NSRange(location: 0, length: 6))
    string.addAttribute(.link, value: "https://github.com/xcy960815/Clipbook/issues", range: NSRange(location: 7, length: 7))
    return string
  }

  private var credits: NSMutableAttributedString {
    let credits = NSMutableAttributedString(string: "",
                                            attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
    credits.append(links)
    credits.setAlignment(.center, range: NSRange(location: 0, length: credits.length))
    return credits
  }

  @objc
  func openAbout(_ sender: NSMenuItem?) {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(options: [NSApplication.AboutPanelOptionKey.credits: credits])
  }
}
