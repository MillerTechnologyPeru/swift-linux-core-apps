//
//  main.swift
//  CoreApps
//

// The software store as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native software [AppRuntime bundle to install]
//     swift run --traits Apple software

#if Native || Apple

import Software

SoftwareApp.main()

#else

print("software is a program: build it with --traits Native, or --traits Apple.")

#endif
