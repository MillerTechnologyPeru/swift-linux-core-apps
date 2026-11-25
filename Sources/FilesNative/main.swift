//
//  main.swift
//  CoreApps
//

// The file manager as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native files [folder]
//     swift run --traits Apple files [folder]
//
// On Cacao it also draws the desktop, as the session starts it: the
// wallpaper and the Desktop folder's icons, in the background layer of the
// screen. A PNG named with `--wallpaper` is drawn instead of the one chosen
// from the desktop's menu.
//
//     files --desktop [--wallpaper image.png]

#if Native || Apple

import Files

FilesApp.main()

#else

print("files is a program: build it with --traits Native, or --traits Apple.")

#endif
