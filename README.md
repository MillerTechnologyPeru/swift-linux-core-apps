# swift-linux-core-apps

Core apps for Swift Linux, written in SwiftUI and laid out for a phone's
width first.

The plan for the apps, and what exists so far, is in
[Documentation/Plan.md](Documentation/Plan.md).

## Two flavors

Most of the apps are [AppRuntime](https://github.com/PureSwift/AppRuntime)
guests: Embedded Swift in a sandboxed bundle, drawing through AppRuntime's
SwiftUI frontend. Two can't live in that sandbox (the file manager and the
software store) and are programs on
[Cacao](https://github.com/PureSwift/Cacao), SwiftUI in Swift.

Every app is written once and builds either way. A package trait picks the
flavor:

| Trait | Builds | For |
| --- | --- | --- |
| `Guest` (default) | Apps as AppRuntime guests | The bundles a host runs; `swift build` and `swift test` on the machine you're at, which checks an app keeps to what a guest can use |
| `Native` | Apps as programs on Cacao | The native apps, and running any app on a desktop while working on it |

Apps import `AppUI`, which re-exports the flavor's SwiftUI, and keep to the
part of SwiftUI both flavors have. Where one has more, such as button
styles, `CoreAppsUI` wraps the difference.

## Layout

| Path | |
| --- | --- |
| `Sources/AppUI` | The flavor's SwiftUI under one name |
| `Sources/CoreAppsUI` | Components and sizes the apps share |
| `Sources/<App>Core` | What an app does, without UI or Foundation, with its tests |
| `Sources/<App>` | An app's views and its `App`; the guest's entry point |
| `Sources/<App>Native` | The app as a program on Cacao |
| `Manifests/<App>` | The app's AppRuntime manifest and its localized strings |

## Apps

| App | Flavor | State |
| --- | --- | --- |
| Calculator | Guest | Works as a native program; builds as a guest for the machine at hand; no bundle has been built or run in a host |
| Files | Native | Browses folders from a list of locations, sorts, shows hidden files and a file's details; doesn't open, move or delete anything yet |

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
```

A guest's bundle is built from an AppRuntime checkout, with its wasm Swift
SDK installed:

```sh
Scripts/guest.py bundle --package <this repository> --manifest <this repository>/Manifests/Calculator/App.swift
```
