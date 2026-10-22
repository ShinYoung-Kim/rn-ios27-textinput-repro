import XCTest

/// Types Korean on the iOS software keyboard, key by key, so the real IME recomposition path runs
/// (e.g. 하 + ㄴ replaces 하 with 한). The caret sits at the end of the first paragraph and later
/// paragraphs exist. Screenshots are kept for comparison with the probe log written by the app.
final class KoreanInputUITests: XCTestCase {
  // " 한글 입력" typed at the end of "첫째 줄".
  private let keys = [" ", "ㅎ", "ㅏ", "ㄴ", "ㄱ", "ㅡ", "ㄹ", " ", "ㅇ", "ㅣ", "ㅂ", "ㄹ", "ㅕ", "ㄱ"]

  override func setUp() {
    continueAfterFailure = false
  }

  func testNonScrollingInput() {
    run(inputId: "input-noscroll")
  }

  func testScrollingInput() {
    run(inputId: "input-scroll")
  }

  private func run(inputId: String) {
    let app = XCUIApplication()
    app.launch()

    let input = app.textViews[inputId]
    XCTAssertTrue(input.waitForExistence(timeout: 30), "input not found")
    input.tap()
    selectKoreanKeyboard(app)
    // onFocus moves the caret to the end of the first paragraph after 50ms.
    Thread.sleep(forTimeInterval: 0.5)

    for (i, key) in keys.enumerated() {
      if key == " " {
        keyboardElement(app, labels: ["space", "Space", "스페이스", "간격", " "]).tap()
      } else {
        app.keyboards.keys[key].tap()
      }
      Thread.sleep(forTimeInterval: 0.4)
      snapshot("\(inputId)-\(i)-\(key)")
    }
  }

  private func selectKoreanKeyboard(_ app: XCUIApplication) {
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), "keyboard not shown")
    for _ in 0..<6 where !app.keyboards.keys["ㅎ"].exists {
      app.buttons["Next keyboard"].tap()
      Thread.sleep(forTimeInterval: 0.3)
    }
    XCTAssertTrue(app.keyboards.keys["ㅎ"].exists, "Korean keyboard not available")
  }

  private func keyboardElement(_ app: XCUIApplication, labels: [String]) -> XCUIElement {
    let predicate = NSPredicate(format: "label IN %@ OR identifier IN %@", labels, labels)
    return app.keyboards.descendants(matching: .any).matching(predicate).firstMatch
  }

  private func snapshot(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
