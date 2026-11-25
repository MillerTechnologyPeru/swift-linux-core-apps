# swift-linux-core-apps

Core apps for Swift Linux, written in SwiftUI and laid out for a phone's
width first.

The plan for the apps, and what exists so far, is in
[Documentation/Plan.md](Documentation/Plan.md).

## Three flavors

Most of the apps are [AppRuntime](https://github.com/PureSwift/AppRuntime)
guests: Embedded Swift in a sandboxed bundle, drawing through AppRuntime's
SwiftUI frontend. Three can't live in that sandbox (the file manager, the
software store and Settings) and are programs on
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
| Files | Native | Browses, searches, sorts as a list or grid; copies, moves, renames (several at once), links, compresses, trashes and restores, with undo; bookmarks, stars, volumes, properties and permissions. With `--desktop` it also draws the desktop: the wallpaper and the Desktop folder's icons, in the background layer of the screen. It is also the desktop portal's file chooser, so every app's Open and Save dialogs are Files' (`files --file-chooser`, which D-Bus starts). How it stands beside GNOME Files, and what's missing, is in [Documentation/Files.md](Documentation/Files.md) |
| Images | Native for now | Shows a folder's images as a grid and one at a time: pinch or double-tap to zoom, drag to pan, swipe or step to the next, rotate, properties, move to trash. On Cacao only PNG is drawn, the other formats being named but not decoded; on Apple's SwiftUI the system decodes them. It is meant to be a guest, and isn't yet because a guest can't show an image from a file or take a pinch |
| Music | Native for now | Finds the music under the Music folder and lists it by song, album and artist, from tags it reads itself (ID3, Vorbis comments, MPEG-4, WAV); plays a queue with shuffle and repeat, a scrubber and what's up next. On Cacao only WAV plays, through SDL, the compressed formats waiting on a media stack; on Apple's SwiftUI the system plays them. It is meant to be a guest, and isn't yet because AppRuntime has no player on Linux |
| Text Editor | Native for now | Lists a folder's text files, makes new ones and edits them: undo and redo, find and replace (whole words, matching case), wrapping, text size, word and line counts. Keeps a file's encoding (UTF-8, UTF-16, Latin-1) and line endings. Leaving a document saves it. No in-text highlighting of matches, go to line or line numbers, which need a text view with a selection; files over 5 MB aren't opened. It is meant to be a guest, and isn't yet because a guest has no text editor or file picker |
| Clocks | Native for now | A world clock for places picked from the time zones, alarms that repeat on chosen days with a label and snooze, a stopwatch with laps (fastest and slowest marked) and a timer with presets that can be paused and given another minute. Alarms and timers ring with a chime, through SDL on Cacao and AVFoundation on Apple's SwiftUI, and the places and alarms are kept in `~/.config/clocks`. Alarms ring only while Clocks is open, as nothing wakes it. It is meant to be a guest, and isn't yet because a guest can't play a sound |
| Weather | Native for now | The places you search for, each with its weather now, the next 24 hours (with sunrise and sunset), 10 days on a bar of the week's temperatures, and feels-like, humidity, wind, UV, sun, rain and pressure. In Celsius or Fahrenheit, from [Open-Meteo](https://open-meteo.com), which needs no key; the last forecasts are kept for when it's offline. No current location, there being none to ask on Linux, and no radar, maps or alerts. It is meant to be a guest, and isn't yet because a guest has no HTTP |
| Contacts | Native for now | People and companies by letter, sorted by first or last name, with favorites first and a search that ignores case and accents and finds numbers by their digits. Each card has phones, emails, links, addresses, a birthday and notes, with buttons to call, message and email. The cards are one vCard file in `~/.local/share/contacts`; vCards from Android (2.1), Apple's Contacts and others import and export, keeping what the app doesn't show, such as photos. No photos shown, groups, linked cards or sync. It is meant to be a guest, and isn't yet because a guest has no file picker |
| Calendar | Native for now | A month at a time with a dot for each calendar with events that day, and the day picked listed below it; swipe or step between months. Events can be all-day or timed, repeat (daily, weekdays, weekly, fortnightly, monthly, yearly, until a day) with single days taken out, go on calendars that can be hidden, and alert. `.ics` files from other calendars import, in their time zones, with their repeats, exceptions, moved occurrences and alerts, and export. Alerts come only while Calendar is open, as nothing wakes it; no week or day view, invitations or sync. It is meant to be a guest, and isn't yet because a guest has no time zones, file picker or way to alert while closed |
| Maps | Native for now | OpenStreetMap's map, dragged, pinched and zoomed, with its tiles kept in `~/.cache/maps` to draw again offline. Search for places (near the map first) and save them; directions to a place by car, bike or on foot, drawn on the map with each step. Tiles, search and routes come from OpenStreetMap, Nominatim and FOSSGIS's OSRM, which need no key but ask for light use: `MAPS_TILE_URL` points the map at another tile server. No current location, there being none to ask on Linux, and no offline search, transit or turn-by-turn. It is meant to be a guest, and isn't yet because a guest has no HTTP |
| Videos | Guest | Plays a video file, or one at an `http` or `https` address: play and pause, a scrubber with the time gone and the time left, skipping 10 seconds back and forward, volume and mute, and full screen with the controls over the picture at a tap. As a guest it plays through AppRuntime's `MediaPlayer`, which the host decodes and shows (on Linux, LinuxAppRuntime's GStreamer player), and opens files with the system's picker. As a program it plays through GStreamer on Cacao, its frames published from GStreamer's thread to an `ExternalSurface`, and through AVFoundation on Apple's SwiftUI; a program also opens the file or address it's given. No subtitles, choice of audio track, playlist or playback speed. Its guest bundle plays an address with sound in LinuxAppRuntime's host, through that host's GStreamer player; desktop full screen is untested under a window manager |
| Browser | Guest | Tabs, and an address bar that goes to what's typed or searches for it (with DuckDuckGo, Startpage, Google or Bing), offering matching bookmarks and history as it's typed in; on a page of results it shows the search, and on a web page its host, with a lock over HTTPS. Back and forward, reload and stop, and a progress bar. Bookmarks, shown as favorites on a new tab with the pages gone to lately, can be renamed and moved; the history can be searched and cleared. The tabs, bookmarks, history and search engine are kept between runs, and only the tab shown loads at launch. As a guest its pages are AppRuntime's `WebView`, which LinuxAppRuntime's host draws with WPE WebKit; as a program they're WPE WebKit's on Cacao, through [PureSwift/WebKit](https://github.com/PureSwift/WebKit), and WKWebView on Apple's SwiftUI. A program also opens the address or search it's given. No downloads, private tabs, find in the page, zoom, or links that open new windows in tabs of their own, as Cacao's pages don't have them yet |
| Software | Native | Flathub's catalog, read from the AppStream file Flatpak keeps, browsed by category and the apps updated lately, and searched by name, keywords and summary; each app's page has its description, what's new, license, size and website. Installs from Flathub (for the user when the user has Flathub as a remote, so no password is asked), opens, updates and removes Flatpak apps, lists their updates and updates them all. AppRuntime bundles are listed beside them, installed with LinuxAppRuntime's `linux-app` (picked, or given on the command line) and removed. Sources are the `flatpak` and `linux-app` programs, run directly: no plugin protocol yet, no OS updates, no progress while installing, and no screenshots, which are on Flathub's servers. On Apple's platforms, which have no Flatpak, it says so |
| Camera | Guest | Photos and videos with sound, from the back, front or a plugged-in camera, filling the screen: zoom buttons for the lenses the camera's range reaches (0.5×, 1×, 2×…), a flash that's off, automatic or on, a recording's time, and the last capture beside the shutter. Captures are numbered `IMG_0001.jpg` and `VID_0002.mp4` in the app's documents, under `Captures`, and shown in a grid, one at a time and deleted. As a guest it uses AppRuntime's `Camera`, which the host runs and previews; as a program, AVFoundation on Apple's SwiftUI. Only the iOS Simulator has run it, which has no camera, so no photo or video has been taken. Its guest bundle builds, and LinuxAppRuntime's host refuses it, having neither the camera's contracts nor the drawing ones that show photos; Cacao's flavor has no camera either, and says so; videos don't play in the app; captures aren't added to the system's photos |
| Settings | Native | A sidebar of panes, one over the other at a phone's width. Appearance is the one that works: light, dark or automatic, an accent from GNOME's palette, higher contrast, the window buttons at the left, the right or GNOME's close alone, the interface and monospace fonts, and the icon and cursor themes installed and the cursor's size. It reads them through the settings portal (`org.freedesktop.portal.Settings`, or the settings service's own backend when no portal answers), follows `SettingChanged` so it stays in step, and changes them through [swift-linux-shell](https://github.com/MillerTechnologyPeru/swift-linux-shell)'s settings service, `org.pureswift.Cacao.Settings1.Set`, which every Cacao app, Perry's Mac apps and GNOME apps in a Flatpak follow live. Without the service it shows what the portal has, unchangeable, and says why. Wi-Fi, Bluetooth, Displays, Sound, Power, Default Apps and About are listed and say they aren't here yet. On Apple's platforms there's no session bus, which it says |

The others in the plan aren't started.

## Building

Swift 6.4.2.

```sh
swift build
swift test
```

The native flavor needs what Cacao does: SDL3, and Cairo and FontConfig on
Linux. The video player plays through GStreamer there, which it opens when
a video is first loaded: with GStreamer and its base, good and libav
plugins installed it plays, and without them a video fails to load. The
browser opens WPE WebKit the same way, when its first page loads: with
`libwpewebkit-2.0-1` and `libwpebackend-fdo-1.0-1` installed it shows
pages, and without them a page fails to load, saying so.
Settings reads the desktop's settings from the session bus, through
`xdg-desktop-portal`, and changes them through swift-linux-shell's
`CacaoSettings`, which it needs running to change anything. Its tests run a
`dbus-daemon` of their own when one is installed, and skip the bus
otherwise.

```sh
swift run --traits Native calculator
swift run --traits Native files [folder]
swift run --traits Native files --desktop [--wallpaper image.png]
swift run --traits Native images [image or folder]
swift run --traits Native music [folder]
swift run --traits Native text-editor [file or folder]
swift run --traits Native clocks
swift run --traits Native weather [a kept place]
swift run --traits Native contacts [vCard file to import]
swift run --traits Native calendar [.ics file to import]
swift run --traits Native maps [place to find]
swift run --traits Native videos [file or address]
swift run --traits Native browser [address or search]
swift run --traits Native software [AppRuntime bundle to install]
swift run --traits Native camera
swift run --traits Native settings
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
Scripts/ios-simulator-app.sh maps Maps
Scripts/ios-simulator-app.sh videos Videos
Scripts/ios-simulator-app.sh browser Browser
Scripts/ios-simulator-app.sh software Software
Scripts/ios-simulator-app.sh camera Camera
Scripts/ios-simulator-app.sh settings Settings
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
