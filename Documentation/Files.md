# Files: parity with GNOME Files

2026-11-20

What the file manager does beside what GNOME Files does, feature by feature. The list of GNOME's features comes from its user help; the app was written from that behaviour, not from GNOME's source. Network folders are left out on purpose.

"Tried" says where a feature was last used by hand. Everything under `FilesCore` also has tests, which run on Linux.

## Summary

| Area | Done | Partly | Missing |
| --- | --- | --- | --- |
| Navigation and sidebar | 7 | 1 | 4 |
| Views and sorting | 5 | 1 | 4 |
| Search | 6 | 0 | 2 |
| Selection | 4 | 0 | 2 |
| File operations | 12 | 2 | 6 |
| Trash | 5 | 1 | 1 |
| Properties and permissions | 7 | 1 | 2 |
| Drives and volumes | 4 | 0 | 1 |
| Preferences | 3 | 0 | 3 |
| **All** | **53** | **6** | **25** |

## Navigation and sidebar

| GNOME Files | Here | Tried |
| --- | --- | --- |
| Open folders in place | Done | Cacao, iOS |
| Sidebar of places | Done: Home and the `xdg-user-dirs` folders, Computer, Starred, Trash | Cacao, iOS |
| Path bar, each folder a way up | Done; it doesn't scroll to its end in a deep folder | Cacao, iOS |
| Bookmarks: add, remove, rename | Done, in the file GTK's file choosers read | Read on Debian; adding not tried by hand |
| Starred | Done, in a file of the app's own; GNOME keeps its stars in Tracker, so the two don't share | Not by hand |
| Open with the default program | Done through `xdg-open`, until there are launch services | Not by hand |
| Open in a terminal | Done, with whichever terminal is installed | Not by hand |
| Back and forward | Partly: back only, as a phone has it | |
| Recent | Missing: needs `recently-used.xbel` read and written | |
| Type a path (Ctrl+L) | Missing | |
| Tabs and new windows | Missing | |
| Drag a folder to the sidebar | Missing: Cacao has no drag and drop | |

## Views and sorting

| GNOME Files | Here | Tried |
| --- | --- | --- |
| List and grid | Done | List on Cacao and iOS; grid not by hand |
| Sort by name, modified, size, type | Done | iOS menu |
| Reverse the order | Done | Not by hand |
| Folders before files, or mixed | Done | Not by hand |
| Show hidden files | Done | iOS |
| Thumbnails | Partly: a symbol for each kind, no pictures of the contents | |
| List columns to choose | Missing: rows show size and date only | |
| Grid captions and zoom | Missing | |
| Expandable folders in the list | Missing | |
| Type-ahead | Missing; the search field does the same job | |

## Search

| GNOME Files | Here | Tried |
| --- | --- | --- |
| Search this folder and below | Done; stops at 200 results | Not by hand |
| Whatever the case | Done | |
| Filter by kind | Done | |
| Filter by date | Done | |
| File names or full text | Done for text files up to 2 MB; no index, so it reads each file | |
| Results act like a folder | Done, with "Open Item Location" | |
| Indexed search locations | Missing: there is no index | |
| Search from the shell's overview | Missing: needs the shell | |

## Selection

| GNOME Files | Here | Tried |
| --- | --- | --- |
| Select several | Done, in a selection mode as phones have | iOS |
| Select all, invert | Done | Not by hand |
| Select items matching a pattern | Done, `*` and `?` | Not by hand |
| Act on the selection | Done: cut, copy, trash, rename, duplicate, link, compress, delete | Trash on iOS |
| Ctrl-click, Shift-click | Missing | |
| Rubber band | Missing | |

## File operations

| GNOME Files | Here | Tried |
| --- | --- | --- |
| New folder | Done | iOS |
| New document, from Templates | Done | Empty document on iOS |
| Rename | Done | Tests only |
| Rename several: template with numbers | Done | Tests only |
| Rename several: find and replace | Done | Tests only |
| Cut, copy, paste | Done, within the app | Copy and paste on iOS |
| Duplicate | Done | Not by hand |
| Make a link | Done | Not by hand |
| Compress | Done, to `.tar.gz` with the system's `tar` | Tests on Linux |
| Extract | Done for tar archives and zip, with `tar` and `unzip` | Tests on Linux |
| Undo and redo | Done for create, rename, move, trash and restore | Menu seen on iOS; not used |
| Delete for good, after asking | Done | Not by hand |
| Name conflicts when copying | Partly: both are kept, the newcomer numbered. Replace and skip exist in `FilesCore` with no dialog to choose them | |
| Progress, pause and cancel | Partly: none; operations run to the end on the main thread, so a large copy freezes the window | |
| Clipboard shared with other apps | Missing: Cacao's clipboard carries text | |
| Drag and drop | Missing: Cacao has none | |
| Open with another program | Missing: needs launch services | |
| Rename music from its tags | Missing | |
| Scripts | Missing | |
| Preview with Space | Missing: needs the viewers | |

## Trash

| GNOME Files | Here | Tried |
| --- | --- | --- |
| Move to trash | Done, to freedesktop.org's layout | iOS |
| See the trash | Done | iOS |
| Restore | Done, remaking the folder if it's gone | Tests only |
| Delete one item for good | Done | Tests only |
| Empty, after asking | Done | Not by hand |
| Trash on other volumes | Partly: such items are copied to the home trash rather than a trash on their own volume | |
| Clear the trash by age | Missing | |

## Properties and permissions

| GNOME Files | Here | Tried |
| --- | --- | --- |
| Name, type, size, parent folder | Done | Not by hand |
| Folder's contents and their size | Done; counts up to 20,000 items | |
| Free space | Done | |
| Accessed, modified, created | Done | |
| Owner, group, access for each | Done: the same four levels for folders and three for files | |
| Executable as program | Done | |
| Apply to enclosed files | Done; files keep their own execute bits | Tests only |
| Change the group | Partly: shown, not changed | |
| Image and video details | Missing: needs decoders | |
| Default program for a kind | Missing: needs launch services | |

## Drives and volumes

| GNOME Files | Here | Tried |
| --- | --- | --- |
| Volumes in the sidebar | Done, from UDisks2 on the system bus, mounted or not, without the system's own; they follow disks coming and going. Without UDisks, the mounted ones from `/proc/self/mounts` | A disk image as a loop device, under sway |
| Free space of each | Done | Sway |
| Mount, unmount and eject | Done through UDisks2: a tap mounts and opens, the eject button unmounts and then ejects the media, powers the drive off or detaches the disk image; Unmount in the menu | Sway, with polkit allowing it |
| Not allowed | Done: polkit's refusal is said plainly, naming the missing authentication agent | Sway, with no agent |
| "Volume is busy" | Done, as UDisks reports it | Tests only |
| What to do when media is inserted | Missing: a Settings matter | |

## Desktop

`files --desktop` draws the desktop as well as opening Files windows: a window in the background layer of the screen (a layer-shell surface on sway, anchored to every edge, under the menu bar and dock), which takes the keyboard only when clicked. It replaces swift-linux-shell's stand-in `CacaoDesktop`.

| GNOME (Desktop Icons) | Here | Tried |
| --- | --- | --- |
| Wallpaper | Done: a PNG chosen from the desktop's menu (from Pictures) or named with `--wallpaper`, else the accent gradient, light or dark | Sway |
| The Desktop folder's items as icons | Done, read again every two seconds; no Desktop folder shows none | Sway |
| Open with a double click | Done: folders in a Files window of the same program, files through `xdg-open` | Sway |
| Select | Done, one at a time | Sway |
| Drag to rearrange | Done, snapping to a grid; places are kept in `~/.config/files/desktop.json` | Sway |
| New folder, move to trash | Done, from the menus | Sway |
| Paste | Missing: Files has no clipboard shared between windows | |
| Rename on the desktop, rubber band, several selected | Missing | |
| Drop files onto the desktop | Missing: Cacao's drag and drop is within a window | |

## File chooser

Files is the desktop portal's file chooser: xdg-desktop-portal hands it every app's Open and Save dialog (`org.freedesktop.impl.portal.FileChooser`), so a Cacao app, a Mac app on Perry (both through SDL's file dialogs) and a Flatpak GNOME app show the same one.

- Bus name `org.freedesktop.impl.portal.desktop.cacao.files`, registered by `Data/cacao-files.portal` (`UseIn=Cacao`). The desktop's `portals.conf` routes to it with `org.freedesktop.impl.portal.FileChooser=cacao-files`.
- D-Bus starts `files --file-chooser` for a request (`Data/org.freedesktop.impl.portal.desktop.cacao.files.service.in`). It opens a window per request and quits a minute after its last dialog closes. `files --desktop` serves the chooser too, when it gets the name first.
- `cmake -S Data -B build && cmake --install build` installs both files, and the program with `-DFILES_EXECUTABLE=…`.
- Each request has an `org.freedesktop.impl.portal.Request` object at its handle while it lasts; `Close` closes the dialog and ends the request with response 2.

| Portal option | Here |
| --- | --- |
| `OpenFile`, `SaveFile`, `SaveFiles` | Done |
| `multiple`, `directory` | Done: several files picked by clicking, or folders chosen instead of files |
| `filters`, `current_filter` | Done: globs (with `[…]`) and MIME types guessed from the name extension, as a popup; folders always show |
| `choices` | Done: popups, and checkboxes for choices without options |
| `current_name`, `current_folder`, `current_file` | Done |
| `accept_label` | Done, without its mnemonic's underscore |
| `files` (`SaveFiles`) | Done: each name in the folder chosen |
| Replacing an existing file | Asks first |
| `modal`, `parent_window` | Not yet: the dialog is a window of its own, not attached to the app's |
| Window title | The app's title shows in the dialog's header; the window is titled “Choose Files”, as Cacao has no per-window title |
| Recent files, previews | Missing |

## Preferences

| GNOME Files | Here | Tried |
| --- | --- | --- |
| Folders before files | Done, in the folder's menu | |
| Show hidden files | Done | |
| List or grid | Done | |
| Remembered between launches | Missing: every launch starts with the defaults | |
| Single or double click | Missing; a tap opens, as on a phone | |
| Captions, thumbnails, columns | Missing | |

## What it would take to close the gaps

1. **Operations off the main thread**, with progress, cancel and the conflict dialog. This is the largest gap in daily use.
2. **Cacao work**: drag and drop, a file clipboard, keyboard shortcuts for the menus, multiple windows, and pictures from files for thumbnails.
3. **Launch services** (phase A item 5 of the plan): open with, default programs, and what replaces `xdg-open`.
4. **Recent files** and remembered preferences: small, with no dependencies.
