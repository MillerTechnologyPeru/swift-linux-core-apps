//
//  main.swift
//  CoreApps
//

// The music player as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native music [folder]
//     swift run --traits Apple music [folder]

#if Native || Apple

import Music

MusicApp.main()

#else

print("music is a program: build it with --traits Native, or --traits Apple.")

#endif
