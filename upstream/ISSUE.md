# Title

[iOS] Multiline TextInput with scrollEnabled={false} shifts its text down one line while typing Korean on iOS 27

# Description

On iOS 27.0.1, in a multiline `TextInput` with `scrollEnabled={false}` that already contains more than one paragraph, typing Korean inside the first paragraph draws the whole text one line lower than it should be. It stays shifted until the next keystroke that only inserts a character, so while typing the text keeps jumping down and back up.

This comes from TextKit 2. After an edit that replaces text inside the first paragraph, which is what the Korean keyboard does on every syllable recomposition (하 → 한), `NSTextLayoutManager` places the first `NSTextLayoutFragment` at `origin.y` equal to its own height instead of 0. I reported it to Apple as FB25281535.

Plain UIKit apps do not show it when the `UITextView` is sized with Auto Layout: Auto Layout re-measures the view through `intrinsicContentSize`, which lays the fragment out again before the next sample 16 ms later. A `UITextView` sized with frames only stays shifted, in a plain UIKit app as well, and that is how React Native sizes `RCTUITextView`. So on iOS 27 every React Native app with such an input is affected, while UIKit apps mostly are not.

What I measured on device, logging the first layout fragment's frame 0, 16, 100 and 300 ms after each change while typing ` 한글 입력` at the end of the first paragraph (8 of the 14 keystrokes replace the previous syllable):

| Device, iOS | Input | Shifted after 16 / 100 / 300 ms |
|---|---|---|
| iPhone 15 Pro, 27.0.1 | `scrollEnabled={false}`, 3 paragraphs | 8 / 8 / 8 |
| iPhone 15 Pro, 27.0.1 | `scrollEnabled`, 3 paragraphs | 0 / 0 / 0 |
| iPhone 15 Pro, 27.0.1 | `scrollEnabled={false}`, empty | 0 / 0 / 0 |
| iPad Air (3rd gen), 18.5 | `scrollEnabled={false}`, 3 paragraphs | 0 / 0 / 0 |
| Simulator, 26.4 and 18.6 | `scrollEnabled={false}`, 3 paragraphs | 0 / 0 / 0 |

The view uses TextKit 2 in all runs. Japanese Kana input (marked text, conversion, confirm) at the same position does not trigger it.

I have a fix ready and will open a PR: re-lay out only the first fragment when it is misplaced.

# Steps to reproduce

1. Run the reproducer on an iOS 27 device with the Korean (Standard) keyboard added.
2. Tap the top input (`multiline`, `scrollEnabled={false}`, initial value `첫째 줄\n둘째 줄입니다\n셋째 줄입니다`). The caret goes to the end of the first line.
3. Type ㅎ, then ㅏ.
4. All three lines move down by one line. Type ㄴ (→ 한): still shifted. Type ㄱ: back in place. Type ㅡ: shifted again.

Expected: the first line stays at the top of the input, as on iOS 26 and earlier.

# React Native Version

0.88.0

# Affected Platforms

Runtime - iOS

# Areas

Fabric - The New Renderer

# Output of `npx @react-native-community/cli info`

```text
System:
  OS: macOS 26.4
  CPU: (14) arm64 Apple M4 Pro
Binaries:
  Node: 24.10.0
  npm: 11.6.1
Managers:
  CocoaPods: 1.16.2
SDKs:
  iOS SDK: iOS 26.4
IDEs:
  Xcode: 26.4.1/17E202
npmPackages:
  react-native: 0.88.0
Device: iPhone 15 Pro, iOS 27.0.1 (24A446)
```

# Stacktrace or Logs

```text
Probe log, iPhone 15 Pro, iOS 27.0.1, no fix (t16 = 16 ms after the change)
t16 y=0.0  h=20.3 ok      text=첫째 줄 ㅎ
t16 y=20.3 h=20.3 SHIFTED text=첫째 줄 하
t16 y=20.3 h=20.3 SHIFTED text=첫째 줄 한
t16 y=0.0  h=20.3 ok      text=첫째 줄 한ㄱ
t16 y=20.3 h=20.3 SHIFTED text=첫째 줄 한그
t16 y=20.3 h=20.3 SHIFTED text=첫째 줄 한글
```

# MANDATORY Reproducer

<link to the reproducer repository>

# Screenshots and Videos

<attach screenshots/ios27.0.1-before-fix-after-한.png and screenshots/ios27.0.1-with-fix-after-한.png, plus a screen recording if possible>
