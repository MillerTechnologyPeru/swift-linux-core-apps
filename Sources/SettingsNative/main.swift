//
//  main.swift
//  CoreApps
//

// Settings as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native settings
//     swift run --traits Apple settings

#if Native || Apple

import Settings

SettingsApp.main()

#else

print("settings is a program: build it with --traits Native, or --traits Apple.")

#endif
