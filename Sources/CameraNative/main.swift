//
//  main.swift
//  CoreApps
//

// The camera as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native camera
//     swift run --traits Apple camera
//
// On Cacao it has no camera yet: Linux capture isn't written.

#if Native || Apple

import Viewfinder

CameraApp.main()

#else

print("camera is a program: build it with --traits Native, or --traits Apple.")
print("As a guest, the app is the Viewfinder library product, which AppRuntime's guest.py builds into a bundle.")

#endif
