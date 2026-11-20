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

#else

// An AppRuntime guest: the frontend that sends a host's renderer the views.
@_exported import DynamicRuntime
@_exported import DynamicSwiftUI

#endif
