//
//  main.swift
//  CoreApps
//

// The text editor as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native text-editor [file or folder]
//     swift run --traits Apple text-editor [file or folder]

#if Native || Apple

import Editor

EditorApp.main()

#else

print("text-editor is a program: build it with --traits Native, or --traits Apple.")

#endif
