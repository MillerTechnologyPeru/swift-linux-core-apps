//
//  SoftwareCoreTests.swift
//  CoreApps
//

import Foundation
import Testing
@testable import SoftwareCore

/// A catalog in AppStream's shape, as Flathub's is.
let catalog = """
<?xml version="1.0" encoding="UTF-8"?>
<components version="0.8" origin="flathub">
  <component type="desktop-application">
    <id>org.example.Calculator</id>
    <name>Calculator</name>
    <name xml:lang="de">Taschenrechner</name>
    <summary>Perform arithmetic, scientific or financial calculations</summary>
    <summary xml:lang="de">Rechnen</summary>
    <project_license>GPL-3.0-or-later</project_license>
    <developer id="org.example">
      <name>The Example Project</name>
    </developer>
    <developer_name>Old Name</developer_name>
    <description>
      <p>
      Calculator solves equations,
      with <em>several</em> modes.
    </p>
      <ul>
        <li>Advanced</li>
        <li>Financial &amp; more</li>
      </ul>
    </description>
    <description xml:lang="de">
      <p>Ein Rechner.</p>
    </description>
    <icon type="stock">org.example.Calculator</icon>
    <icon height="128" type="cached" width="128">big.png</icon>
    <icon height="64" type="cached" width="64">org.example.Calculator.png</icon>
    <icon height="128" type="remote" width="128">https://example.org/icon.png</icon>
    <url type="bugtracker">https://example.org/bugs</url>
    <url type="homepage">https://example.org/calculator</url>
    <categories>
      <category>Utility</category>
      <category>Calculator</category>
    </categories>
    <keywords>
      <keyword>maths</keyword>
      <keyword xml:lang="de">Mathe</keyword>
    </keywords>
    <screenshots>
      <screenshot type="default">
        <caption>Basic</caption>
        <image type="source">https://example.org/shot.png</image>
      </screenshot>
    </screenshots>
    <releases>
      <release timestamp="1787961600" type="development" version="51~rc"/>
      <release timestamp="1791590400" type="stable" version="51.1">
        <description>
          <ul>
            <li>Updated translations</li>
          </ul>
        </description>
      </release>
    </releases>
    <bundle type="flatpak" runtime="org.gnome.Platform/x86_64/49">app/org.example.Calculator/x86_64/stable</bundle>
  </component>
  <component type="runtime">
    <id>org.example.Platform</id>
    <name>Platform</name>
  </component>
  <component type="console-application">
    <id>org.example.Tool</id>
    <name>Tool</name>
    <summary>A café for the terminal</summary>
    <project_license>LicenseRef-proprietary</project_license>
    <categories>
      <category>Development</category>
    </categories>
  </component>
  <component type="desktop-application">
    <id>org.example.Player</id>
    <name>Player</name>
    <summary>Plays music</summary>
    <categories>
      <category>Audio</category>
      <category>Player</category>
    </categories>
    <releases>
      <release timestamp="1700000000" version="2.0"/>
    </releases>
  </component>
  <component type="desktop-application">
    <id>org.example.Nameless</id>
  </component>
</components>
"""

@Suite struct AppStreamTests {

    @Test func appsAreReadAndTheRestSkipped() {
        let apps = AppStream.parse(catalog)
        #expect(apps.map { $0.id } == ["org.example.Calculator", "org.example.Tool", "org.example.Player"])
        #expect(apps[1].isGraphical == false)
        #expect(apps[0].isGraphical)
    }

    @Test func textIsTheAppsOwnLanguage() throws {
        let app = try #require(AppStream.parse(catalog).first)
        #expect(app.name == "Calculator")
        #expect(app.summary == "Perform arithmetic, scientific or financial calculations")
        #expect(app.developer == "The Example Project")
        #expect(app.license == "GPL-3.0-or-later")
        #expect(app.keywords == ["maths"])
        #expect(app.categories == ["Utility", "Calculator"])
        #expect(app.homepage == "https://example.org/calculator")
        #expect(app.description == [
            .paragraph("Calculator solves equations, with several modes."),
            .list(["Advanced", "Financial & more"]),
        ])
    }

    @Test func theIconNearest64PixelsIsKept() throws {
        let app = try #require(AppStream.parse(catalog).first)
        #expect(app.icon == "org.example.Calculator.png")
    }

    @Test func releasesAndTheBundle() throws {
        let app = try #require(AppStream.parse(catalog).first)
        #expect(app.releases.map { $0.version } == ["51~rc", "51.1"])
        #expect(app.latestRelease?.version == "51.1")
        #expect(app.latestRelease?.notes == [.list(["Updated translations"])])
        #expect(app.bundle == "app/org.example.Calculator/x86_64/stable")
        #expect(app.branch == "stable")
    }

    @Test func theDeveloperNameIsUsedWithoutADeveloper() {
        let apps = AppStream.parse("""
        <components><component type="desktop-application"><id>a.b</id><name>A</name>\
        <developer_name>Someone</developer_name></component></components>
        """)
        #expect(apps.first?.developer == "Someone")
    }

    @Test func brokenXMLKeepsWhatWasRead() {
        let apps = AppStream.parse("<components><component type=\"desktop-application\"><id>a.b</id><name>A</name></component><component")
        #expect(apps.map { $0.id } == ["a.b"])
    }
}

@Suite struct CategoryTests {

    @Test func theFirstMainCategory() {
        #expect(AppCategory.primary(for: ["Calculator", "Utility"]) == .utility)
        #expect(AppCategory.primary(for: ["Audio", "Player"]) == .audioVideo)
        #expect(AppCategory.primary(for: ["Calculator"]) == nil)
    }

    @Test func appsByCategoryAreGraphicalAndByName() {
        let apps = AppStream.parse(catalog) + [CatalogApp(id: "a.Zed", name: "Abacus", categories: ["Utility"])]
        #expect(CatalogSearch.apps(in: .utility, from: apps).map { $0.name } == ["Abacus", "Calculator"])
        #expect(CatalogSearch.apps(in: .audioVideo, from: apps).map { $0.name } == ["Player"])
        #expect(CatalogSearch.apps(in: .development, from: apps).isEmpty)
    }

    @Test func licenses() {
        #expect(License.isFree("GPL-3.0-or-later"))
        #expect(License.isFree("MIT AND Apache-2.0"))
        #expect(!License.isFree("LicenseRef-proprietary"))
        #expect(!License.isFree(" "))
    }
}

@Suite struct SearchTests {

    let apps = AppStream.parse(catalog)

    @Test func namesComeFirst() {
        let found = CatalogSearch.search("calc", in: apps)
        #expect(found.map { $0.id } == ["org.example.Calculator"])
    }

    @Test func anAppNamedJustThatComesFirst() {
        let apps = [
            CatalogApp(id: "a.Curo", name: "Curo Calculator"),
            CatalogApp(id: "a.Calc", name: "Calculator"),
        ]
        #expect(CatalogSearch.search("calculator", in: apps).map { $0.id } == ["a.Calc", "a.Curo"])
    }

    @Test func everyWordMustMatch() {
        #expect(CatalogSearch.search("financial calc", in: apps).count == 1)
        #expect(CatalogSearch.search("financial music", in: apps).isEmpty)
    }

    @Test func keywordsSummariesAndAccents() {
        #expect(CatalogSearch.search("MATHS", in: apps).map { $0.name } == ["Calculator"])
        #expect(CatalogSearch.search("cafe", in: apps).map { $0.name } == ["Tool"])
        #expect(CatalogSearch.search("plays", in: apps).map { $0.name } == ["Player"])
        #expect(CatalogSearch.search("  ", in: apps).isEmpty)
    }

    @Test func recentlyUpdatedIsNewestFirstAndGraphical() {
        #expect(CatalogSearch.recentlyUpdated(apps).map { $0.name } == ["Calculator", "Player"])
    }
}

@Suite struct FlatpakTableTests {

    @Test func installedApps() {
        let output = """
        com.makemkv.MakeMKV\tMakeMKV\t2.0.0\tstable\tflathub\tuser\t202.9 MB
        org.chromium.Chromium\tChromium Web Browser\t158.0\tstable\tflathub\tsystem\t483.0 MB

        Looking for matches…
        """
        let apps = FlatpakTable.installed(output)
        #expect(apps.map { $0.appID } == ["com.makemkv.MakeMKV", "org.chromium.Chromium"])
        #expect(apps[0].installation == .user)
        #expect(apps[1].installation == .system)
        #expect(apps[1].name == "Chromium Web Browser")
        #expect(apps[1].size == "483.0 MB")
        #expect(apps[0].id != InstalledApp(appID: "com.makemkv.MakeMKV", name: "", source: .flatpak, installation: .system).id)
    }

    @Test func updates() {
        let updates = FlatpakTable.updates("org.gimp.GIMP\t3.2.8\tstable\tflathub\n", installation: .system)
        #expect(updates == [AvailableUpdate(appID: "org.gimp.GIMP", installation: .system, version: "3.2.8", branch: "stable", origin: "flathub")])
        #expect(FlatpakTable.updateArguments(.user) == ["remote-ls", "--user", "--updates", "--app", "--columns=application,version,branch,origin"])
    }

    @Test func failures() {
        #expect(FlatpakTable.failure("Looking for matches…\nerror: No remote refs found for ‘nope’\n") == "No remote refs found for ‘nope’")
        #expect(FlatpakTable.failure("something\nwent wrong\n\n") == "went wrong")
        #expect(FlatpakTable.failure("") == "")
    }
}

@Suite struct AppBundleTests {

    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleDisplayName</key>
        <string>Browser</string>
        <key>CFBundleIdentifier</key>
        <string>org.pureswift.browser</string>
        <key>CFBundleName</key>
        <string>Browser Name</string>
        <key>CFBundleShortVersionString</key>
        <string>0.1</string>
        <key>RTABIVersion</key>
        <integer>1</integer>
    </dict>
    </plist>
    """

    @Test func installedBundles() throws {
        let app = try #require(AppBundle.app(infoPlist: Data(plist.utf8), path: "/home/me/.local/lib/linux-app/org.pureswift.browser.app", installation: .user))
        #expect(app.appID == "org.pureswift.browser")
        #expect(app.name == "Browser")
        #expect(app.version == "0.1")
        #expect(app.source == .appRuntime)
        #expect(AppBundle.app(infoPlist: Data("not a plist".utf8), path: "/x", installation: .user) == nil)
    }

    @Test func whereBundlesAre() {
        #expect(AppBundle.prefixes(environment: [:], home: "/home/me") == ["/home/me/.local", "/usr/local", "/usr"])
        #expect(AppBundle.prefixes(environment: ["LINUXAPPRUNTIME_PREFIXES": "/a:/b"], home: "/home/me") == ["/a", "/b"])
        #expect(AppBundle.installation(of: "/home/me/.local", home: "/home/me") == .user)
        #expect(AppBundle.installation(of: "/usr", home: "/home/me") == .system)
    }

    @Test func removingABundleTakesItsEntryAndIcon() {
        #expect(AppBundle.files(ofBundleAt: "/home/me/.local/lib/linux-app/a.b.app", identifier: "a.b") == [
            "/home/me/.local/lib/linux-app/a.b.app",
            "/home/me/.local/share/applications/a.b.desktop",
            "/home/me/.local/share/icons/hicolor/256x256/apps/a.b.png",
        ])
    }
}
