//
//  main.swift
//  CoreApps
//

// The file manager: swift run --traits Native files

#if Native

import Files

FilesApp.main()

#else

print("files is a native program: build it with --traits Native.")

#endif
