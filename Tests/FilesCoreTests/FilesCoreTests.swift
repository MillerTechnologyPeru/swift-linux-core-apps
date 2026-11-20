import Foundation
import Testing
@testable import FilesCore

@Suite struct ByteCountTests {

    @Test func bytes() {
        #expect(ByteCount.format(0) == "0 bytes")
        #expect(ByteCount.format(1) == "1 byte")
        #expect(ByteCount.format(999) == "999 bytes")
        #expect(ByteCount.format(-5) == "0 bytes")
    }

    @Test func decimalUnits() {
        #expect(ByteCount.format(1000) == "1 kB")
        #expect(ByteCount.format(1500) == "1.5 kB")
        #expect(ByteCount.format(9_940) == "9.9 kB")
        #expect(ByteCount.format(15_400) == "15 kB")
        #expect(ByteCount.format(999_400) == "999 kB")
        #expect(ByteCount.format(1_000_000) == "1 MB")
        #expect(ByteCount.format(2_500_000_000) == "2.5 GB")
        #expect(ByteCount.format(4_000_000_000_000) == "4 TB")
    }

    @Test func aValueThatRoundsUpToAThousandMovesToTheNextUnit() {
        #expect(ByteCount.format(999_960) == "1 MB")
    }
}

@Suite struct FileKindTests {

    @Test func kindsComeFromTheNameExtensionWhateverItsCase() {
        #expect(FileKind(pathExtension: "PNG") == .image)
        #expect(FileKind(pathExtension: "flac") == .audio)
        #expect(FileKind(pathExtension: "mkv") == .video)
        #expect(FileKind(pathExtension: "md") == .text)
        #expect(FileKind(pathExtension: "zip") == .archive)
        #expect(FileKind(pathExtension: "pdf") == .document)
        #expect(FileKind(pathExtension: "") == .other)
        #expect(FileKind(pathExtension: "xyz") == .other)
    }
}

@Suite struct DirectoryListingTests {

    /// A folder of its own, removed when the test ends.
    private func withFolder(_ body: (URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("FilesCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try body(folder)
    }

    private func write(_ name: String, bytes: Int, in folder: URL, modified: Date? = nil) throws {
        let url = folder.appendingPathComponent(name)
        try Data(repeating: 0, count: bytes).write(to: url)
        if let modified {
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        }
    }

    @Test func foldersComeFirstThenNamesAsPeopleOrderThem() throws {
        try withFolder { folder in
            try write("File 10.txt", bytes: 1, in: folder)
            try write("File 2.txt", bytes: 1, in: folder)
            try write("apple.png", bytes: 1, in: folder)
            try FileManager.default.createDirectory(at: folder.appendingPathComponent("Zebra"), withIntermediateDirectories: false)
            let items = try DirectoryListing.load(folder)
            #expect(items.map(\.name) == ["Zebra", "apple.png", "File 2.txt", "File 10.txt"])
            #expect(items[0].isFolder)
            #expect(items[0].size == nil)
            #expect(items[1].kind == .image)
        }
    }

    @Test func hiddenFilesShowOnlyWhenAsked() throws {
        try withFolder { folder in
            try write(".secret", bytes: 1, in: folder)
            try write("shown.txt", bytes: 1, in: folder)
            #expect(try DirectoryListing.load(folder).map(\.name) == ["shown.txt"])
            let all = try DirectoryListing.load(folder, showsHidden: true)
            #expect(all.map(\.name) == [".secret", "shown.txt"])
            #expect(all[0].isHidden)
        }
    }

    @Test func sizesAndDatesAreRead() throws {
        try withFolder { folder in
            let date = Date(timeIntervalSince1970: 1_700_000_000)
            try write("data.bin", bytes: 2048, in: folder, modified: date)
            let item = try #require(try DirectoryListing.load(folder).first)
            #expect(item.size == 2048)
            #expect(item.modified == date)
        }
    }

    @Test func sortingBySizeAndDateKeepsFoldersFirst() throws {
        try withFolder { folder in
            try write("small.txt", bytes: 10, in: folder, modified: Date(timeIntervalSince1970: 3000))
            try write("large.txt", bytes: 5000, in: folder, modified: Date(timeIntervalSince1970: 1000))
            try write("medium.txt", bytes: 300, in: folder, modified: Date(timeIntervalSince1970: 2000))
            try FileManager.default.createDirectory(at: folder.appendingPathComponent("Folder"), withIntermediateDirectories: false)
            #expect(try DirectoryListing.load(folder, sort: .size).map(\.name) == ["Folder", "large.txt", "medium.txt", "small.txt"])
            #expect(try DirectoryListing.load(folder, sort: .modified).map(\.name) == ["Folder", "small.txt", "medium.txt", "large.txt"])
        }
    }

    @Test func aMissingFolderThrows() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("FilesCoreTests-missing-\(UUID().uuidString)")
        #expect(throws: (any Error).self) {
            try DirectoryListing.load(missing)
        }
    }
}

@Suite struct LocationTests {

    @Test func onlyTheFoldersThatExistAreListed() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("FilesCoreTests-home-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home.appendingPathComponent("Documents"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home.appendingPathComponent("Music"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let locations = Location.standard(home: home)
        #expect(locations.map(\.name) == ["Home", "Documents", "Music", "Computer"])
        #expect(locations.last?.url.path == "/")
    }

    @Test func aLocationsFolderTakesItsName() {
        let home = URL(fileURLWithPath: "/home/user", isDirectory: true)
        let locations = [Location(name: "Home", symbolName: "house", url: home)]
        #expect(Location.title(for: URL(fileURLWithPath: "/home/user"), among: locations) == "Home")
        #expect(Location.title(for: URL(fileURLWithPath: "/home/user/Projects"), among: locations) == "Projects")
    }
}

/// A folder of its own for a test, removed afterwards.
private func withScratchFolder(_ body: (URL) throws -> Void) throws {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("FilesCoreTests-\(UUID().uuidString)", isDirectory: true)
        .resolvingSymlinksInPath()
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    try body(folder)
}

private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
}

@Suite struct FileNameTests {

    @Test func namesAreCleanedOfSpaceAroundThem() {
        #expect(FileName.cleaned("  Notes \n") == "Notes")
    }

    @Test func problems() {
        #expect(FileName.problem(with: "Notes.txt") == nil)
        #expect(FileName.problem(with: ".hidden") == nil)
        #expect(FileName.problem(with: "") == .empty)
        #expect(FileName.problem(with: "a/b") == .containsSlash)
        #expect(FileName.problem(with: ".") == .reserved)
        #expect(FileName.problem(with: "..") == .reserved)
        #expect(FileName.problem(with: String(repeating: "a", count: 255)) == nil)
        #expect(FileName.problem(with: String(repeating: "a", count: 256)) == .tooLong)
        // 128 two-byte characters are 256 bytes.
        #expect(FileName.problem(with: String(repeating: "é", count: 128)) == .tooLong)
    }

    @Test func aFreeNameIsKept() {
        #expect(FileName.unique("Notes.txt", among: ["Other.txt"]) == "Notes.txt")
    }

    @Test func aTakenNameGetsTheFirstFreeNumberBeforeItsExtension() {
        #expect(FileName.unique("Notes.txt", among: ["Notes.txt"]) == "Notes 2.txt")
        #expect(FileName.unique("Notes.txt", among: ["Notes.txt", "Notes 2.txt"]) == "Notes 3.txt")
        #expect(FileName.unique("New Folder", among: ["New Folder"]) == "New Folder 2")
        #expect(FileName.unique("archive.tar.gz", among: ["archive.tar.gz"]) == "archive.tar 2.gz")
    }

    @Test func aHiddenFilesDotIsNotAnExtension() {
        #expect(FileName.unique(".config", among: [".config"]) == ".config 2")
    }
}

@Suite struct FileOperationsTests {

    @Test func newFoldersAreNumberedWhenTheNameIsTaken() throws {
        try withScratchFolder { folder in
            let first = try FileOperations.createFolder(in: folder)
            let second = try FileOperations.createFolder(in: folder)
            #expect(first.lastPathComponent == "New Folder")
            #expect(second.lastPathComponent == "New Folder 2")
            #expect(try DirectoryListing.load(folder).map(\.name) == ["New Folder", "New Folder 2"])
            #expect(try DirectoryListing.load(folder).allSatisfy(\.isFolder))
        }
    }

    @Test func aFolderCantBeMadeWithABadName() throws {
        try withScratchFolder { folder in
            #expect(throws: FileName.Problem.containsSlash) {
                try FileOperations.createFolder(named: "a/b", in: folder)
            }
            #expect(throws: FileName.Problem.empty) {
                try FileOperations.createFolder(named: "   ", in: folder)
            }
            let items = try DirectoryListing.load(folder)
            #expect(items.isEmpty)
        }
    }

    @Test func renamingMovesAnItemWithinItsFolder() throws {
        try withScratchFolder { folder in
            let file = folder.appendingPathComponent("a.txt")
            try Data("hello".utf8).write(to: file)
            let renamed = try FileOperations.rename(file, to: " b.txt ")
            #expect(renamed.lastPathComponent == "b.txt")
            #expect(!exists(file))
            #expect(try String(contentsOf: renamed, encoding: .utf8) == "hello")
        }
    }

    @Test func renamingToTheSameNameDoesNothing() throws {
        try withScratchFolder { folder in
            let file = folder.appendingPathComponent("a.txt")
            try Data().write(to: file)
            #expect(try FileOperations.rename(file, to: "a.txt") == file)
            #expect(exists(file))
        }
    }

    @Test func renamingNeverReplacesAnotherItem() throws {
        try withScratchFolder { folder in
            let first = folder.appendingPathComponent("a.txt"), second = folder.appendingPathComponent("b.txt")
            try Data("a".utf8).write(to: first)
            try Data("b".utf8).write(to: second)
            #expect(throws: FileOperations.Failure.nameTaken("b.txt")) {
                try FileOperations.rename(first, to: "b.txt")
            }
            #expect(throws: FileName.Problem.reserved) {
                try FileOperations.rename(first, to: "..")
            }
            #expect(try String(contentsOf: first, encoding: .utf8) == "a")
            #expect(try String(contentsOf: second, encoding: .utf8) == "b")
        }
    }
}

@Suite struct TrashTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func theHomeTrashFollowsXDGDataHome() {
        let home = URL(fileURLWithPath: "/home/user", isDirectory: true)
        #expect(Trash.home(environment: [:], homeDirectory: home).directory.path == "/home/user/.local/share/Trash")
        #expect(Trash.home(environment: ["XDG_DATA_HOME": "/data"], homeDirectory: home).directory.path == "/data/Trash")
        // The variable must hold an absolute path to count.
        #expect(Trash.home(environment: ["XDG_DATA_HOME": "data"], homeDirectory: home).directory.path == "/home/user/.local/share/Trash")
    }

    @Test func aRecordHasThePathEncodedAndTheLocalTime() {
        // 2026-11-20 09:05:07 UTC.
        let date = Date(timeIntervalSince1970: 1_795_165_507)
        let record = Trash.record(path: "/home/user/My Notes/café.txt", date: date, calendar: calendar)
        #expect(record == "[Trash Info]\nPath=/home/user/My%20Notes/caf%C3%A9.txt\nDeletionDate=2026-11-20T09:05:07\n")
    }

    @Test func recordsAreParsed() {
        let parsed = Trash.parse(record: "# comment\n[Trash Info]\nDeletionDate=2026-01-02T03:04:05\nPath=/a/b%20c.txt\n")
        #expect(parsed?.path == "/a/b c.txt")
        #expect(parsed?.deletionDate == "2026-01-02T03:04:05")
        #expect(Trash.parse(record: "Path=/a\n") == nil)
        #expect(Trash.parse(record: "[Trash Info]\nPath=relative\n") == nil)
        #expect(Trash.parse(record: "[Trash Info]\n[Other]\nPath=/a\n") == nil)
    }

    @Test func trashingMovesAnItemAndRecordsWhereItWas() throws {
        try withScratchFolder { folder in
            let trash = Trash(directory: folder.appendingPathComponent("Trash"))
            let file = folder.appendingPathComponent("a file.txt")
            try Data("hello".utf8).write(to: file)

            let trashed = try trash.trash(file, at: Date(timeIntervalSince1970: 1_795_165_507), calendar: calendar)

            #expect(!exists(file))
            #expect(trashed == trash.files.appendingPathComponent("a file.txt"))
            #expect(try String(contentsOf: trashed, encoding: .utf8) == "hello")
            let record = try String(contentsOf: trash.info.appendingPathComponent("a file.txt.trashinfo"), encoding: .utf8)
            #expect(record.contains("Path=\(folder.path)/a%20file.txt\n"))
            #expect(record.contains("DeletionDate=2026-11-20T09:05:07\n"))
            #expect(trash.items() == [Trash.Item(url: trashed, originalURL: file, deletionDate: "2026-11-20T09:05:07")])
        }
    }

    @Test func itemsOfTheSameNameAreKeptApart() throws {
        try withScratchFolder { folder in
            let trash = Trash(directory: folder.appendingPathComponent("Trash"))
            let file = folder.appendingPathComponent("a.txt")
            try Data("one".utf8).write(to: file)
            let first = try trash.trash(file)
            try Data("two".utf8).write(to: file)
            let second = try trash.trash(file)

            #expect(first.lastPathComponent == "a.txt")
            #expect(second.lastPathComponent == "a 2.txt")
            #expect(try String(contentsOf: first, encoding: .utf8) == "one")
            #expect(try String(contentsOf: second, encoding: .utf8) == "two")
            #expect(trash.items().map(\.originalURL) == [file, file])
        }
    }

    @Test func aFolderIsTrashedWithWhatItHolds() throws {
        try withScratchFolder { folder in
            let trash = Trash(directory: folder.appendingPathComponent("Trash"))
            let inner = try FileOperations.createFolder(named: "Inner", in: folder)
            try Data("x".utf8).write(to: inner.appendingPathComponent("x.txt"))
            let trashed = try trash.trash(inner)
            #expect(!exists(inner))
            #expect(exists(trashed.appendingPathComponent("x.txt")))
        }
    }

    @Test func trashingSomethingThatIsNotThereLeavesNoRecord() throws {
        try withScratchFolder { folder in
            let trash = Trash(directory: folder.appendingPathComponent("Trash"))
            #expect(throws: (any Error).self) {
                try trash.trash(folder.appendingPathComponent("missing.txt"))
            }
            let records = try FileManager.default.contentsOfDirectory(atPath: trash.info.path)
            #expect(trash.items().isEmpty)
            #expect(records.isEmpty)
        }
    }

    @Test func restoringPutsAnItemBackAndRemovesItsRecord() throws {
        try withScratchFolder { folder in
            let trash = Trash(directory: folder.appendingPathComponent("Trash"))
            let parent = try FileOperations.createFolder(named: "Parent", in: folder)
            let file = parent.appendingPathComponent("a.txt")
            try Data("hello".utf8).write(to: file)
            try trash.trash(file)
            // The folder it was in is gone by the time it's put back.
            try FileManager.default.removeItem(at: parent)

            let item = try #require(trash.items().first)
            #expect(try trash.restore(item) == file)
            #expect(try String(contentsOf: file, encoding: .utf8) == "hello")
            #expect(trash.items().isEmpty)
        }
    }

    @Test func restoringNeverReplacesAnotherItem() throws {
        try withScratchFolder { folder in
            let trash = Trash(directory: folder.appendingPathComponent("Trash"))
            let file = folder.appendingPathComponent("a.txt")
            try Data("old".utf8).write(to: file)
            try trash.trash(file)
            try Data("new".utf8).write(to: file)

            let item = try #require(trash.items().first)
            #expect(throws: FileOperations.Failure.nameTaken("a.txt")) {
                try trash.restore(item)
            }
            #expect(try String(contentsOf: file, encoding: .utf8) == "new")
            #expect(trash.items().count == 1)
        }
    }

    @Test func emptyingDeletesItemsAndRecords() throws {
        try withScratchFolder { folder in
            let trash = Trash(directory: folder.appendingPathComponent("Trash"))
            let file = folder.appendingPathComponent("a.txt")
            try Data().write(to: file)
            try trash.trash(file)
            try trash.empty()
            #expect(trash.items().isEmpty)
            #expect(try FileManager.default.contentsOfDirectory(atPath: trash.files.path) == [])
            #expect(try FileManager.default.contentsOfDirectory(atPath: trash.info.path) == [])
        }
    }
}
