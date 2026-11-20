//
//  main.swift
//  CoreApps
//

// The calculator as a program on Cacao: swift run --traits Native calculator

#if Native

import Calculator

CalculatorApp.main()

#else

print("calculator is a native program: build it with --traits Native.")
print("As a guest, the app is the Calculator library product, which AppRuntime's guest.py builds into a bundle.")

#endif
