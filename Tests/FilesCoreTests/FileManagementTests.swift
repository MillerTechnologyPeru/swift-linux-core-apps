import Foundation
import Testing
@testable import FilesCore

/// A folder of its own for a test, removed afterwards.
private func withScratchFolder(_ body: (URL) throws -> Void) throws {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("FileManagementTests-\(UUID().uuidString)", isDirectory: true)
        .resolvingSymlinksInPath()
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    try body(folder)
}

private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
}

private func text(_ url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
}

@discardableResult
private func write(_ contents: String, to url: URL) throws -> URL {
    try Data(contents.utf8).write(to: url)
    return url
}

private func item(_ name: String, kind: FileKind = .other, size: Int64? = nil, modified: Date? = nil) -> FileItem {
    FileItem(url: URL(fileURLWithPath: "/x/" + name), name: name, kind: kind, size: size, modified: modified)
}

@Suite struct ListingOrderTests {

    @Test func theOrderCanBeTurnedAroundWithFoldersStillFirst() {
        let items = [item("b"), item("a"), item("Folder", kind: .folder), item("c")]
        let names = DirectoryListing.sorted(items, by: .name, isReversed: true).map(\.name)
        #expect(names == ["Folder", "c", "b", "a"])
    }

    @Test func foldersCanBeMixedInWithFiles() {
        let items = [item("b"), item("Folder", kind: .folder), item("a")]
        let names = DirectoryListing.sorted(items, by: .name, foldersFirst: false).map(\.name)
        #expect(names == ["a", "b", "Folder"])
    }

    @Test func byTypeGroupsKindsThenExtensionsThenNames() {
        let items = [item("b.txt", kind: .text), item("a.png", kind: .image), item("a.md", kind: .text), item("c.jpg", kind: .image)]
        let names = DirectoryListing.sorted(items, by: .type).map(\.name)
        #expect(names == ["c.jpg", "a.png", "a.md", "b.txt"])
    }

    @Test func smallestFirstIsSizeReversed() {
        let items = [item("a", size: 5), item("b", size: 1), item("c", size: 9)]
        #expect(DirectoryListing.sorted(items, by: .size, isReversed: true).map(\.name) == ["b", "a", "c"])
    }
}

@Suite struct TransferTests {

    @Test func copyingKeepsBothWhenANameIsTaken() throws {
        try withScratchFolder { folder in
            let source = try FileOperations.createFolder(named: "Source", in: folder)
            let target = try FileOperations.createFolder(named: "Target", in: folder)
            let file = try write("new", to: source.appendingPathComponent("a.txt"))
            try write("old", to: target.appendingPathComponent("a.txt"))

            let done = try FileOperations.copy([file], to: target)

            #expect(done.map(\.destination.lastPathComponent) == ["a 2.txt"])
            #expect(try text(target.appendingPathComponent("a.txt")) == "old")
            #expect(try text(target.appendingPathComponent("a 2.txt")) == "new")
            #expect(exists(file))
        }
    }

    @Test func copyingCanReplaceOrSkip() throws {
        try withScratchFolder { folder in
            let source = try FileOperations.createFolder(named: "Source", in: folder)
            let target = try FileOperations.createFolder(named: "Target", in: folder)
            let file = try write("new", to: source.appendingPathComponent("a.txt"))
            let other = try write("old", to: target.appendingPathComponent("a.txt"))

            let skipped = try FileOperations.copy([file], to: target, policy: .skip)
            #expect(skipped.isEmpty)
            #expect(try text(other) == "old")

            let replaced = try FileOperations.copy([file], to: target, policy: .replace)
            #expect(replaced.count == 1)
            #expect(try text(other) == "new")
        }
    }

    @Test func aFolderIsCopiedWithWhatItHolds() throws {
        try withScratchFolder { folder in
            let source = try FileOperations.createFolder(named: "Source", in: folder)
            try write("x", to: source.appendingPathComponent("x.txt"))
            let target = try FileOperations.createFolder(named: "Target", in: folder)
            try FileOperations.copy([source], to: target)
            #expect(try text(target.appendingPathComponent("Source/x.txt")) == "x")
        }
    }

    @Test func aFolderCantGoInsideItself() throws {
        try withScratchFolder { folder in
            let outer = try FileOperations.createFolder(named: "Outer", in: folder)
            let inner = try FileOperations.createFolder(named: "Inner", in: outer)
            #expect(throws: FileOperations.Failure.intoItself("Outer")) {
                try FileOperations.copy([outer], to: inner)
            }
            #expect(throws: FileOperations.Failure.intoItself("Outer")) {
                try FileOperations.move([outer], to: outer)
            }
            #expect(exists(inner))
        }
    }

    @Test func movingTakesItemsOutOfTheirFolder() throws {
        try withScratchFolder { folder in
            let target = try FileOperations.createFolder(named: "Target", in: folder)
            let file = try write("a", to: folder.appendingPathComponent("a.txt"))
            let done = try FileOperations.move([file], to: target)
            #expect(done == [Transfer(source: file, destination: target.appendingPathComponent("a.txt"))])
            #expect(!exists(file))
            // Moving to where it is already does nothing.
            let again = try FileOperations.move([done[0].destination], to: target)
            #expect(again.isEmpty)
        }
    }

    @Test func duplicatesGoBesideTheOriginal() throws {
        try withScratchFolder { folder in
            let file = try write("a", to: folder.appendingPathComponent("a.txt"))
            let done = try FileOperations.duplicate([file])
            #expect(done.map(\.destination.lastPathComponent) == ["a 2.txt"])
            #expect(try text(done[0].destination) == "a")
        }
    }

    @Test func linksLeadToTheirItems() throws {
        try withScratchFolder { folder in
            let file = try write("a", to: folder.appendingPathComponent("a.txt"))
            let link = try FileOperations.link(to: file, in: folder)
            #expect(link.lastPathComponent == "Link to a.txt")
            #expect(try text(link) == "a")
            let properties = try FileProperties.load(link)
            #expect(properties.linkTarget == file.path)
        }
    }

    @Test func newFilesAreEmptyOrCopiesOfATemplate() throws {
        try withScratchFolder { folder in
            let empty = try FileOperations.createFile(in: folder)
            let second = try FileOperations.createFile(in: folder)
            #expect(empty.lastPathComponent == "New Document.txt")
            #expect(second.lastPathComponent == "New Document 2.txt")
            #expect(try text(empty) == "")

            let templates = try FileOperations.createFolder(named: "Templates", in: folder)
            let template = try write("Dear ", to: templates.appendingPathComponent("Letter.txt"))
            #expect(FileOperations.templates(in: templates) == [template])
            let letter = try FileOperations.createFile(named: "Letter.txt", in: folder, from: template)
            #expect(try text(letter) == "Dear ")
        }
    }

    @Test func deletingForGoodRemovesFoldersWithTheirContents() throws {
        try withScratchFolder { folder in
            let inner = try FileOperations.createFolder(named: "Inner", in: folder)
            try write("x", to: inner.appendingPathComponent("x.txt"))
            try FileOperations.deletePermanently([inner])
            #expect(!exists(inner))
        }
    }
}

@Suite struct UndoTests {

    @Test func aRenameIsUndoneAndRedone() throws {
        try withScratchFolder { folder in
            let file = try write("a", to: folder.appendingPathComponent("a.txt"))
            let renamed = try FileOperations.rename(file, to: "b.txt")
            var stack = UndoStack()
            stack.record(.moved([Transfer(source: file, destination: renamed)]))
            #expect(stack.undoName == "Rename")

            try stack.undo()
            #expect(exists(file) && !exists(renamed))
            #expect(stack.canRedo && !stack.canUndo)

            try stack.redo()
            #expect(!exists(file) && exists(renamed))
            #expect(stack.canUndo && !stack.canRedo)
        }
    }

    @Test func aMoveIsUndone() throws {
        try withScratchFolder { folder in
            let target = try FileOperations.createFolder(named: "Target", in: folder)
            let file = try write("a", to: folder.appendingPathComponent("a.txt"))
            var stack = UndoStack()
            stack.record(.moved(try FileOperations.move([file], to: target)))
            #expect(stack.undoName == "Move")
            try stack.undo()
            #expect(exists(file))
        }
    }

    @Test func undoingNeverReplacesWhatTookAnItemsPlace() throws {
        try withScratchFolder { folder in
            let file = try write("a", to: folder.appendingPathComponent("a.txt"))
            let renamed = try FileOperations.rename(file, to: "b.txt")
            var stack = UndoStack()
            stack.record(.moved([Transfer(source: file, destination: renamed)]))
            try write("other", to: file)
            #expect(throws: FileOperations.Failure.nameTaken("a.txt")) {
                try stack.undo()
            }
            let contents = try text(file)
            #expect(contents == "other")
            #expect(stack.canUndo)
        }
    }

    @Test func trashingIsUndoneByRestoring() throws {
        try withScratchFolder { folder in
            let trash = Trash(directory: folder.appendingPathComponent("Trash"))
            let file = try write("a", to: folder.appendingPathComponent("a.txt"))
            var stack = UndoStack()
            stack.record(.trashed([Transfer(source: file, destination: try trash.trash(file))], trash))
            #expect(!exists(file))

            try stack.undo()
            #expect(exists(file))
            #expect(trash.items().isEmpty)

            try stack.redo()
            #expect(!exists(file))
            #expect(trash.items().count == 1)
        }
    }

    @Test func aNewChangeForgetsWhatWasUndone() throws {
        var stack = UndoStack(limit: 2)
        let a = URL(fileURLWithPath: "/a"), b = URL(fileURLWithPath: "/b")
        stack.record(.created([]))
        #expect(!stack.canUndo)
        stack.record(.moved([Transfer(source: a, destination: b)]))
        stack.record(.moved([Transfer(source: a, destination: b)]))
        stack.record(.moved([Transfer(source: a, destination: b)]))
        #expect(stack.done.count == 2)
    }
}

@Suite struct SearchTests {

    @Test func patterns() {
        #expect(FilePattern("*.txt").matches("Notes.TXT"))
        #expect(FilePattern("Vacation-???.jpg").matches("vacation-001.jpg"))
        #expect(!FilePattern("Vacation-???.jpg").matches("vacation-01.jpg"))
        #expect(FilePattern("Invoice.*").matches("Invoice.pdf"))
        #expect(!FilePattern("Invoice.*").matches("Invoice"))
        #expect(FilePattern("*a*b*").matches("xxaxxbxx"))
        #expect(!FilePattern("a").matches("ab"))
        #expect(FilePattern("*").matches(""))
    }

    @Test func aSearchLooksInFoldersInsideTheFolder() throws {
        try withScratchFolder { folder in
            let inner = try FileOperations.createFolder(named: "Inner", in: folder)
            try write("", to: folder.appendingPathComponent("Report.txt"))
            try write("", to: inner.appendingPathComponent("old report.md"))
            try write("", to: inner.appendingPathComponent("photo.png"))
            try write("", to: inner.appendingPathComponent(".report-hidden"))

            let found = FileSearch.find(FileQuery(text: "report"), in: folder)
            #expect(found.map(\.name) == ["old report.md", "Report.txt"])

            let hidden = FileSearch.find(FileQuery(text: "report", showsHidden: true), in: folder)
            #expect(hidden.count == 3)

            let images = FileSearch.find(FileQuery(kind: .image), in: folder)
            #expect(images.map(\.name) == ["photo.png"])

            let pattern = FileSearch.find(FileQuery(text: "*.md"), in: folder)
            #expect(pattern.map(\.name) == ["old report.md"])

            #expect(FileSearch.find(FileQuery(), in: folder).isEmpty)
            #expect(FileSearch.find(FileQuery(text: "o"), in: folder, limit: 1).count == 1)
        }
    }

    @Test func aSearchCanLookInsideTextFilesAndByDate() throws {
        try withScratchFolder { folder in
            try write("the quick brown fox", to: folder.appendingPathComponent("a.txt"))
            try write("nothing here", to: folder.appendingPathComponent("b.txt"))

            #expect(FileSearch.find(FileQuery(text: "Brown"), in: folder).isEmpty)
            let found = FileSearch.find(FileQuery(text: "Brown", searchesContents: true), in: folder)
            #expect(found.map(\.name) == ["a.txt"])

            let future = FileSearch.find(FileQuery(modifiedSince: Date().addingTimeInterval(3600)), in: folder)
            #expect(future.isEmpty)
            let past = FileSearch.find(FileQuery(modifiedSince: Date().addingTimeInterval(-3600)), in: folder)
            #expect(past.count == 2)
        }
    }
}

@Suite struct PlacesTests {

    private let home = URL(fileURLWithPath: "/home/user", isDirectory: true)

    @Test func userFoldersComeFromTheirConfiguration() {
        let text = """
        # comment
        XDG_DOWNLOAD_DIR="$HOME/Descargas"
        XDG_MUSIC_DIR="/mnt/music"
        XDG_TEMPLATES_DIR="$HOME/"
        XDG_BOGUS_DIR="$HOME/x"
        XDG_VIDEOS_DIR=relative
        """
        let folders = UserFolders(home: home, configuration: text)
        #expect(folders.url(for: .downloads).path == "/home/user/Descargas")
        #expect(folders.url(for: .music).path == "/mnt/music")
        // Turned off, or not there: the usual name.
        #expect(folders.url(for: .templates).path == "/home/user/Templates")
        #expect(folders.url(for: .documents).path == "/home/user/Documents")
    }

    @Test func volumesAreTheMountedDisksButNotTheSystemsOwn() {
        let mounts = """
        /dev/nvme0n1p2 / ext4 rw,relatime 0 0
        proc /proc proc rw 0 0
        tmpfs /run tmpfs rw 0 0
        /dev/nvme0n1p1 /boot/efi vfat rw 0 0
        /dev/sda1 /media/user/USB\\040Stick vfat rw 0 0
        /dev/sdb1 /mnt/data ext4 rw 0 0
        /dev/sdb1 /mnt/data ext4 rw 0 0
        server:/export /mnt/nfs nfs4 rw 0 0
        //server/share /mnt/smb cifs rw 0 0
        /dev/loop3 /snap/core/1 squashfs ro 0 0
        """
        let volumes = Volume.parse(mounts: mounts)
        #expect(volumes.map(\.url.path) == ["/mnt/data", "/media/user/USB Stick"])
        #expect(volumes.map(\.name) == ["data", "USB Stick"])
        #expect(volumes.map(\.fileSystem) == ["ext4", "vfat"])
        #expect(volumes.map(\.isRemovable) == [true, true])
    }

    @Test func aPathBarHasEveryFolderFromTheRoot() {
        let urls = Location.ancestors(of: URL(fileURLWithPath: "/home/user/Music"))
        #expect(urls.map(\.path) == ["/", "/home", "/home/user", "/home/user/Music"])
        #expect(Location.ancestors(of: URL(fileURLWithPath: "/")).map(\.path) == ["/"])
    }

    @Test func freeSpaceIsKnownForTheTemporaryFolder() {
        let space = Volume.space(at: FileManager.default.temporaryDirectory)
        #expect((space?.total ?? 0) > 0)
        #expect((space?.free ?? -1) >= 0)
    }
}

@Suite struct BookmarkTests {

    @Test func theBookmarksFileIsReadAndWritten() {
        let text = "file:///home/user/My%20Music\nfile:///srv/data Data Disk\nsftp://server/home Server\n\n"
        let bookmarks = Bookmarks.parse(text)
        #expect(bookmarks.map(\.url.path) == ["/home/user/My Music", "/srv/data"])
        #expect(bookmarks.map(\.name) == ["My Music", "Data Disk"])
        #expect(Bookmarks.text(for: bookmarks) == "file:///home/user/My%20Music\nfile:///srv/data Data Disk\n")
    }

    @Test func bookmarksAreAddedRenamedAndRemovedKeepingServers() throws {
        try withScratchFolder { folder in
            let bookmarks = Bookmarks(file: folder.appendingPathComponent("gtk-3.0/bookmarks"))
            #expect(bookmarks.load().isEmpty)
            try FileManager.default.createDirectory(at: bookmarks.file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try write("sftp://server/home Server\n", to: bookmarks.file)

            let music = URL(fileURLWithPath: "/home/user/Music", isDirectory: true)
            try bookmarks.add(music)
            try bookmarks.add(music)
            #expect(bookmarks.load().count == 1)
            #expect(bookmarks.contains(music))

            try bookmarks.rename(music, to: "Songs")
            #expect(bookmarks.load().map(\.name) == ["Songs"])
            let renamed = try text(bookmarks.file)
            #expect(renamed == "file:///home/user/Music Songs\nsftp://server/home Server\n")

            try bookmarks.remove(music)
            #expect(bookmarks.load().isEmpty)
            let removed = try text(bookmarks.file)
            #expect(removed == "sftp://server/home Server\n")
        }
    }

    @Test func starsFollowItemsThatMove() throws {
        try withScratchFolder { folder in
            let starred = Starred(file: folder.appendingPathComponent("data/starred"))
            let file = try write("a", to: folder.appendingPathComponent("a.txt"))
            let gone = folder.appendingPathComponent("gone.txt")
            try starred.set(true, for: file)
            try starred.set(true, for: file)
            try starred.set(true, for: gone)
            #expect(starred.paths().count == 2)
            #expect(starred.contains(file))
            // Only what still exists is shown.
            #expect(starred.items().map(\.name) == ["a.txt"])

            let renamed = try FileOperations.rename(file, to: "b.txt")
            try starred.moved(from: file, to: renamed)
            #expect(starred.items().map(\.name) == ["b.txt"])

            try starred.set(false, for: renamed)
            #expect(!starred.contains(renamed))
        }
    }
}

@Suite struct PropertiesTests {

    @Test func permissionsAsLettersAndWords() {
        var permissions = Permissions(mode: 0o644)
        #expect(permissions.symbolic == "rw-r--r--")
        #expect(permissions.summary(for: .owner, isFolder: false) == "Read and write")
        #expect(permissions.summary(for: .others, isFolder: false) == "Read-only")
        #expect(!permissions.isExecutable)

        permissions.isExecutable = true
        #expect(permissions.symbolic == "rwxr-xr-x")
        permissions.isExecutable = false
        #expect(permissions.mode == 0o644)

        permissions.set(.write, for: .group, to: true)
        #expect(permissions.symbolic == "rw-rw-r--")

        let folder = Permissions(mode: 0o750)
        #expect(folder.summary(for: .owner, isFolder: true) == "Create and delete files")
        #expect(folder.summary(for: .group, isFolder: true) == "Access files")
        #expect(folder.summary(for: .others, isFolder: true) == "None")
        #expect(Permissions(mode: 0o400).summary(for: .owner, isFolder: true) == "List files only")
    }

    @Test func propertiesOfAFileAndAFolder() throws {
        try withScratchFolder { folder in
            let file = try write("hello", to: folder.appendingPathComponent("a.txt"))
            let inner = try FileOperations.createFolder(named: "Inner", in: folder)
            try write("12345678", to: inner.appendingPathComponent("b.txt"))

            let properties = try FileProperties.load(file)
            #expect(properties.size == 5)
            #expect(properties.kind == .text)
            #expect(properties.itemCount == nil)
            #expect(properties.modified != nil)
            #expect(properties.parent == folder.path)
            #expect(properties.linkTarget == nil)

            let folderProperties = try FileProperties.load(folder)
            #expect(folderProperties.isFolder)
            #expect(folderProperties.itemCount == 2)
            #expect(folderProperties.size == nil)
            #expect((folderProperties.freeSpace ?? -1) >= 0)

            let contents = FileProperties.contents(of: folder)
            #expect(contents.bytes == 13)
            #expect(contents.items == 3)
            #expect(contents.isComplete)
            #expect(!FileProperties.contents(of: folder, limit: 1).isComplete)
        }
    }

    @Test func permissionsAreSetOnAFolderAndWhatItHolds() throws {
        try withScratchFolder { folder in
            let inner = try FileOperations.createFolder(named: "Inner", in: folder)
            let file = try write("x", to: inner.appendingPathComponent("x.txt"))
            try FileProperties.setPermissions(Permissions(mode: 0o600), of: file)

            try FileProperties.setPermissions(Permissions(mode: 0o750), of: inner, recursively: true)

            let folderMode = try FileProperties.load(inner).permissions
            let fileMode = try FileProperties.load(file).permissions
            #expect(folderMode?.symbolic == "rwxr-x---")
            // A file inside doesn't become a program.
            #expect(fileMode?.symbolic == "rw-r-----")
        }
    }
}

@Suite struct BatchRenameTests {

    @Test func aTemplateNumbersItemsAndKeepsExtensions() {
        let names = BatchRename.template("Trip [01] [Original]").names(for: ["a.jpg", "b.png", ".hidden"])
        #expect(names == ["Trip 01 a.jpg", "Trip 02 b.png", "Trip 03 .hidden"])
        #expect(BatchRename.template("[001]").names(for: ["x.txt"]) == ["001.txt"])
    }

    @Test func textIsReplacedInNames() {
        #expect(BatchRename.replace("IMG_", with: "Photo ").names(for: ["IMG_1.jpg", "notes.txt"]) == ["Photo 1.jpg", "notes.txt"])
        #expect(BatchRename.replace("", with: "x").names(for: ["a"]) == ["a"])
    }

    @Test func aRenamingThatWouldCollideIsRefused() {
        #expect(BatchRename.template("Same").problem(for: ["a.txt", "b.txt"]) != nil)
        #expect(BatchRename.template("[1]").problem(for: ["a.txt", "b.txt"]) == nil)
        #expect(BatchRename.template("[1]").problem(for: ["a.txt"], among: ["1.txt"]) != nil)
        #expect(BatchRename.replace("a", with: "/").problem(for: ["a.txt"]) != nil)
    }

    @Test func itemsCanTradeNames() throws {
        try withScratchFolder { folder in
            let first = try write("one", to: folder.appendingPathComponent("1.txt"))
            let second = try write("two", to: folder.appendingPathComponent("2.txt"))
            // Listed second first, each takes the other's name.
            let transfers = try BatchRename.template("[1]").apply(to: [second, first])
            #expect(transfers.count == 2)
            #expect(try text(first) == "two")
            #expect(try text(second) == "one")
        }
    }
}

#if os(macOS) || os(Linux)
@Suite struct ArchiveTests {

    @Test func archiveNames() {
        #expect(Archive.stem(of: "photos.tar.gz") == "photos")
        #expect(Archive.stem(of: "Photos.ZIP") == "Photos")
        #expect(Archive.stem(of: "notes.txt") == "notes.txt")
    }

    @Test func itemsArePackedAndUnpacked() throws {
        try #require(Archive.canCompress)
        try withScratchFolder { folder in
            let inner = try FileOperations.createFolder(named: "Inner", in: folder)
            try write("x", to: inner.appendingPathComponent("x.txt"))
            let file = try write("a", to: folder.appendingPathComponent("a.txt"))

            let archive = try Archive.compress([inner, file])
            #expect(archive.lastPathComponent == "Archive.tar.gz")
            #expect(Archive.canExtract(archive))
            let second = try Archive.compress([inner, file])
            #expect(second.lastPathComponent == "Archive 2.tar.gz")

            let unpacked = try Archive.extract(archive)
            #expect(unpacked.lastPathComponent == "Archive")
            #expect(try text(unpacked.appendingPathComponent("Inner/x.txt")) == "x")
            #expect(try text(unpacked.appendingPathComponent("a.txt")) == "a")

            let single = try Archive.compress([file])
            #expect(single.lastPathComponent == "a.txt.tar.gz")
        }
    }

    @Test func aBrokenArchiveLeavesNoFolder() throws {
        try #require(Archive.canCompress)
        try withScratchFolder { folder in
            let bad = try write("not an archive", to: folder.appendingPathComponent("bad.tar.gz"))
            #expect(throws: (any Error).self) {
                try Archive.extract(bad)
            }
            #expect(!exists(folder.appendingPathComponent("bad")))
        }
    }
}
#endif
