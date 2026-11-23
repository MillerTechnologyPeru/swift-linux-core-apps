//
//  AppUI.swift
//  CoreApps
//

// SwiftUI, as the flavor being built provides it. Apps and their shared
// components import this module instead of a toolkit, and keep to what
// both flavors have.

#if Native

// A program on Cacao: SwiftUI in Swift, with its SDL host. Foundation
// comes with it, as with SwiftUI: off Apple's platforms that is where
// `CGFloat` and the other geometry types are.
@_exported import Cacao
@_exported import CacaoSDL
@_exported import Foundation

#elseif Apple

// A program on Apple's SwiftUI, on macOS and iOS.
@_exported import SwiftUI

#else

// An AppRuntime guest: the frontend that sends a host's renderer the views.
// AppRuntime's guest.py names it `SwiftUI`, as guest code calls it; a host
// build of this package can't, since Apple's SDK has a SwiftUI.
@_exported import DynamicRuntime
#if canImport(DynamicSwiftUI)
@_exported import DynamicSwiftUI
#else
@_exported import SwiftUI
#endif

#endif
