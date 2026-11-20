//
//  main.swift
//  CoreApps
//

// The file manager as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native files [folder]
//     swift run --traits Apple files [folder]

#if Native || Apple

import Files

FilesApp.main()

#else

print("files is a program: build it with --traits Native, or --traits Apple.")

#endif
