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
```

On Apple's SwiftUI, for macOS and for the iOS Simulator (the script leaves
an app in `.build/ios-simulator`, to install with `xcrun simctl install`):

```sh
swift run --traits Apple calculator
Scripts/ios-simulator-app.sh calculator Calculator
Scripts/ios-simulator-app.sh files Files
Scripts/ios-simulator-app.sh images Images
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
