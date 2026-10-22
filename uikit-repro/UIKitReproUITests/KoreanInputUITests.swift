import XCTest

/// Same key sequence as the RN repro, typed at the end of the first paragraph of each text view.
final class KoreanInputUITests: XCTestCase {
  private let keys = [" ", "ㅎ", "ㅏ", "ㄴ", "ㄱ", "ㅡ", "ㄹ", " ", "ㅇ", "ㅣ", "ㅂ", "ㄹ", "ㅕ", "ㄱ"]

  override func setUp() {
    continueAfterFailure = false
  }

  func testFrameLayout() {
    run(inputId: "input-frame")
  }

  func testAutoLayout() {
    run(inputId: "input-autolayout")
  }

  private func run(inputId: String) {
    let app = XCUIApplication()
    app.launch()

    let input = app.textViews[inputId]
    XCTAssertTrue(input.waitForExistence(timeout: 30), "input not found")
    input.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), "keyboard not shown")
    for _ in 0..<5 where !app.keyboards.keys["ㅎ"].exists {
      app.buttons["Next keyboard"].tap()
    }
    XCTAssertTrue(app.keyboards.keys["ㅎ"].exists, "Korean keyboard not available")
    Thread.sleep(forTimeInterval: 0.5)

    for (i, key) in keys.enumerated() {
      if key == " " {
        app.keyboards.descendants(matching: .any)
          .matching(NSPredicate(format: "label IN %@ OR identifier IN %@", ["space", " "], ["space", " "])).firstMatch.tap()
      } else {
        app.keyboards.keys[key].tap()
      }
      Thread.sleep(forTimeInterval: 0.4)
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = "\(inputId)-\(i)-\(key)"
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
}
