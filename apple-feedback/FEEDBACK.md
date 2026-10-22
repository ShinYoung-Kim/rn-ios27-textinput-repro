# Apple Feedback

Submitted 2026-10-22 as **FB25281535** (https://feedbackassistant.apple.com/feedback/25281535), without sysdiagnose.

- Platform: iOS
- Area: UIKit (UITextView / TextKit 2)
- Type: Incorrect/Unexpected Behavior
- Attachments: UIKitRepro.zip, screenshots/*, logs/*

## Title

iOS 27: TextKit 2 lays out the first paragraph one line low after a Korean IME syllable edit when later paragraphs exist

## Description

On iOS 27.0.1, a TextKit 2 UITextView with later paragraphs places its first NSTextLayoutFragment at y = its own height, instead of 0, after a Korean keyboard edit that replaces a character inside the first paragraph (syllable recomposition, for example 하 → 한). The whole text is drawn one line lower than it should be.

The wrong value is already there right after the edit, in UITextView.textDidChangeNotification, in every case we tested on iOS 27.0.1. What happens next depends on how the view is sized:

- Sized by Auto Layout: UIKit re-measures the view through intrinsicContentSize, the fragment is laid out again and is back at y = 0 by our next sample 16 ms later. In our screenshots users do not see the problem.
- Sized by setting `frame` (no Auto Layout), which is how React Native and other frame-based layout systems size views: nothing lays the fragment out again, so the text stays shifted until the next edit that only inserts text.

The same steps on iOS 18.5 (device) and iOS 26.4 (Simulator) keep the fragment at y = 0 at every point, including right after the edit.

## Steps to reproduce

1. Open UIKitRepro.xcodeproj, set a development team, run on an iOS 27.0.1 device. The screen has two UITextViews with `isScrollEnabled = false` and the text "첫째 줄\n둘째 줄입니다\n셋째 줄입니다":
   - top: "input-frame", sized only with `frame`
   - bottom: "input-autolayout", sized with Auto Layout
2. Add the Korean (Standard) keyboard on the device.
3. Tap the top text view. The caret moves to the end of the first paragraph.
4. Type ㅎ, then ㅏ on the Korean keyboard, so that ㅎ is recomposed into 하.

The included UI test `KoreanInputUITests` types the full sequence (space ㅎ ㅏ ㄴ ㄱ ㅡ ㄹ space ㅇ ㅣ ㅂ ㄹ ㅕ ㄱ) on both text views. The app writes the first layout fragment's frame to Documents/tk2probe.log at 0, 16, 100 and 300 ms after each text change.

## Expected result

The first line stays at the top of the text view. The first NSTextLayoutFragment's layoutFragmentFrame.origin.y is 0 after every edit, as on iOS 18.5 and iOS 26.4.

## Actual result

After every edit that replaces a character in the first paragraph, the first fragment's origin.y equals its height (20.3 pt with the 17 pt system font), and all lines are drawn one line lower. Edits that only insert text bring it back to 0.

| iOS, device | sizing | shifted right after the edit | still shifted after 16 / 100 / 300 ms |
|---|---|---|---|
| 27.0.1, iPhone 15 Pro | frame | 8 / 8 replacing edits | 8 / 8 / 8 |
| 27.0.1, iPhone 15 Pro | Auto Layout | 8 / 8 replacing edits | 0 / 0 / 0 |
| 18.5, iPad Air (3rd gen) | frame | 0 | 0 / 0 / 0 |
| 18.5, iPad Air (3rd gen) | Auto Layout | 0 | 0 / 0 / 0 |
| 26.4 Simulator | frame and Auto Layout | 0 | 0 / 0 / 0 |

The view uses TextKit 2 in every run; textLayoutManager is non-nil and layoutManager is never accessed.

Conditions that are all required:
- At least one paragraph after the edited one. With a single paragraph the bug does not occur.
- The edit is inside the first paragraph. The same Korean input typed into the last paragraph of a text view did not trigger it.
- The edit replaces existing text, such as Korean syllable recomposition. Plain insertions, and Japanese Kana input that edits marked text, did not trigger it.

## Workaround

After the text change, if the first fragment's origin.y is greater than 0, invalidate and re-lay out only its range:

```swift
var first: NSTextLayoutFragment?
tlm.enumerateTextLayoutFragments(from: tlm.documentRange.location, options: []) { first = $0; return false }
if let first, first.layoutFragmentFrame.origin.y > 0 {
  tlm.invalidateLayout(for: first.rangeInElement)
  tlm.ensureLayout(for: first.rangeInElement)
}
```

Calling ensureLayout(for:) without invalidating first does not fix it. Calling the view's intrinsicContentSize or sizeThatFits(_:) also fixes it, but lays out the whole document. In our React Native app on the same iPhone, with a 9,200-character text, that took about 35 ms per keystroke, compared with 0.26 ms for the range invalidation above.

## Configuration

- Fails: iOS 27.0.1, iPhone 15 Pro (iPhone16,1)
- Works: iOS 18.5, iPad Air 3rd generation (iPad11,3); iOS 26.4 and iOS 18.6 Simulator
- Xcode 26.4.1 (17E202)
