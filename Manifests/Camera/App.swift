// The camera's manifest. Build its bundle from AppRuntime's checkout:
//
//     Scripts/guest.py bundle --package <this repository> --manifest <this file>
import AppManifest

let app = App(
    id: "org.pureswift.camera",
    name: .localized("app.name"),
    version: "0.1", build: 1,
    languages: ["en"],
    product: "Viewfinder",
    // The camera, and the microphone for videos' sound.
    capabilities: [
        .camera(usage: .localized("perm.camera")),
        .microphone(usage: .localized("perm.microphone")),
    ],
    platforms: [.linux]
)
