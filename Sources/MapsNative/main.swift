//
//  main.swift
//  CoreApps
//

// The maps as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native maps [place to find]
//     swift run --traits Apple maps

#if Native || Apple

import Atlas

MapsApp.main()

#else

print("maps is a program: build it with --traits Native, or --traits Apple.")

#endif
