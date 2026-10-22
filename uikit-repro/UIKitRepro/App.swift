import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    TextKit2Probe.start()
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = ViewController()
    window?.makeKeyAndVisible()
    return true
  }
}

/// Two non-scrolling UITextViews with the same prefilled text.
/// - "input-frame": sized by frame only, like React Native (Yoga) does. UIKit never asks intrinsicContentSize.
/// - "input-autolayout": sized by Auto Layout, so UIKit re-measures through intrinsicContentSize on every edit.
final class ViewController: UIViewController, UITextViewDelegate {
  static let prefilled = "첫째 줄\n둘째 줄입니다\n셋째 줄입니다"

  private let frameTextView = ViewController.makeTextView(id: "input-frame")
  private let autoLayoutTextView = ViewController.makeTextView(id: "input-autolayout")

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white

    view.addSubview(frameTextView)

    autoLayoutTextView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(autoLayoutTextView)
    NSLayoutConstraint.activate([
      autoLayoutTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      autoLayoutTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      autoLayoutTextView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 140),
    ])
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let top = view.safeAreaInsets.top + 16
    frameTextView.frame = CGRect(x: 16, y: top, width: view.bounds.width - 32, height: 100)
  }

  private static func makeTextView(id: String) -> UITextView {
    let textView = UITextView()
    textView.accessibilityIdentifier = id
    textView.isScrollEnabled = false
    textView.font = .systemFont(ofSize: 17)
    textView.text = prefilled
    textView.layer.borderWidth = 1
    textView.layer.borderColor = UIColor.lightGray.cgColor
    return textView
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    frameTextView.delegate = self
    autoLayoutTextView.delegate = self
  }

  // Caret goes to the end of the first paragraph so typing edits it while later paragraphs exist.
  func textViewDidBeginEditing(_ textView: UITextView) {
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
      let end = (ViewController.prefilled as NSString).range(of: "\n").location
      textView.selectedRange = NSRange(location: end, length: 0)
    }
  }
}

/// Same probe as the RN repro: y of the first TextKit 2 layout fragment after every text change.
enum TextKit2Probe {
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
    write("\(tag) id=\(textView.accessibilityIdentifier ?? "?") y=\(y) h=\(h) \(status) text=\(text)")
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
