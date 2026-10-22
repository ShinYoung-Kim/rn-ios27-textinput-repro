# iOS 27: multiline TextInput text shifts down one line while typing Korean

Reproducer for a React Native 0.88.0 (New Architecture) bug on iOS 27.0.1.

In a `<TextInput multiline scrollEnabled={false}>` that already has more than one paragraph, typing Korean inside the first paragraph moves the whole text down by one line. It stays there until the next keystroke that only inserts a character, so while typing the text keeps jumping down and back.

The cause is in TextKit 2 (Apple FB25281535): after an edit that replaces text inside the first paragraph, `NSTextLayoutManager` places the first layout fragment at `y = its own height` instead of `0`. UIKit apps that size `UITextView` with Auto Layout never show it, because Auto Layout re-measures the view and that lays the fragment out again. React Native sizes views with frames, so nothing does.

## Run it

```sh
npm install
cd ios && bundle install && bundle exec pod install && cd ..
npx react-native run-ios --device   # iOS 27 device; set your team in Xcode first
```

1. Add the Korean (Standard) keyboard on the device.
2. Tap the top input. The caret goes to the end of `첫째 줄`.
3. Type ㅎ then ㅏ (so ㅎ becomes 하). The three lines move down by one line.

The bottom input has `scrollEnabled` on and does not move.

`ios/RNReproUITests` types the full sequence ` 한글 입력` key by key on the iOS keyboard. The app logs the first layout fragment's frame to `Documents/tk2probe.log` at 0, 16, 100 and 300 ms after each change (see `TextKit2Probe` in `ios/RNRepro/AppDelegate.swift`); `SHIFTED` means `y > 0`.

## Results

14 keystrokes, 8 of them replace the previous syllable (하, 한, 그, 글, 이, 입, 려, 력).

| Device, iOS | Input | Shifted after 16 / 100 / 300 ms |
|---|---|---|
| iPhone 15 Pro, 27.0.1 | `scrollEnabled={false}` | 8 / 8 / 8 |
| iPhone 15 Pro, 27.0.1 | `scrollEnabled` | 0 / 0 / 0 |
| iPhone 15 Pro, 27.0.1 | `scrollEnabled={false}`, empty input | 0 / 0 / 0 |
| iPad Air (3rd gen), 18.5 | `scrollEnabled={false}` | 0 / 0 / 0 |
| Simulator, 26.4 and 18.6 | `scrollEnabled={false}` | 0 / 0 / 0 |

Japanese Kana input (marked text, conversion, confirm) at the same position does not trigger it.

`uikit-repro/` reproduces it without React Native: a frame-sized `UITextView` stays shifted, an Auto Layout one recovers.

## Fix

`patches/relayout-first-fragment.patch` re-lays out only the first fragment when it is misplaced. To try it, the React Native core has to be built from source:

```sh
patch -p1 < patches/relayout-first-fragment.patch
cd ios && RCT_USE_PREBUILT_RNCORE=0 bundle exec pod install
```

With the patch, the same run gives 0 / 0 / 0 for the top input. Cost per keystroke on the iPhone 15 Pro:

| | 26 characters | 9,204 characters |
|---|---|---|
| shift check only, when nothing is shifted | 0.007 ms | 0.011 ms |
| re-layout of the first fragment, when shifted | 0.20 ms | 0.26 ms |
| for comparison: re-measuring the view with `sizeThatFits:` / `intrinsicContentSize` | 0.5 ms | 35 ms |
