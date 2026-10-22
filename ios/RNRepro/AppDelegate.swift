import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    TextKit2Probe.start()
    return true
  }
}

/// Logs the y of the first TextKit 2 layout fragment after every text change.
/// Expected value is 0. The bug shows up as y == height of the first paragraph.
/// Only reads `textLayoutManager`; touching `layoutManager` would switch the view to TextKit 1.
enum TextKit2Probe {
  /// Device logs need root to collect, so lines are also appended to Documents/tk2probe.log.
  private static let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("tk2probe.log")

  static func start() {
    try? FileManager.default.removeItem(at: fileURL)
    write("iOS \(UIDevice.current.systemVersion)")
    NotificationCenter.default.addObserver(
      forName: UITextView.textDidChangeNotification, object: nil, queue: .main
    ) { note in
      guard let textView = note.object as? UITextView else { return }
      log(textView, "t0")
      for ms in [16, 100, 300] {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(ms)) { log(textView, "t\(ms)") }
      }
    }
  }

  static func log(_ textView: UITextView, _ tag: String) {
    guard #available(iOS 16.0, *), let tlm = textView.textLayoutManager else {
      write("\(tag) no textLayoutManager (TextKit 1)")
      return
    }
    var frame: CGRect?
    tlm.enumerateTextLayoutFragments(from: tlm.documentRange.location, options: []) { fragment in
      frame = fragment.layoutFragmentFrame
      return false
    }
    let y = frame.map { String(format: "%.1f", $0.origin.y) } ?? "nil"
    let h = frame.map { String(format: "%.1f", $0.size.height) } ?? "nil"
    let status = (frame?.origin.y ?? 0) > 0.5 ? "SHIFTED" : "ok"
    let text = textView.text.replacingOccurrences(of: "\n", with: "⏎")
    write("\(tag) \(type(of: textView)) id=\(inputId(of: textView)) scroll=\(textView.isScrollEnabled ? 1 : 0) y=\(y) h=\(h) \(status) text=\(text)")
  }

  /// RN puts testID on the component view, which is the text view's superview.
  private static func inputId(of textView: UITextView) -> String {
    textView.superview?.accessibilityIdentifier ?? textView.accessibilityIdentifier ?? "?"
  }

  private static func write(_ line: String) {
    NSLog("[TK2PROBE] %@", line)
    let data = Data((line + "\n").utf8)
    if let handle = try? FileHandle(forWritingTo: fileURL) {
      handle.seekToEndOfFile()
      handle.write(data)
      try? handle.close()
    } else {
      try? data.write(to: fileURL)
    }
  }
}
