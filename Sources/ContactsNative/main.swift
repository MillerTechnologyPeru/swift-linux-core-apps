//
//  main.swift
//  CoreApps
//

// The contacts as a program, on Cacao or on Apple's SwiftUI:
//
//     swift run --traits Native contacts [vCard file to import]
//     swift run --traits Apple contacts

#if Native || Apple

import AddressBook

ContactsApp.main()

#else

print("contacts is a program: build it with --traits Native, or --traits Apple.")

#endif
