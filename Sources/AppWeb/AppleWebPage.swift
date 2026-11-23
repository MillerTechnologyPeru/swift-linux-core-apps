//
//  AppleWebPage.swift
//  CoreApps
//

#if Apple

import Observation
import SwiftUI
import WebKit

/// What started a navigation, as AppRuntime names it.
public enum WebNavigationKind: Int32, Sendable {
    case linkActivated = 0
    case formSubmitted = 1
    case backForward = 2
    case reload = 3
    case other = 4
}

/// A navigation a page is about to make, for `WebPage.navigationDecider`.
public struct WebNavigation: Equatable, Sendable {

    public var url: String

    public var kind: WebNavigationKind

    /// `false` for a frame inside the page.
    public var isMainFrame: Bool

    public init(url: String, kind: WebNavigationKind, isMainFrame: Bool) {
        self.url = url
        self.kind = kind
        self.isMainFrame = isMainFrame
    }
}

/// Why a navigation or a script failed, as AppRuntime has it.
public struct WebError: Error, Equatable, Sendable {

    public enum Code: Int32, Sendable {
        case unknown = 0
        case cancelled = 1
        case network = 2
        case timedOut = 3
        case security = 4
        case badURL = 5
        case javaScript = 6
        case notPermitted = 7
    }

    public var code: Code

    public var message: String

    public init(_ code: Code, message: String = "") {
        self.code = code
        self.message = message
    }

    /// The code for an error from WebKit or the URL loading system; `nil`
    /// for a navigation that was only cancelled, by another or by a
    /// decision.
    init?(_ error: any Error) {
        let error = error as NSError
        switch (error.domain, error.code) {
        case (NSURLErrorDomain, NSURLErrorCancelled), ("WebKitErrorDomain", 102):
            return nil
        case (NSURLErrorDomain, NSURLErrorTimedOut):
            self.init(.timedOut, message: error.localizedDescription)
        case (NSURLErrorDomain, NSURLErrorUnsupportedURL), (NSURLErrorDomain, NSURLErrorBadURL),
             (NSURLErrorDomain, NSURLErrorFileDoesNotExist), ("WebKitErrorDomain", 101):
            self.init(.badURL, message: error.localizedDescription)
        case (NSURLErrorDomain, NSURLErrorSecureConnectionFailed),
             (NSURLErrorDomain, NSURLErrorServerCertificateUntrusted),
             (NSURLErrorDomain, NSURLErrorServerCertificateHasBadDate),
             (NSURLErrorDomain, NSURLErrorServerCertificateNotYetValid),
             (NSURLErrorDomain, NSURLErrorServerCertificateHasUnknownRoot),
             (NSURLErrorDomain, NSURLErrorAppTransportSecurityRequiresSecureConnection):
            self.init(.security, message: error.localizedDescription)
        case (NSURLErrorDomain, _):
            self.init(.network, message: error.localizedDescription)
        default:
            self.init(.unknown, message: error.localizedDescription)
        }
    }
}

/// A page of web content, as AppRuntime's `WebPage` is: the part the apps
/// use, over a `WKWebView`. Show it with `WebView(page)`.
///
/// It's observable: a view that reads `title` or `estimatedProgress` is
/// updated as the page loads.
@MainActor
@Observable
public final class WebPage {

    // MARK: State

    /// The main frame's URL, once a navigation has committed.
    public private(set) var url: String?

    public private(set) var title = ""

    public private(set) var isLoading = false

    /// 0…1.
    public private(set) var estimatedProgress: Double = 0

    public private(set) var canGoBack = false

    public private(set) var canGoForward = false

    /// Why the last navigation failed; `nil` again once another starts.
    public private(set) var error: WebError?

    /// Asked before each navigation the page or the person starts; `false`
    /// stops it. Loads the app asks for aren't asked about.
    @ObservationIgnored public var navigationDecider: ((WebNavigation) -> Bool)?

    /// Called when a navigation finishes without failing.
    @ObservationIgnored public var onFinish: (() -> Void)?

    // MARK: The view

    @ObservationIgnored let webView: WKWebView

    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    @ObservationIgnored private lazy var navigationDelegate = NavigationDelegate(page: self)

    public init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = navigationDelegate
        observe()
    }

    // MARK: Loading

    public func load(_ url: String) {
        guard let address = URL(string: url), address.scheme != nil else {
            error = WebError(.badURL, message: "\(url) isn't a URL")
            return
        }
        error = nil
        navigationDelegate.expectsOwnNavigation = true
        if address.isFileURL {
            webView.loadFileURL(address, allowingReadAccessTo: address.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: address))
        }
    }

    public func load(html: String, baseURL: String? = nil) {
        error = nil
        navigationDelegate.expectsOwnNavigation = true
        webView.loadHTMLString(html, baseURL: baseURL.flatMap(URL.init(string:)))
    }

    public func reload() {
        error = nil
        webView.reload()
    }

    public func stopLoading() {
        webView.stopLoading()
    }

    public func goBack() {
        webView.goBack()
    }

    public func goForward() {
        webView.goForward()
    }

    // MARK: Following the view

    private func observe() {
        observations = [
            webView.observe(\.url) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.url = view.url?.absoluteString }
            },
            webView.observe(\.title) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.title = view.title ?? "" }
            },
            webView.observe(\.isLoading) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.isLoading = view.isLoading }
            },
            webView.observe(\.estimatedProgress) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.estimatedProgress = view.estimatedProgress }
            },
            webView.observe(\.canGoBack) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.canGoForward) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.canGoForward = view.canGoForward }
            },
        ]
    }

    fileprivate func started() {
        error = nil
    }

    fileprivate func failed(_ error: any Error) {
        guard let error = WebError(error) else { return }
        self.error = error
    }

    fileprivate func finished() {
        onFinish?()
    }
}

/// The page's answers to its view.
@MainActor
private final class NavigationDelegate: NSObject, WKNavigationDelegate {

    unowned let page: WebPage

    /// The app asked for the next navigation itself, so it isn't asked
    /// about it.
    var expectsOwnNavigation = false

    init(page: WebPage) {
        self.page = page
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        let isMainFrame = action.targetFrame?.isMainFrame ?? true
        if expectsOwnNavigation, isMainFrame {
            expectsOwnNavigation = false
            return decisionHandler(.allow)
        }
        guard let decider = page.navigationDecider, let url = action.request.url?.absoluteString else {
            return decisionHandler(.allow)
        }
        let kind: WebNavigationKind = switch action.navigationType {
        case .linkActivated: .linkActivated
        case .formSubmitted, .formResubmitted: .formSubmitted
        case .backForward: .backForward
        case .reload: .reload
        default: .other
        }
        let allowed = decider(WebNavigation(url: url, kind: kind, isMainFrame: isMainFrame))
        if allowed, action.targetFrame == nil {
            // A link to a new window loads here.
            webView.load(action.request)
            return decisionHandler(.cancel)
        }
        decisionHandler(allowed ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        page.started()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        page.failed(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        page.failed(error)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        page.finished()
    }
}

/// Shows a page's `WKWebView`. It takes the space it's offered.
public struct WebView: View {

    let page: WebPage

    public init(_ page: WebPage) {
        self.page = page
    }

    public var body: some View {
        WebViewRepresentable(webView: page.webView)
    }
}

#if os(iOS)

private struct WebViewRepresentable: UIViewRepresentable {

    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }

    func updateUIView(_ view: WKWebView, context: Context) { }
}

#else

private struct WebViewRepresentable: NSViewRepresentable {

    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }

    func updateNSView(_ view: WKWebView, context: Context) { }
}

#endif

#endif
