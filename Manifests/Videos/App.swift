// The video player's manifest. Build its bundle from AppRuntime's checkout:
//
//     Scripts/guest.py bundle --package <this repository> --manifest <this file>
import AppManifest

let app = App(
    id: "org.pureswift.videos",
    name: .localized("app.name"),
    version: "0.1", build: 1,
    languages: ["en"],
    product: "Videos",
    // Sound, for the videos' own; the network, for videos played from an
    // address; and the system's picker, for files.
    capabilities: [.audio, .network, .userFiles],
    platforms: [.linux]
)
