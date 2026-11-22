//
//  main.swift
//  CoreApps
//

// The calendar as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native calendar [.ics file to import]
//     swift run --traits Apple calendar

#if Native || Apple

import Datebook

CalendarApp.main()

#else

print("calendar is a program: build it with --traits Native, or --traits Apple.")

#endif
