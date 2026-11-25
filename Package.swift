// swift-tools-version:6.4
import PackageDescription

/// The core apps for Swift Linux.
///
/// Each app is written once, in the part of SwiftUI that all of its hosts
/// draw, and builds in one of three flavors, chosen by a package trait:
///
/// - `Guest` (the default): an AppRuntime guest, in Embedded Swift, drawing
///   through AppRuntime's SwiftUI frontend. `swift build` and `swift test`
///   build this flavor for the machine they run on, which checks that an app
///   stays inside what a guest can use; AppRuntime's `Scripts/guest.py`
///   builds the bundle a host runs.
/// - `Native`: a program on Cacao, for the apps that can't live in the
///   bundle sandbox (the file manager, the software store and Settings),
///   and for running any app on a desktop while working on it:
///   `swift run --traits Native calculator`.
/// - `Apple`: a program on Apple's own SwiftUI, for macOS and iOS. It shows
///   an app as SwiftUI itself draws it, beside Cacao's drawing of the same
///   source, and keeps the apps to SwiftUI that Apple's accepts.
///
/// Apps import `AppUI`, which re-exports the flavor's SwiftUI.
let package = Package(
    name: "CoreApps",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        // Guest products: what `guest.py` builds a bundle from.
        .library(name: "Calculator", type: .static, targets: ["Calculator"]),
        .library(name: "Videos", type: .static, targets: ["Videos"]),
        .library(name: "Browser", type: .static, targets: ["Browser"]),
        .library(name: "Viewfinder", type: .static, targets: ["Viewfinder"]),
        // Native programs.
        .executable(name: "calculator", targets: ["CalculatorNative"]),
        .executable(name: "files", targets: ["FilesNative"]),
        .executable(name: "images", targets: ["ImagesNative"]),
        .executable(name: "music", targets: ["MusicNative"]),
        .executable(name: "clocks", targets: ["ClocksNative"]),
        .executable(name: "text-editor", targets: ["EditorNative"]),
        .executable(name: "weather", targets: ["WeatherNative"]),
        .executable(name: "contacts", targets: ["ContactsNative"]),
        .executable(name: "calendar", targets: ["CalendarNative"]),
        .executable(name: "maps", targets: ["MapsNative"]),
        .executable(name: "videos", targets: ["VideosNative"]),
        .executable(name: "browser", targets: ["BrowserNative"]),
        .executable(name: "software", targets: ["SoftwareNative"]),
        .executable(name: "camera", targets: ["CameraNative"]),
        .executable(name: "settings", targets: ["SettingsNative"]),
        // Shared.
        .library(name: "AppUI", targets: ["AppUI"]),
        .library(name: "CoreAppsUI", targets: ["CoreAppsUI"]),
        .library(name: "AppMedia", targets: ["AppMedia"]),
        .library(name: "AppWeb", targets: ["AppWeb"]),
        .library(name: "AppCamera", targets: ["AppCamera"]),
        .library(name: "CalculatorCore", targets: ["CalculatorCore"]),
        .library(name: "FilesCore", targets: ["FilesCore"]),
        .library(name: "ImagesCore", targets: ["ImagesCore"]),
        .library(name: "MusicCore", targets: ["MusicCore"]),
        .library(name: "ClocksCore", targets: ["ClocksCore"]),
        .library(name: "TextCore", targets: ["TextCore"]),
        .library(name: "WeatherCore", targets: ["WeatherCore"]),
        .library(name: "ContactsCore", targets: ["ContactsCore"]),
        .library(name: "CalendarCore", targets: ["CalendarCore"]),
        .library(name: "MapsCore", targets: ["MapsCore"]),
        .library(name: "VideosCore", targets: ["VideosCore"]),
        .library(name: "BrowserCore", targets: ["BrowserCore"]),
        .library(name: "SoftwareCore", targets: ["SoftwareCore"]),
        .library(name: "CameraCore", targets: ["CameraCore"]),
        .library(name: "SettingsCore", targets: ["SettingsCore"]),
    ],
    traits: [
        .trait(
            name: "Guest",
            description: "Build apps as AppRuntime guests, on its SwiftUI frontend."
        ),
        .trait(
            name: "Native",
            description: "Build apps as programs on Cacao. Use it alone: --traits Native."
        ),
        .trait(
            name: "Apple",
            description: "Build apps as programs on Apple's SwiftUI, for macOS and iOS. Use it alone: --traits Apple."
        ),
        .default(enabledTraits: ["Guest"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/AppRuntime.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/PureSwift/Cacao.git",
            branch: "develop"
        ),
        // SDL's audio, for the music player on Cacao. The same package and
        // branch Cacao opens its windows with.
        .package(
            url: "https://github.com/PureSwift/SDL.git",
            branch: "master"
        ),
        // WPE WebKit's pages in Cacao, for the browser on Cacao.
        .package(
            url: "https://github.com/PureSwift/WebKit.git",
            branch: "master"
        ),
        // The session bus, for Settings to read and change the desktop's
        // settings. The same package and branch Cacao follows the portal
        // with.
        .package(
            url: "https://github.com/PureSwift/DBus.git",
            branch: "master"
        ),
    ],
    targets: [

        // MARK: - Shared

        // The flavor's SwiftUI, under one name.
        .target(
            name: "AppUI",
            dependencies: [
                .product(name: "DynamicRuntime", package: "AppRuntime", condition: .when(traits: ["Guest"])),
                .product(name: "DynamicSwiftUI", package: "AppRuntime", condition: .when(traits: ["Guest"])),
                .product(name: "Cacao", package: "Cacao", condition: .when(traits: ["Native"])),
                .product(name: "CacaoSDL", package: "Cacao", condition: .when(traits: ["Native"])),
            ]
        ),
        // Components the apps share, so they look and behave alike.
        .target(
            name: "CoreAppsUI",
            dependencies: ["AppUI"]
        ),
        // Media playing, as the flavor has it, in AppRuntime's shape: its
        // `DynamicMedia` for a guest, GStreamer to an `ExternalSurface` on
        // Cacao, and AVFoundation on Apple's SwiftUI.
        .target(
            name: "AppMedia",
            dependencies: [
                "AppUI",
                .product(name: "DynamicMedia", package: "AppRuntime", condition: .when(traits: ["Guest"])),
                .product(name: "DynamicFiles", package: "AppRuntime", condition: .when(traits: ["Guest"])),
            ]
        ),
        // Web pages, as the flavor has them, in AppRuntime's shape: its
        // `DynamicWebKit` for a guest, PureSwift/WebKit's WPE pages on
        // Cacao, and WKWebView on Apple's SwiftUI.
        .target(
            name: "AppWeb",
            dependencies: [
                "AppUI",
                .product(name: "DynamicWebKit", package: "AppRuntime", condition: .when(traits: ["Guest"])),
                .product(name: "CacaoWebKit", package: "WebKit", condition: .when(traits: ["Native"])),
            ]
        ),
        // A camera, as the flavor has it, in AppRuntime's shape: its
        // `DynamicCamera` for a guest, with `DynamicFiles` for where
        // captures go and `DynamicDrawing` to show them; AVFoundation on
        // Apple's SwiftUI; and none yet on Cacao.
        .target(
            name: "AppCamera",
            dependencies: [
                "AppUI",
                .product(name: "DynamicCamera", package: "AppRuntime", condition: .when(traits: ["Guest"])),
                .product(name: "DynamicFiles", package: "AppRuntime", condition: .when(traits: ["Guest"])),
                .product(name: "DynamicDrawing", package: "AppRuntime", condition: .when(traits: ["Guest"])),
            ]
        ),

        // MARK: - Calculator

        // What the calculator computes: no UI, and nothing a guest lacks.
        .target(
            name: "CalculatorCore"
        ),
        .target(
            name: "Calculator",
            dependencies: ["AppUI", "CoreAppsUI", "CalculatorCore"]
        ),
        // The calculator as a program, on Cacao or on Apple's SwiftUI. Named
        // apart from the app's library:
        // file systems that ignore case would give the two one directory.
        .executableTarget(
            name: "CalculatorNative",
            dependencies: [
                .target(name: "Calculator", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "CalculatorCoreTests",
            dependencies: ["CalculatorCore"]
        ),

        // MARK: - Files

        // What the file manager knows of the file system. It uses
        // Foundation: the file manager is a program, never a guest.
        .target(
            name: "FilesCore"
        ),
        .target(
            name: "Files",
            dependencies: ["AppUI", "CoreAppsUI", "FilesCore"]
        ),
        .executableTarget(
            name: "FilesNative",
            dependencies: [
                .target(name: "Files", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "FilesCoreTests",
            dependencies: ["FilesCore"]
        ),

        // MARK: - Images

        // What the image viewer works out: formats, sizes, zooming. No UI
        // and no Foundation, for the day it's a guest.
        .target(
            name: "ImagesCore"
        ),
        // The viewer's views. It finds a folder's images with the file
        // manager's listing, and so is a program for now.
        .target(
            name: "Images",
            dependencies: ["AppUI", "CoreAppsUI", "ImagesCore", "FilesCore"]
        ),
        .executableTarget(
            name: "ImagesNative",
            dependencies: [
                .target(name: "Images", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "ImagesCoreTests",
            dependencies: ["ImagesCore"]
        ),

        // MARK: - Music

        // What the music player works out: tags, the queue, the library.
        // No UI and no Foundation, for the day it's a guest.
        .target(
            name: "MusicCore"
        ),
        // The player's views and its sound. It finds music on the file
        // system and plays it through SDL or AVFoundation, and so is a
        // program for now.
        .target(
            name: "Music",
            dependencies: [
                "AppUI", "CoreAppsUI", "MusicCore", "FilesCore",
                .product(name: "SDL3Swift", package: "SDL", condition: .when(traits: ["Native"])),
            ]
        ),
        .executableTarget(
            name: "MusicNative",
            dependencies: [
                .target(name: "Music", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "MusicCoreTests",
            dependencies: ["MusicCore"]
        ),

        // MARK: - Text Editor

        // What the text editor works out: encodings, searching, undoing.
        // No UI and no Foundation, for the day it's a guest.
        .target(
            name: "TextCore"
        ),
        // The editor's views. It finds and writes files itself, and so is
        // a program for now.
        // Named apart from SwiftUI's `TextEditor`, which it's built on.
        .target(
            name: "Editor",
            dependencies: ["AppUI", "CoreAppsUI", "TextCore", "FilesCore"]
        ),
        .executableTarget(
            name: "EditorNative",
            dependencies: [
                .target(name: "Editor", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "TextCoreTests",
            dependencies: ["TextCore"]
        ),

        // MARK: - Clocks

        // What the clocks work out: alarms, the stopwatch, the timer and
        // the chime. No UI and no Foundation, for the day it's a guest.
        .target(
            name: "ClocksCore"
        ),
        // The clocks' views, and the chime played through SDL or
        // AVFoundation. It rings only while it's open, there being no
        // service yet to wake it, and so is a program for now.
        .target(
            name: "Clocks",
            dependencies: [
                "AppUI", "CoreAppsUI", "ClocksCore",
                .product(name: "SDL3Swift", package: "SDL", condition: .when(traits: ["Native"])),
            ]
        ),
        .executableTarget(
            name: "ClocksNative",
            dependencies: [
                .target(name: "Clocks", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "ClocksCoreTests",
            dependencies: ["ClocksCore"]
        ),

        // MARK: - Weather

        // What the weather works out: Open-Meteo's forecast and places,
        // conditions, times on a place's clock, units. No UI and no
        // Foundation, for the day it's a guest.
        .target(
            name: "WeatherCore"
        ),
        // The weather's views. It fetches forecasts over HTTP, which a
        // guest can't yet, and so is a program for now.
        .target(
            name: "Weather",
            dependencies: ["AppUI", "CoreAppsUI", "WeatherCore"]
        ),
        .executableTarget(
            name: "WeatherNative",
            dependencies: [
                .target(name: "Weather", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "WeatherCoreTests",
            dependencies: ["WeatherCore"]
        ),

        // MARK: - Contacts

        // What the contacts work out: names, sorting and searching, and
        // vCards. No UI and no Foundation, for the day it's a guest.
        .target(
            name: "ContactsCore"
        ),
        // The contacts' views. It keeps its cards in a file of its own and
        // imports and exports through the system's file dialogs, which a
        // guest has no contract for yet, and so is a program for now.
        // Named apart from Apple's Contacts framework.
        .target(
            name: "AddressBook",
            dependencies: ["AppUI", "CoreAppsUI", "ContactsCore"]
        ),
        .executableTarget(
            name: "ContactsNative",
            dependencies: [
                .target(name: "AddressBook", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "ContactsCoreTests",
            dependencies: ["ContactsCore"]
        ),

        // MARK: - Calendar

        // What the calendar works out: days, repeating events, the month's
        // grid, alerts and iCalendar files. No UI and no Foundation, for
        // the day it's a guest.
        .target(
            name: "CalendarCore"
        ),
        // The calendar's views. It reminds only while it's open and uses
        // the system's file dialogs and time zones, and so is a program
        // for now. Named apart from Foundation's `Calendar`.
        .target(
            name: "Datebook",
            dependencies: ["AppUI", "CoreAppsUI", "CalendarCore"]
        ),
        .executableTarget(
            name: "CalendarNative",
            dependencies: [
                .target(name: "Datebook", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "CalendarCoreTests",
            dependencies: ["CalendarCore"]
        ),

        // MARK: - Maps

        // What the maps work out: the projection, which tiles cover the
        // screen, panning and zooming, and reading searches and routes.
        // No UI and no Foundation, for the day it's a guest.
        .target(
            name: "MapsCore"
        ),
        // The maps' views. They fetch tiles, searches and routes over
        // HTTP, which a guest can't yet, and so are a program for now.
        // Named apart from Apple's MapKit and Maps.
        .target(
            name: "Atlas",
            dependencies: ["AppUI", "CoreAppsUI", "MapsCore"]
        ),
        .executableTarget(
            name: "MapsNative",
            dependencies: [
                .target(name: "Atlas", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "MapsCoreTests",
            dependencies: ["MapsCore"]
        ),

        // MARK: - Videos

        // What the video player works out: times, the scrubber, the
        // volume and what was opened. No UI and no Foundation, as it's a
        // guest.
        .target(
            name: "VideosCore"
        ),
        // The player's views. A guest: AppRuntime's host decodes and shows
        // the video, and the system's picker gives it files. As a program
        // it plays through GStreamer on Cacao, where full screen is SDL's,
        // or AVFoundation on Apple's SwiftUI.
        .target(
            name: "Videos",
            dependencies: [
                "AppUI", "CoreAppsUI", "AppMedia", "VideosCore",
                .product(name: "DynamicDocuments", package: "AppRuntime", condition: .when(traits: ["Guest"])),
                .product(name: "SDL3Swift", package: "SDL", condition: .when(traits: ["Native"])),
            ]
        ),
        .executableTarget(
            name: "VideosNative",
            dependencies: [
                .target(name: "Videos", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "VideosCoreTests",
            dependencies: ["VideosCore"]
        ),

        // MARK: - Browser

        // What the browser works out: what's typed into the address bar,
        // the tabs, bookmarks and history, and keeping them. No UI and no
        // Foundation, as it's a guest.
        .target(
            name: "BrowserCore"
        ),
        // The browser's views. A guest: AppRuntime's host loads and draws
        // the pages, and keeps its defaults. As a program its pages are
        // WPE WebKit's on Cacao, through PureSwift/WebKit, or WKWebView on
        // Apple's SwiftUI, whose pages and views belong to the main actor,
        // as the views here then do too.
        .target(
            name: "Browser",
            dependencies: [
                "AppUI", "CoreAppsUI", "AppWeb", "BrowserCore",
                .product(name: "DynamicDefaults", package: "AppRuntime", condition: .when(traits: ["Guest"])),
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self, .when(traits: ["Native", "Apple"])),
            ]
        ),
        .executableTarget(
            name: "BrowserNative",
            dependencies: [
                .target(name: "Browser", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "BrowserCoreTests",
            dependencies: ["BrowserCore"]
        ),

        // MARK: - Software

        // What the software store reads: AppStream catalogs, what Flatpak
        // prints, and AppRuntime bundles' Info.plist; and finding apps. It
        // uses Foundation: the store is a program, never a guest.
        .target(
            name: "SoftwareCore"
        ),
        // The store's views, and running `flatpak` and `linux-app`. Its
        // views and model belong to the main actor, as SwiftUI's do.
        .target(
            name: "Software",
            dependencies: ["AppUI", "CoreAppsUI", "SoftwareCore"],
            swiftSettings: [
                .defaultIsolation(MainActor.self, .when(traits: ["Native", "Apple"])),
            ]
        ),
        .executableTarget(
            name: "SoftwareNative",
            dependencies: [
                .target(name: "Software", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "SoftwareCoreTests",
            dependencies: ["SoftwareCore"]
        ),

        // MARK: - Camera

        // What the camera works out: captures' names, the zoom buttons, the
        // recording's time and the flash. No UI and no Foundation, as it's
        // a guest.
        .target(
            name: "CameraCore"
        ),
        // The camera's views, named apart from the `Camera` they use. A
        // guest: AppRuntime's host captures and shows the preview. As a
        // program it captures with AVFoundation on Apple's SwiftUI, and on
        // Cacao says there's no camera yet. Its views belong to the main
        // actor in a program, as the cameras there do.
        .target(
            name: "Viewfinder",
            dependencies: ["AppUI", "CoreAppsUI", "AppCamera", "CameraCore"],
            swiftSettings: [
                .defaultIsolation(MainActor.self, .when(traits: ["Native", "Apple"])),
            ]
        ),
        .executableTarget(
            name: "CameraNative",
            dependencies: [
                .target(name: "Viewfinder", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "CameraCoreTests",
            dependencies: ["CameraCore"]
        ),

        // MARK: - Settings

        // What Settings works out: the settings the portal serves, their
        // values, the accents and window buttons to choose from, the
        // themes installed, and the session bus calls that read and
        // change them. It uses Foundation and D-Bus: Settings is a
        // program, never a guest. Apple's platforms have no D-Bus package
        // but on macOS, and iOS no session bus, so there it reads nothing.
        .target(
            name: "SettingsCore",
            dependencies: [
                .product(name: "DBus", package: "DBus", condition: .when(platforms: [.linux, .macOS])),
            ]
        ),
        // Settings' views. Its views and model belong to the main actor,
        // as SwiftUI's do.
        .target(
            name: "Settings",
            dependencies: ["AppUI", "CoreAppsUI", "SettingsCore"],
            swiftSettings: [
                .defaultIsolation(MainActor.self, .when(traits: ["Native", "Apple"])),
            ]
        ),
        .executableTarget(
            name: "SettingsNative",
            dependencies: [
                .target(name: "Settings", condition: .when(traits: ["Native", "Apple"])),
            ]
        ),
        .testTarget(
            name: "SettingsCoreTests",
            dependencies: [
                "SettingsCore",
                .product(name: "DBus", package: "DBus", condition: .when(platforms: [.linux, .macOS])),
            ]
        ),
    ]
)
