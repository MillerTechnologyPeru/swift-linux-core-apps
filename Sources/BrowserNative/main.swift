//
//  main.swift
//  CoreApps
//

// The web browser as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native browser [address or search]
//     swift run --traits Apple browser

#if Native || Apple

import Browser

BrowserApp.main()

#else

print("browser is a program: build it with --traits Native, or --traits Apple.")
print("As a guest, the app is the Browser library product, which AppRuntime's guest.py builds into a bundle.")

#endif
