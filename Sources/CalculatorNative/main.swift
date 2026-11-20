//
//  main.swift
//  CoreApps
//

// The calculator as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native calculator
//     swift run --traits Apple calculator

#if Native || Apple

import Calculator

CalculatorApp.main()

#else

print("calculator is a program: build it with --traits Native, or --traits Apple.")
print("As a guest, the app is the Calculator library product, which AppRuntime's guest.py builds into a bundle.")

#endif
