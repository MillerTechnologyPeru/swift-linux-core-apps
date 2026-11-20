# Core apps for Swift Linux: plan

2026-11-20

## Summary

Cacao becomes the only toolkit in the base image. Fifteen core apps are written in SwiftUI with phone-width layouts first: 13 as AppRuntime bundles and 2 as native Cacao apps (file manager and software store).

Four things decide the plan:

1. **GTK is more than widgets.** A GNOME app also gets settings storage, file choosers, notifications, icons and app activation from the platform. Those services come before most apps.
2. **The sandbox decides the split.** An AppRuntime app sees only its bundle and its own container, has no window API and cannot start processes. The file manager and the store cannot work inside that.
3. **Mobile first needs toolkit work.** Cacao has no swipe on rows, no sheet detents and no separate keyboard safe area today. An on-screen keyboard is a shell piece that does not exist yet.
4. **Several apps need the background.** AppRuntime today has no sockets, no background network sessions and foreground-only audio. Email, music, calendar and clocks all need something to run while the app is closed.

Seven apps come first: file manager, image viewer, music player, text editor, video player, web browser and maps. They are the ones that lean hardest on the base plan, so its `ExternalSurface`, WebKit and text-engine work moves to the front.

Flatpak carries existing GTK and Qt apps. Their toolkits live in Flatpak runtimes, so nothing in the base image links GTK.

The plan comes from reading the repos and docs. The status below is what has since been built and run.

## Status

What exists as of 2026-11-20, against the prerequisites this plan names. "Merged" means on Cacao's `develop`; "on a branch" means pushed to `feature/host-input` and not merged.

| Prerequisite | State | Checked on |
| --- | --- | --- |
| Cacao split into render, compositor and host | Merged | macOS, Debian 13 |
| `ExternalSurface`, pixels and shared GPU buffers | Merged | Pixels on macOS and Linux; dma-bufs imported on an Intel GPU |
| Input routed to external content (pointer, keys, scroll, touch, text) | Merged | Debian 13 (X11), Debian tablet (Wayland), postmarketOS phone |
| Size classes from the window's size | On a branch | macOS tests; the phone |
| Split view collapsing to one column | On a branch | macOS tests; the phone |
| Scrolling with a finger | On a branch | The phone and the tablet. **Content does not coast after a flick; not diagnosed.** |
| Switch that slides and can be dragged | On a branch | macOS tests only |
| CMake builds of Silica and Cacao; Buildroot packages | Merged | A container simulation; no real Buildroot build |
| Pinch zoom on a touch screen | Not started | Two fingers reach external content separately; nothing turns them into a magnify gesture for SwiftUI views |
| Keyboard safe area, sheet detents, row swipe, pull to refresh | Not started | |
| WebKit repo, JSC repo, shared text engine | Not started | |

Touch input has now been tried by hand on two Linux devices, which the last risk in this plan asked for. It found three faults, two fixed (each finger was delivered twice; scroll views ignored fingers) and one open (no coasting).

Cacao runs on postmarketOS only through a glibc root filesystem in a sandbox, because postmarketOS uses musl. A native build needs a Swift toolchain that targets musl with shared system libraries.

## The apps

Size is relative: S is days of UI work on finished platform pieces, L needs a new engine, contract or service.

| App | Where | Needs beyond what exists | Size |
| --- | --- | --- | --- |
| Calculator | AppRuntime | Nothing | S |
| Clocks | AppRuntime | `Notifications`; a system alarm service so alarms fire while the app is closed | M |
| Weather | AppRuntime | `HTTPClient` and `Location` on the Linux host | M |
| Contacts | AppRuntime | `Persistence`; a shared contacts store other apps can query; document picker for vCard | M |
| Image viewer | AppRuntime | Document picker; JPEG, WebP and HEIF decoders in Silica; pinch zoom | M |
| Music player | AppRuntime | `MediaPlayer` on Linux; background playback; media keys and lock-screen controls | M |
| Calendar | AppRuntime | `Persistence`, `Notifications`; CalDAV over `HTTPClient`; date and recurrence logic without Foundation | L |
| Text editor | AppRuntime | Document picker; a text view in Cacao that handles large files, undo and find | L |
| Video player | AppRuntime | `MediaPlayer` with video frames through `ExternalSurface` | L |
| Web browser | AppRuntime | `WebKit` contract; tabs, downloads, history; touch scrolling and zoom in the web view | L |
| Camera | AppRuntime | A `Camera` contract over PipeWire or V4L2; preview through `ExternalSurface` | L |
| Maps | AppRuntime | `Location`, `HTTPClient`; a tile renderer; a search and routing service | L |
| Email client | AppRuntime | A TLS stream contract for IMAP and SMTP, or JMAP over `HTTPClient`; a secrets contract; background sync; MIME parsing in the guest; HTML bodies in a locked-down web view | L |
| File manager | Native | Whole filesystem, mounts, trash, thumbnails; also hosts the system file picker | L |
| Software store | Native | Installs and removes software, applies OS updates; plugin backends (below) | L |

Settings and a terminal are not in this list. The OS still needs at least a Settings app to join Wi-Fi and pair devices, so phase D assumes one exists or is added.

### Rule for future apps

| Question | If yes |
| --- | --- |
| Does it work with only its own data, plus files the user hands it? | AppRuntime |
| Does it need a capability phones also have (camera, location, notifications)? | AppRuntime, adding the contract if it is missing |
| Does it need the whole filesystem, other processes, or system daemons? | Native Cacao app |

Write the two native apps in the same SwiftUI subset the AppRuntime frontend supports, so screens and components are shared.

## Mobile-optimized SwiftUI

Every app is designed at phone width first and widens to tablet and desktop.

| Need | Cacao today | Work |
| --- | --- | --- |
| Size classes | On a branch: `horizontalSizeClass` and `verticalSizeClass` from the window size, compact below 678 points wide | Merge; settle the threshold, which was chosen inside a measured range of 657 to 739 points |
| Split view collapsing to a stack | On a branch: one column at compact width | Merge; three-column split views are untested |
| Scrolling with a finger | On a branch, without coasting | Find why a flick does not coast on a device |
| Row swipe actions | Shown in the context menu; no swipe | Real swipe with touch |
| Sheet detents | `presentationDetents` is accepted with no effect | Half and full-height sheets with drag |
| Pull to refresh | `refreshable` only sets the action | Draw and drive the indicator |
| On-screen keyboard | The keyboard's safe area is not separate | A shell keyboard, plus a keyboard safe area so content moves above it |
| Rotation and safe areas | Window safe area comes from SDL | Rotation handling in the shell and host |
| Touch targets and text size | Not audited. Beside iOS on a phone, rows are about 44 points tall where iOS's are about 51 | Minimum target size in the component package; dynamic type from the system store |

The AppRuntime render IR already has nodes for swipe actions, sheets, refresh, search and tabs, so guests need no change once Cacao draws them properly.

## Software store

A native Cacao app with a small core and one plugin per source of software.

| Plugin | Installs | Notes |
| --- | --- | --- |
| AppRuntime bundles | First-party and third-party `.app` bundles | Uses the existing `linux-app` packager and the bundle sandbox |
| Flatpak | Flathub and other remotes | Carries GTK and Qt apps with their own runtimes |
| OS updates | The A/B root slots | Download, verify, switch slot, reboot |
| Others later | For example PortMaster ports | Same plugin interface |

**Plugin design.** Run each plugin as its own process speaking a small protocol (search, details, install, remove, update, progress). A crash or a slow remote then cannot take down the store, and a plugin can be written in any language. In-process dynamic libraries would be simpler but tie plugins to the store's Swift ABI.

**What Flatpak needs on the OS.** To be confirmed against current Flatpak:

- libflatpak, OSTree and bubblewrap, which use GLib and fit the GLib-on-Linux rule.
- User namespaces and FUSE in the kernel.
- A D-Bus session bus and `xdg-dbus-proxy`.
- A writable location for installs, since the root is read-only.
- `xdg-desktop-portal` with a portal backend. Flatpak apps ask portals for the file chooser, notifications and the dark-mode setting, so the backend should be written on Cacao and reuse the picker and notification services from phase A. Without it, sandboxed GTK apps get no file dialogs.

## What replaces GTK's platform services

| GTK / GNOME piece | Replacement | State today |
| --- | --- | --- |
| Widgets, libadwaita patterns | Cacao, plus a small component package (settings rows, toasts, empty states) | Cacao covers the controls; the package is new |
| GSettings / dconf | AppRuntime `Defaults` per app; one system store for appearance, text size, locale | `Defaults` exists; the system store is new |
| Dark mode, accent, text scale | Cacao environment values driven by the system store, updating live | Cacao reads SDL's system theme only |
| File chooser, portals | A picker service owned by the file manager; a document-picker contract; the portal backend above | Cacao's host shows SDL's dialogs, which fall back to a GTK tool |
| Notifications | A shell notification service; a `Notifications` contract | Capability is named in AppRuntime's table; no contract yet |
| Icon theme | A full symbol set behind `Image(systemName:)` | About 60 symbols drawn by Cacao |
| App activation, open-with, URL schemes | Launch services reading document types from each bundle's `Info.plist` | Packager writes a `.desktop` file and icon |
| Accounts | One accounts service for mail, calendar and contacts servers, with a secrets store | Nothing yet |
| Background work | A system service that runs sync, alarms and playback for apps | Nothing yet |
| Accessibility (AT-SPI) | An AT-SPI bridge in Cacao | Missing |
| Media playback | `MediaPlayer` over one media stack | Contract specified; Linux host not written |

## Phases

The first wave is the seven apps to ship first: file manager, image viewer, music player, text editor, video player, web browser and maps. They are the content-heavy ones, so the work they depend on moves to the front.

### What the first wave pulls forward

| Prerequisite | Needed by | Comes from |
| --- | --- | --- |
| Cacao split and `ExternalSurface` | Video player, Web browser, Maps | Base phases 1 and 2. Done |
| WebKit repo with the Cacao web view | Web browser | Base phase 5, which needs the JSC repo from base phase 4 |
| Media stack choice and `MediaPlayer` on the Linux host | Music player, Video player | New; decision 5 |
| Large-file text view on the shared text engine | Text editor | Base phase 6, text part only |
| JPEG, WebP and HEIF decoders in Silica | Image viewer, File manager thumbnails | New |
| Launch services with document types and open-with | All seven | Phase A item 5 |
| Picker service and document-picker contract | Image viewer, Text editor, both players | File manager, phase B item 2 |
| `HTTPClient` and `Location` on the Linux host | Maps, Web browser downloads | Phase B item 1 |
| Size classes, pinch zoom, keyboard safe area | All seven at phone width | Phase A item 1. Size classes are on a branch |

Perry moving onto the engine (base phase 3) is not needed by these apps and can run in parallel or after.

### Phase A: platform and mobile toolkit (starts now)

1. Mobile work in Cacao from the table above. Size classes are written; pinch zoom and the keyboard safe area are next.
2. Component package and visual language.
3. System settings store driving color scheme and text size.
4. Full symbol set.
5. Launch services: install location, document types, open-with.
6. Shell services on Cacao: picker, on-screen keyboard, then notifications. These need layer-shell support in the host.

Gate: a test app at phone width rotates, shows the keyboard without covering its field, and opens a file through the picker, with no GTK library loaded.

### Phase B: AppRuntime contracts

1. `HTTPClient` and `Location` on the Linux host.
2. The document picker, on Linux and Darwin together.
3. `MediaPlayer` on the Linux host, audio first, then video frames through `ExternalSurface`. Include background playback for the music player.
4. Second wave only: `Clipboard`, `Notifications`, `Device`, `Camera`, the wider background model, TLS stream and secrets.

Gate: each new contract passes one conformance test on both the Linux and Darwin hosts.

### Phase C: first wave, in this order

1. **File manager** (native). It owns the picker and open-with, which the other six use.
2. **Image viewer.** The smallest content app; proves the open-with path and the decoders.
3. **Music player.** Proves `MediaPlayer`, background playback and media keys.
4. **Text editor.** Lands when the large-file text view does.
5. **Video player.** Lands when video in `MediaPlayer` does.
6. **Web browser.** Lands when the WebKit repo does.
7. **Maps.** Last, because it also needs a tile renderer and outside services for search and routing.

Items 2 to 4 need none of the base plan's engine work, so they can ship while base phases 4 and 5 are in progress.

Gate: from the file manager, open a photo, a song, a text file, a video and a web link, each in its own app, at phone width and at desktop width.

### Phase D: software store

The store with the AppRuntime and OS-update plugins, then Flatpak with the portal backend. Until it exists, the first-wave apps ship in the OS image.

Gate: on a fresh image, install an AppRuntime app and a Flathub GTK app from the store, and open a file from each through the same picker.

### Phase E: second wave

Calculator, Clocks, Weather, Contacts, Calendar, Camera, Email. Calculator, Weather and Contacts are small and can fill gaps earlier. Email is last because it needs the most new pieces.

## Decisions to make first

1. **Shell and compositor.** Who draws the panel, launcher, lock screen and keyboard decides how the phase A services attach. A phone-style shell is its own project.
2. **Background model.** One system service that apps register work with, or always-running helper processes per app. This shapes Email, Music, Calendar and Clocks.
3. **Email protocol.** IMAP and SMTP need a socket contract and a mail parser in the guest. JMAP needs only `HTTPClient` but few providers offer it. Gmail and Outlook also require registered OAuth client IDs.
4. **Maps data.** Which tile, search and routing services, and whether offline maps matter.
5. **Media stack.** GStreamer fits the GLib rule and WPE already uses it; FFmpeg is smaller.
6. **Guest limits.** Guests are Embedded Swift with no Foundation. Calendar, Contacts, Email and Text editor need date arithmetic, time zones, collation and text encodings. Decide what the formatting contract grows to cover and what ships as guest libraries.
7. **Licensing.** GNOME's apps are GPL. Writing new apps from their behaviour is different from translating their source, which would carry the licence. Check with a lawyer if the apps are meant to be permissively licensed.
8. **C library.** postmarketOS uses musl, and Cacao has only been built for glibc. Either the image is glibc, or the toolchain and every dependency are built for musl.

## Risks

- **Email is the largest app.** Protocols, parsing, HTML rendering with remote content blocked, credentials and background sync are each sizeable. It could become native if the guest limits bite.
- **Flatpak pulls in a second world.** Portals, the session bus and Flatpak's own sandbox sit beside the bundle sandbox. The store must present both as one catalogue.
- **Two UI stacks.** Guests draw through the render IR and native apps through Cacao directly. Anything the IR lacks pushes an app toward native.
- **Text editing.** The text editor, email composer and every text field depend on one text engine that does not exist yet in shared form.
- **Touch input has had one pass.** Fingers, a trackpad and keys were tried by hand on a tablet and a phone. Input methods have not, and scrolling does not coast.
