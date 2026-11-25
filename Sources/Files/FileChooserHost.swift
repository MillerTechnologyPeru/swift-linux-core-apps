//
//  FileChooserHost.swift
//  CoreApps
//

// The file chooser answers the desktop portal over D-Bus, on Linux, with
// windows Cacao opens: only on Cacao.
#if Native

import AppUI
import CacaoHost
import FilesCore
import FilesPortal
import Foundation

/// A request on screen, until it's answered or the app closes it.
@MainActor
final class FileChooserDialog: ObservableObject {

    let request: FileChooserRequest

    /// Whether the app closed the request, and the window should go.
    @Published fileprivate(set) var isClosed = false

    fileprivate var continuation: CheckedContinuation<FileChooserResponse, Never>?

    fileprivate init(request: FileChooserRequest, continuation: CheckedContinuation<FileChooserResponse, Never>) {
        self.request = request
        self.continuation = continuation
    }
}

/// Where the portal's requests meet the program's windows: each request
/// waits here for a window of the file chooser's group to show it, and for
/// its answer.
///
/// Run as `files --file-chooser`, D-Bus starts the program for the first
/// request, whose window is the first to open; later ones open windows
/// through `openWindow`. `files --desktop` serves requests the same way
/// beside the desktop.
@MainActor
final class FileChooserHost: ObservableObject {

    nonisolated static let shared = FileChooserHost()

    /// The window group the dialogs open in.
    static let windowID = "file-chooser"

    /// How long the program stays after its last dialog closes, for the
    /// next one to open quickly.
    static let lingering: TimeInterval = 60

    /// The requests being answered, by handle.
    @Published private(set) var dialogs: [String: FileChooserDialog] = [:]

    /// Requests no window has asked for yet, oldest first.
    private var waiting: [String] = []

    /// Requests the app closed before they reached this host.
    private var closedEarly: Set<String> = []

    /// What opens windows, once a view has given it.
    private var openWindow: OpenWindowAction?

    /// Whether the oldest request waits for the program's first window,
    /// which opens with no value, rather than getting a window of its own.
    var reservesFirstRequest = false

    private var lastActivity = Date()

    /// The backend, once serving. Set once, before any request.
    nonisolated(unsafe) private(set) var backend: FileChooserBackend?

    /// Signalled when the first request comes, off the main actor: the
    /// program waits for it before it opens any window.
    nonisolated let firstRequest = DispatchSemaphore(value: 0)

    nonisolated(unsafe) private var hasSignalled = false

    nonisolated private init() { }

    // MARK: Serving

    /// Serves the portal on the session bus, unless another program does.
    /// Returns whether this one does.
    nonisolated static func serve() async -> Bool {
        do {
            let (backend, owns) = try await FileChooserBackend.start { request in
                await shared.present(request)
            }
            shared.backend = backend
            if !owns {
                print("files: another program is the file chooser")
            }
            return owns
        } catch {
            print("files: can't serve the file chooser: \(error)")
            return false
        }
    }

    /// Answers a request once a window has shown it, or with `.other` once
    /// the app closes it.
    nonisolated func present(_ request: FileChooserRequest) async -> FileChooserResponse {
        let handle = request.handle
        if !hasSignalled {
            hasSignalled = true
            firstRequest.signal()
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                Task { @MainActor in
                    self.add(request, continuation: continuation)
                }
            }
        } onCancel: {
            Task { @MainActor in
                self.close(handle)
            }
        }
    }

    private func add(_ request: FileChooserRequest, continuation: CheckedContinuation<FileChooserResponse, Never>) {
        lastActivity = Date()
        if closedEarly.remove(request.handle) != nil {
            continuation.resume(returning: .other)
            return
        }
        dialogs[request.handle] = FileChooserDialog(request: request, continuation: continuation)
        waiting.append(request.handle)
        openWaitingWindows()
    }

    // MARK: Windows

    /// Takes the oldest request no window has asked for: what the first
    /// window shows, which opens with no value.
    func claimNext() -> FileChooserDialog? {
        guard !waiting.isEmpty else { return nil }
        reservesFirstRequest = false
        return dialogs[waiting.removeFirst()]
    }

    func dialog(for handle: String) -> FileChooserDialog? {
        waiting.removeAll { $0 == handle }
        return dialogs[handle]
    }

    /// Takes a view's way of opening windows, and opens one for each
    /// request waiting.
    func register(_ openWindow: OpenWindowAction) {
        if self.openWindow == nil {
            self.openWindow = openWindow
        }
        openWaitingWindows()
    }

    private func openWaitingWindows() {
        guard let openWindow else { return }
        let handles = reservesFirstRequest ? Array(waiting.dropFirst()) : waiting
        waiting.removeAll { handles.contains($0) }
        for handle in handles {
            openWindow(id: Self.windowID, value: handle)
        }
        HostRuntime.wake()
    }

    /// Keeps the program running with no windows while it serves requests,
    /// and for a while after the last: run as the file chooser alone, it
    /// would otherwise quit when its last dialog closes.
    func keepRunningBetweenDialogs() {
        let keepsRunning: @MainActor () -> Bool = {
            let host = FileChooserHost.shared
            return !host.dialogs.isEmpty || Date().timeIntervalSince(host.lastActivity) < Self.lingering
        }
        HostRuntime.runsWithoutWindows = keepsRunning
        // The first window appears while the host sets up, which then sets
        // its own; this runs again once its loop goes around.
        Task { @MainActor in
            HostRuntime.runsWithoutWindows = keepsRunning
        }
    }

    // MARK: Answers

    /// Answers a request, which ends it.
    func complete(_ handle: String, with response: FileChooserResponse) {
        guard let dialog = dialogs.removeValue(forKey: handle) else { return }
        waiting.removeAll { $0 == handle }
        lastActivity = Date()
        dialog.continuation?.resume(returning: response)
        dialog.continuation = nil
    }

    /// Ends a request the app closed: its window goes, and the app hears
    /// nothing more of it.
    func close(_ handle: String) {
        guard let dialog = dialogs[handle] else {
            closedEarly.insert(handle)
            return
        }
        dialog.isClosed = true
        complete(handle, with: .other)
    }

    /// Ends the requests still open, as the program quits.
    func cancelAll() {
        for handle in Array(dialogs.keys) {
            complete(handle, with: .other)
        }
    }

    /// Waits up to a moment for the answers given to reach the apps.
    nonisolated func waitForAnswers() {
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            for _ in 0 ..< 20 {
                if await (self.backend?.requestsInProgress ?? 0) == 0 { break }
                try? await Task.sleep(for: .milliseconds(50))
            }
            // The last reply is written after its handler returns.
            try? await Task.sleep(for: .milliseconds(200))
            done.signal()
        }
        _ = done.wait(timeout: .now() + 3)
    }
}

#endif
