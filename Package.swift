// swift-tools-version:6.4
import PackageDescription

/// The core apps for Swift Linux.
///
/// Each app is written once, in the part of SwiftUI that both of its hosts
/// draw, and builds in one of two flavors, chosen by a package trait:
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
///
/// Apps import `AppUI`, which re-exports the flavor's SwiftUI.
let package = Package(
    name: "CoreApps",
    platforms: [
        .macOS(.v14),
        .iOS(.v15),
    ],
    products: [
        // Guest products: what `guest.py` builds a bundle from.
        .library(name: "Calculator", type: .static, targets: ["Calculator"]),
        // Native programs.
        .executable(name: "calculator", targets: ["CalculatorNative"]),
        .executable(name: "files", targets: ["FilesNative"]),
        // Shared.
        .library(name: "AppUI", targets: ["AppUI"]),
        .library(name: "CoreAppsUI", targets: ["CoreAppsUI"]),
        .library(name: "CalculatorCore", targets: ["CalculatorCore"]),
        .library(name: "FilesCore", targets: ["FilesCore"]),
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
        // The calculator as a program. Named apart from the app's library:
        // file systems that ignore case would give the two one directory.
        .executableTarget(
            name: "CalculatorNative",
            dependencies: [
                .target(name: "Calculator", condition: .when(traits: ["Native"])),
            ]
        ),
        .testTarget(
            name: "CalculatorCoreTests",
            dependencies: ["CalculatorCore"]
        ),

        // MARK: - Files

        // What the file manager knows of the file system. It uses
        // Foundation: the file manager is a native app.
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
                .target(name: "Files", condition: .when(traits: ["Native"])),
            ]
        ),
        .testTarget(
            name: "FilesCoreTests",
            dependencies: ["FilesCore"]
        ),
    ]
)
