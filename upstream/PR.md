# Title

fix(ios): re-lay out a misplaced first text fragment in RCTUITextView on iOS 27

# Summary

Fixes #<issue number>.

On iOS 27, TextKit 2 can leave the first layout fragment of a `UITextView` pushed down by its own height after an edit that replaces text inside the first paragraph while later paragraphs exist. The Korean keyboard does this on every syllable recomposition, so in a multiline `TextInput` with `scrollEnabled={false}` the whole text jumps down by the height of the first paragraph while typing. Reported to Apple as FB25281535.

UIKit hides this when the text view is sized with Auto Layout, because re-measuring through `intrinsicContentSize` lays the fragment out again. `RCTUITextView` is sized with frames, so nothing does that and the text stays shifted until the next edit. A frame-sized `UITextView` in a plain UIKit app behaves the same way.

This change checks the first layout fragment after each text change, and when its `origin.y` is greater than 0, invalidates and re-lays out only that fragment's range. Invalidating first is required: `ensureLayoutForRange:` alone does not fix it.

- Nothing changes while the first fragment is in place. That was the case for every edit on iOS 18.5 and 26.4, and on iOS 27 for every edit that does not trigger the bug. The check costs about 0.01 ms per change.
- Re-laying out one fragment costs about 0.25 ms per change and does not depend on the text length. Re-measuring the whole view with `sizeThatFits:` or `intrinsicContentSize` also fixes it, but took 35 ms per keystroke for a 9,204-character text on an iPhone 15 Pro.

## Changelog:

[IOS] [FIXED] - Fix multiline TextInput text shifting down while typing Korean on iOS 27

## Test Plan:

Reproducer: <link to the reproducer repository>. A UI test types ` 한글 입력` key by key on the iOS Korean keyboard at the end of the first paragraph of `첫째 줄\n둘째 줄입니다\n셋째 줄입니다`, and the app logs the first layout fragment's frame 0, 16, 100 and 300 ms after each change. 8 of the 14 keystrokes replace the previous syllable.

iPhone 15 Pro, iOS 27.0.1, React Native 0.88.0 built from source:

| Input | Shifted after 16 / 100 / 300 ms, before | after |
|---|---|---|
| `multiline`, `scrollEnabled={false}` | 8 / 8 / 8 | 0 / 0 / 0 |
| `multiline`, `scrollEnabled` | 0 / 0 / 0 | 0 / 0 / 0 |

| Before | After |
|---|---|
| <ios27.0.1-before-fix-after-한.png> | <ios27.0.1-with-fix-after-한.png> |

Also checked:

- Japanese Kana input with marked text, conversion and confirm at the same position: same final text with and without the change, no shift either way.
- iOS 18.5 device, iOS 26.4 and 18.6 simulators: the first fragment stays at y = 0 after every edit, so the new code returns right after the check.
- 9,204-character input: fixed, about 0.26 ms per shifted keystroke.
