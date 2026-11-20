// The calculator's manifest. Build its bundle from AppRuntime's checkout:
//
//     Scripts/guest.py bundle --package <this repository> --manifest <this file>
import AppManifest

let app = App(
    id: "org.pureswift.calculator",
    name: .localized("app.name"),
    version: "0.1", build: 1,
    languages: ["en"],
    product: "Calculator",
    capabilities: [],
    platforms: [.linux]
)
