//
//  AppWeb.swift
//  CoreApps
//

// Web pages, as the flavor being built has them, in AppRuntime's shape: a
// `WebPage` the app loads and moves through, and a `WebView` that shows
// it. Apps import this module instead of a web framework, as they import
// `AppUI` instead of a toolkit.
//
// - A guest's pages are AppRuntime's `DynamicWebKit`: the host loads and
//   draws them, on Linux in WPE WebKit.
// - A program on Cacao has PureSwift/WebKit's `CacaoWebKit`, whose pages
//   are WPE WebKit's, opened at run time and drawn into Cacao's external
//   surfaces.
// - A program on Apple's SwiftUI has the `WebPage` and `WebView` in
//   AppleWebPage.swift, over WKWebView.
//
// All three have the same names. Apps keep to the part they share: loading,
// the title and progress, back and forward, errors, and deciding
// navigations.

#if Native

@_exported import CacaoWebKit

#elseif !Apple

// guest.py names it `WebKit` in a bundle.
#if canImport(DynamicWebKit)
@_exported import DynamicWebKit
#else
@_exported import WebKit
#endif

#endif
