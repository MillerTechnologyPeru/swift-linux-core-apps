# swift-linux-core-apps

Core apps for Swift Linux, written in SwiftUI and laid out for a phone's
width first.

The plan for the apps, and what exists so far, is in
[Documentation/Plan.md](Documentation/Plan.md).

## Three flavors

Most of the apps are [AppRuntime](https://github.com/PureSwift/AppRuntime)
guests: Embedded Swift in a sandboxed bundle, drawing through AppRuntime's
SwiftUI frontend. Two can't live in that sandbox (the file manager and the
software store) and are programs on
[Cacao](https://github.com/PureSwift/Cacao), SwiftUI in Swift.

Every app is written once and builds either way, and a third way too: on
Apple's own SwiftUI, for macOS and iOS. A package trait picks the flavor:

| Trait | Builds | For |
| --- | --- | --- |
| `Guest` (default) | Apps as AppRuntime guests | The bundles a host runs; `swift build` and `swift test` on the machine you're at, which checks an app keeps to what a guest can use |
| `Native` | Apps as programs on Cacao | The native apps, and running any app on a desktop while working on it |
| `Apple` | Apps as programs on Apple's SwiftUI | Running the apps on macOS and iOS, and comparing them with the real thing |

Apps import `AppUI`, which re-exports the flavor's SwiftUI, and keep to the
part of SwiftUI every flavor has. Where one has more, such as button
styles, `CoreAppsUI` wraps the difference.

## Layout

| Path | |
| --- | --- |
| `Sources/AppUI` | The flavor's SwiftUI under one name |
| `Sources/CoreAppsUI` | Components and sizes the apps share |
| `Sources/<App>Core` | What an app does, without UI or Foundation, with its tests |
| `Sources/<App>` | An app's views and its `App`; the guest's entry point |
| `Sources/<App>Native` | The app as a program, on Cacao or Apple's SwiftUI |
| `Scripts` | Building an app for the iOS Simulator |
| `Manifests/<App>` | The app's AppRuntime manifest and its localized strings |

## Apps

| App | Flavor | State |
| --- | --- | --- |
| Calculator | Guest | Works as a native program; builds as a guest for the machine at hand; no bundle has been built or run in a host |
| Files | Native | Browses, searches, sorts as a list or grid; copies, moves, renames (several at once), links, compresses, trashes and restores, with undo; bookmarks, stars, volumes, properties and permissions. How it stands beside GNOME Files, and what's missing, is in [Documentation/Files.md](Documentation/Files.md) |
| Images | Native for now | Shows a folder's images as a grid and one at a time: pinch or double-tap to zoom, drag to pan, swipe or step to the next, rotate, properties, move to trash. On Cacao only PNG is drawn, the other formats being named but not decoded; on Apple's SwiftUI the system decodes them. It is meant to be a guest, and isn't yet because a guest can't show an image from a file or take a pinch |
| Music | Native for now | Finds the music under the Music folder and lists it by song, album and artist, from tags it reads itself (ID3, Vorbis comments, MPEG-4, WAV); plays a queue with shuffle and repeat, a scrubber and what's up next. On Cacao only WAV plays, through SDL, the compressed formats waiting on a media stack; on Apple's SwiftUI the system plays them. It is meant to be a guest, and isn't yet because AppRuntime has no player on Linux |
| Text Editor | Native for now | Lists a folder's text files, makes new ones and edits them: undo and redo, find and replace (whole words, matching case), wrapping, text size, word and line counts. Keeps a file's encoding (UTF-8, UTF-16, Latin-1) and line endings. Leaving a document saves it. No in-text highlighting of matches, go to line or line numbers, which need a text view with a selection; files over 5 MB aren't opened. It is meant to be a guest, and isn't yet because a guest has no text editor or file picker |
| Clocks | Native for now | A world clock for places picked from the time zones, alarms that repeat on chosen days with a label and snooze, a stopwatch with laps (fastest and slowest marked) and a timer with presets that can be paused and given another minute. Alarms and timers ring with a chime, through SDL on Cacao and AVFoundation on Apple's SwiftUI, and the places and alarms are kept in `~/.config/clocks`. Alarms ring only while Clocks is open, as nothing wakes it. It is meant to be a guest, and isn't yet because a guest can't play a sound |
| Weather | Native for now | The places you search for, each with its weather now, the next 24 hours (with sunrise and sunset), 10 days on a bar of the week's temperatures, and feels-like, humidity, wind, UV, sun, rain and pressure. In Celsius or Fahrenheit, from [Open-Meteo](https://open-meteo.com), which needs no key; the last forecasts are kept for when it's offline. No current location, there being none to ask on Linux, and no radar, maps or alerts. It is meant to be a guest, and isn't yet because a guest has no HTTP |
| Contacts | Native for now | People and companies by letter, sorted by first or last name, with favorites first and a search that ignores case and accents and finds numbers by their digits. Each card has phones, emails, links, addresses, a birthday and notes, with buttons to call, message and email. The cards are one vCard file in `~/.local/share/contacts`; vCards from Android (2.1), Apple's Contacts and others import and export, keeping what the app doesn't show, such as photos. No photos shown, groups, linked cards or sync. It is meant to be a guest, and isn't yet because a guest has no file picker |
| Calendar | Native for now | A month at a time with a dot for each calendar with events that day, and the day picked listed below it; swipe or step between months. Events can be all-day or timed, repeat (daily, weekdays, weekly, fortnightly, monthly, yearly, until a day) with single days taken out, go on calendars that can be hidden, and alert. `.ics` files from other calendars import, in their time zones, with their repeats, exceptions, moved occurrences and alerts, and export. Alerts come only while Calendar is open, as nothing wakes it; no week or day view, invitations or sync. It is meant to be a guest, and isn't yet because a guest has no time zones, file picker or way to alert while closed |

The others in the plan aren't started.

## Building

Swift 6.4.2.

```sh
swift build
swift test
```

The native flavor needs what Cacao does: SDL3, and Cairo and FontConfig on
Linux.

```sh
swift run --traits Native calculator
swift run --traits Native files [folder]
swift run --traits Native images [image or folder]
swift run --traits Native music [folder]
swift run --traits Native text-editor [file or folder]
swift run --traits Native clocks
swift run --traits Native weather [a kept place]
swift run --traits Native contacts [vCard file to import]
swift run --traits Native calendar [.ics file to import]
```

On Apple's SwiftUI, for macOS and for the iOS Simulator (the script leaves
an app in `.build/ios-simulator`, to install with `xcrun simctl install`):

```sh
swift run --traits Apple calculator
Scripts/ios-simulator-app.sh calculator Calculator
Scripts/ios-simulator-app.sh files Files
Scripts/ios-simulator-app.sh images Images
Scripts/ios-simulator-app.sh music Music
Scripts/ios-simulator-app.sh text-editor "Text Editor"
Scripts/ios-simulator-app.sh clocks Clocks
Scripts/ios-simulator-app.sh weather Weather
Scripts/ios-simulator-app.sh contacts Contacts
Scripts/ios-simulator-app.sh calendar Calendar
```

The guest flavor and the apps' logic also build for Linux linked statically
against musl, with Swift's
[static Linux SDK](https://www.swift.org/documentation/articles/static-linux-getting-started.html)
installed. Cacao's flavor doesn't, as the SDK has no SDL, Cairo or
FontConfig.

```sh
swift build --swift-sdk aarch64-swift-linux-musl
```

CI builds all of these: macOS and the iOS Simulator, Linux on x86_64 (where
it also runs both programs offscreen), and arm64 with musl.

A guest's bundle is built from an AppRuntime checkout, with its wasm Swift
SDK installed:

```sh
Scripts/guest.py bundle --package <this repository> --manifest <this repository>/Manifests/Calculator/App.swift
```
