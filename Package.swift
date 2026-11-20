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
///   bundle sandbox (the file manager and the software store), and for
///   running any app on a desktop while working on it:
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
        // Native programs.
        .executable(name: "calculator", targets: ["CalculatorNative"]),
        .executable(name: "files", targets: ["FilesNative"]),
        .executable(name: "images", targets: ["ImagesNative"]),
        .executable(name: "music", targets: ["MusicNative"]),
        // Shared.
        .library(name: "AppUI", targets: ["AppUI"]),
        .library(name: "CoreAppsUI", targets: ["CoreAppsUI"]),
        .library(name: "CalculatorCore", targets: ["CalculatorCore"]),
        .library(name: "FilesCore", targets: ["FilesCore"]),
        .library(name: "ImagesCore", targets: ["ImagesCore"]),
        .library(name: "MusicCore", targets: ["MusicCore"]),
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
    ]
)
