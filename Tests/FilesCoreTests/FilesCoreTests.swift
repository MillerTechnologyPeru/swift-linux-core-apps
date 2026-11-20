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
