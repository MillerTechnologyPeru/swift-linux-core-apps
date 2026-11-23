//
//  AppStream.swift
//  CoreApps
//

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Reads an AppStream catalog, as Flatpak keeps each remote's
/// (`appstream/<remote>/<arch>/active/appstream.xml`): the apps in it,
/// in English.
///
/// Only apps are kept, with or without a window; runtimes, add-ons, fonts
/// and the like aren't shown in the store. Of text given in several
/// languages, the one without `xml:lang` is kept, which is the app's own.
public enum AppStream {

    public static func parse(_ data: Data) -> [CatalogApp] {
        let reader = Reader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        parser.parse()
        return reader.apps
    }

    public static func parse(_ text: String) -> [CatalogApp] {
        parse(Data(text.utf8))
    }
}

/// `XMLParser`'s delegate: follows where it is in a component, and fills
/// in an app as it goes.
private final class Reader: NSObject, XMLParserDelegate {

    var apps: [CatalogApp] = []

    /// The open elements, innermost last.
    private var path: [String] = []

    /// The app being read, when its component is one.
    private var app: CatalogApp?

    /// Inside an element in another language, or one being skipped, at
    /// this depth.
    private var skippingDepth: Int?

    private var text = ""

    // What's being built inside a description.
    private var blocks: [DescriptionBlock] = []
    private var items: [String] = []

    private var iconWidth = 0
    private var bestIconWidth = 0
    private var iconIsCached = false
    private var urlType: String?
    private var release: Release?

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        path.append(name)
        if !Self.inline.contains(name) {
            text = ""
        }
        if skippingDepth != nil { return }
        if attributes["xml:lang"] != nil {
            skippingDepth = path.count
            return
        }
        switch name {
        case "component" where path.count <= 2:
            let type = attributes["type"] ?? ""
            if type == "desktop-application" || type == "desktop" || type == "console-application" {
                app = CatalogApp(id: "", name: "", isGraphical: type != "console-application")
                bestIconWidth = 0
            } else {
                app = nil
                skippingDepth = path.count
            }
        case "description":
            blocks = []
        case "ul", "ol":
            items = []
        case "icon":
            iconIsCached = attributes["type"] == "cached"
            iconWidth = Int(attributes["width"] ?? "") ?? 0
        case "url":
            urlType = attributes["type"]
        case "release":
            release = Release(
                version: attributes["version"] ?? "",
                timestamp: Int(attributes["timestamp"] ?? "") ?? 0,
                isStable: (attributes["type"] ?? "stable") == "stable"
            )
        case "screenshots", "content_rating", "languages", "requires", "recommends", "supports",
             "provides", "branding", "translation", "custom", "suggests", "metadata":
            skippingDepth = path.count
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA data: Data) {
        text += String(decoding: data, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        defer {
            path.removeLast()
            if !Self.inline.contains(name) {
                text = ""
            }
        }
        if let depth = skippingDepth {
            if path.count == depth {
                skippingDepth = nil
            }
            return
        }
        guard app != nil else { return }
        let value = Self.collapsed(text)
        let parent = path.count >= 2 ? path[path.count - 2] : ""
        let inRelease = path.contains("release")
        switch name {
        case "component":
            if let app, !app.id.isEmpty, !app.name.isEmpty {
                apps.append(app)
            }
            app = nil
        case "id" where parent == "component":
            app?.id = value
        case "name" where parent == "component":
            app?.name = value
        case "name" where parent == "developer":
            app?.developer = value
        case "developer_name" where app?.developer.isEmpty ?? false:
            app?.developer = value
        case "summary" where parent == "component":
            app?.summary = value
        case "project_license":
            app?.license = value
        case "category":
            app?.categories.append(value)
        case "keyword":
            app?.keywords.append(value)
        case "bundle":
            if app?.bundle == nil { app?.bundle = value }
        case "url":
            if urlType == "homepage" { app?.homepage = value }
        case "icon":
            // The cached icon nearest 64 pixels wide, as the list shows it.
            if iconIsCached, !value.isEmpty, app?.icon == nil || abs(iconWidth - 64) < abs(bestIconWidth - 64) {
                app?.icon = value
                bestIconWidth = iconWidth
            }
        case "p":
            if !value.isEmpty { blocks.append(.paragraph(value)) }
        case "li":
            if !value.isEmpty { items.append(value) }
        case "ul", "ol":
            if !items.isEmpty { blocks.append(.list(items)) }
            items = []
        case "description":
            if inRelease {
                release?.notes = blocks
            } else if parent == "component" {
                app?.description = blocks
            }
            blocks = []
        case "release":
            if let release, !release.version.isEmpty {
                app?.releases.append(release)
            }
            release = nil
        default:
            break
        }
    }

    /// Elements inside a paragraph's text, which keep it going.
    static let inline: Set<String> = ["em", "code"]

    /// Runs of whitespace, as XML text has them across lines, as one
    /// space, and none at either end.
    static func collapsed(_ text: String) -> String {
        var output = ""
        var pendingSpace = false
        for character in text {
            if character.isWhitespace {
                pendingSpace = !output.isEmpty
            } else {
                if pendingSpace {
                    output.append(" ")
                    pendingSpace = false
                }
                output.append(character)
            }
        }
        return output
    }
}
