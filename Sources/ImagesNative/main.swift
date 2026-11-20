//
//  main.swift
//  CoreApps
//

// The image viewer as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native images [image or folder]
//     swift run --traits Apple images [image or folder]

#if Native || Apple

import Images

ImagesApp.main()

#else

print("images is a program: build it with --traits Native, or --traits Apple.")

#endif
