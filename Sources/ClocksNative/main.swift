//
//  main.swift
//  CoreApps
//

// The clocks as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native clocks
//     swift run --traits Apple clocks

#if Native || Apple

import Clocks

ClocksApp.main()

#else

print("clocks is a program: build it with --traits Native, or --traits Apple.")

#endif
