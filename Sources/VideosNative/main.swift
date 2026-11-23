//
//  main.swift
//  CoreApps
//

// The video player as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native videos [file or address]
//     swift run --traits Apple videos

#if Native || Apple

import Videos

VideosApp.main()

#else

print("videos is a program: build it with --traits Native, or --traits Apple.")
print("As a guest, the app is the Videos library product, which AppRuntime's guest.py builds into a bundle.")

#endif
