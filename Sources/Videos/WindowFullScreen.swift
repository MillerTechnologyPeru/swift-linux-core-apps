//
//  WindowFullScreen.swift
//  CoreApps
//

#if Native
import CSDL3
#elseif Apple && os(macOS)
import AppKit
#endif

/// Takes the app's window to the whole screen and back, on a desktop. On
/// a phone, and for a guest, whose host decides, the cover already fills
/// the screen and this does nothing. Views call it, on the main thread.
enum WindowFullScreen {

    static func set(_ isFullScreen: Bool) {
        #if Native
        // Cacao's window is SDL's; the one with the keyboard is the app's.
        guard let window = SDL_GetKeyboardFocus() else { return }
        _ = SDL_SetWindowFullscreen(window, isFullScreen)
        #elseif Apple && os(macOS)
        MainActor.assumeIsolated {
            guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first,
                  window.styleMask.contains(.fullScreen) != isFullScreen else { return }
            window.toggleFullScreen(nil)
        }
        #else
        _ = isFullScreen
        #endif
    }
}
