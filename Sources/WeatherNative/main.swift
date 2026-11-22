//
//  main.swift
//  CoreApps
//

// The weather as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native weather [a kept place]
//     swift run --traits Apple weather

#if Native || Apple

import Weather

WeatherApp.main()

#else

print("weather is a program: build it with --traits Native, or --traits Apple.")

#endif
