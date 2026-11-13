//
//  ZoteroLibraryLocator.swift
//  PaperFocus
//

import Foundation
import SQLite3
import SwiftData

nonisolated struct ZoteroLibraryCandidate: Identifiable, Hashable, Sendable {
    let rootPath: String
    let sourceDescription: String

    var id: String { rootPath }

    var rootURL: URL {
        URL(fileURLWithPath: rootPath, isDirectory: true)
    }
}

nonisolated struct PaperFocusLibraryItem: Sendable {
    var uuid: String = ""
    var title: String = ""
    var subtitle: String = ""
    var authors: String = ""
    var editors: String = ""
    var citationKey: String = ""
    var itemType: String = "journalArticle"
    var journal: String = ""
    var publisher: String = ""
    var volume: String = ""
    var issue: String = ""
    var pages: String = ""
    var year: Int?
    var dateText: String = ""
    var doi: String = ""
    var url: String = ""
    var isbn: String = ""
    var issn: String = ""
    var pmid: String = ""
    var abstractText: String = ""
    var notes: String = ""
    var language: String = ""
    var tagsText: String = ""
    var collectionPath: String = ""
    var pdfPath: String = ""
}

nonisolated enum LiteratureLibraryKind: Sendable {
    case zoteroDataDirectory
    case zoteroJSON
    case endNoteXML
    case paperFocusExport
    case paperFocusStore
    case endNotePackage
    case pdf
    case pdfFolder
    case unrecognized

    static func detect(at url: URL) -> LiteratureLibraryKind {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return .unrecognized
        }

        if isDirectory.boolValue {
            return detectDirectory(url, fileManager: fileManager)
        }

        let extensionName = url.pathExtension.lowercased()
        if extensionName == "pdf" {
            return .pdf
        }
        if extensionName == "enl" {
            return .endNotePackage
        }
        if extensionName == "json" {
            return detectJSON(at: url)
        }
        if extensionName == "xml" {
            return detectXML(at: url) ? .endNoteXML : .unrecognized
        }
        if ZoteroDatabaseValidator.isValidZoteroDatabase(at: url) {
            return .zoteroDataDirectory
        }
        if PaperFocusLibraryStore.isValidStore(at: url) {
            return .paperFocusStore
        }
        return .unrecognized
    }

    private static func detectDirectory(_ url: URL, fileManager: FileManager) -> LiteratureLibraryKind {
        let databaseURL = url.appendingPathComponent("zotero.sqlite")
        if fileManager.fileExists(atPath: databaseURL.path),
           ZoteroDatabaseValidator.isValidZoteroDatabase(at: databaseURL) {
            return .zoteroDataDirectory
        }

        if PaperFocusLibraryStore.containsStore(in: url) {
            return .paperFocusStore
        }

        let exportURL = url.appendingPathComponent("paperfocus-library.json")
        if fileManager.fileExists(atPath: exportURL.path), detectJSON(at: exportURL) == .paperFocusExport {
            return .paperFocusExport
        }

        if directoryContainsPDF(url, fileManager: fileManager) {
            return .pdfFolder
        }
        return .unrecognized
    }

    private static func detectJSON(at url: URL) -> LiteratureLibraryKind {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return .unrecognized
        }

        if let dictionary = json as? [String: Any] {
            let format = (dictionary["format"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
            if format == "paperfocus.library" {
                return .paperFocusExport
            }
            if dictionary["items"] is [[String: Any]] {
                return .zoteroJSON
            }
        }

        if let items = json as? [[String: Any]],
           items.contains(where: { item in
               let itemType = (item["itemType"] as? String) ?? ((item["data"] as? [String: Any])?["itemType"] as? String)
               return !(itemType ?? "").isEmpty
           }) {
            return .zoteroJSON
        }

        return .unrecognized
    }

    private static func detectXML(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            return false
        }
        let prefix = data.prefix(512 * 1024)
        guard let text = String(data: prefix, encoding: .utf8)?.lowercased() else {
            return false
        }
        guard text.contains("<record") else { return false }
        return text.contains("<ref-type")
            || text.contains("<rec-number")
            || text.contains("<source-app")
            || text.contains("app=\"en\"")
    }

    private static func directoryContainsPDF(_ url: URL, fileManager: FileManager) -> Bool {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        var inspected = 0
        for case let fileURL as URL in enumerator {
            inspected += 1
            if inspected > 400 {
                break
            }
            if fileURL.pathExtension.lowercased() == "pdf" {
                return true
            }
        }
        return false
    }
}

nonisolated enum ZoteroLibraryLocator {
    static func candidates() -> [ZoteroLibraryCandidate] {
        #if os(macOS)
        return macOSCandidates()
        #else
        return []
        #endif
    }

    #if os(macOS)
    private static func macOSCandidates() -> [ZoteroLibraryCandidate] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        var ordered: [(URL, String)] = []

        ordered.append((home.appendingPathComponent("Zotero", isDirectory: true), "默认数据目录"))
        ordered.append((home.appendingPathComponent("Documents/Zotero", isDirectory: true), "文稿中的 Zotero 目录"))

        let support = home.appendingPathComponent("Library/Application Support/Zotero", isDirectory: true)
        ordered.append((support, "应用支持目录"))

        for profile in profileDirectories(in: support, fileManager: fileManager) {
            if let dataDirectory = dataDirectory(fromProfile: profile) {
                ordered.append((dataDirectory, "配置文件中的数据目录"))
            }
            ordered.append((profile, "配置文件目录"))
        }

        var seen: Set<String> = []
        var results: [ZoteroLibraryCandidate] = []
        for (url, source) in ordered {
            let standardized = url.standardizedFileURL
            let key = standardized.resolvingSymlinksInPath().path
            guard seen.insert(key).inserted else { continue }
            let databaseURL = standardized.appendingPathComponent("zotero.sqlite")
            guard fileManager.fileExists(atPath: databaseURL.path) else { continue }
            guard ZoteroDatabaseValidator.isValidZoteroDatabase(at: databaseURL) else { continue }
            results.append(
                ZoteroLibraryCandidate(
                    rootPath: standardized.path,
                    sourceDescription: source
                )
            )
        }
        return results
    }
    #endif

    #if os(macOS)
    private static func profileDirectories(in support: URL, fileManager: FileManager) -> [URL] {
        var directories: [URL] = []
        let profilesFile = support.appendingPathComponent("profiles.ini")
        if let text = try? String(contentsOf: profilesFile, encoding: .utf8) {
            directories.append(contentsOf: parseProfilePaths(from: text, base: support))
        }

        let profilesDirectory = support.appendingPathComponent("Profiles", isDirectory: true)
        if let children = try? fileManager.contentsOfDirectory(
            at: profilesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for child in children {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: child.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    directories.append(child)
                }
            }
        }
        return directories
    }

    private static func parseProfilePaths(from text: String, base: URL) -> [URL] {
        var results: [URL] = []
        var isRelative = true
        var path: String?

        func flush() {
            guard let path else { return }
            let expanded = (path as NSString).expandingTildeInPath
            let url = isRelative
                ? base.appendingPathComponent(expanded)
                : URL(fileURLWithPath: expanded, isDirectory: true)
            results.append(url)
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                flush()
                path = nil
                isRelative = true
                continue
            }
            if line.hasPrefix("IsRelative=") {
                isRelative = line != "IsRelative=0"
            } else if line.hasPrefix("Path=") {
                path = String(line.dropFirst("Path=".count))
            }
        }
        flush()
        return results
    }

    private static func dataDirectory(fromProfile profile: URL) -> URL? {
        let preferencesURL = profile.appendingPathComponent("prefs.js")
        guard let text = try? String(contentsOf: preferencesURL, encoding: .utf8) else {
            return nil
        }

        if text.contains("user_pref(\"extensions.zotero.useDataDir\", false)") {
            return nil
        }

        guard let range = text.range(of: "user_pref(\"extensions.zotero.dataDir\", \"") else {
            return nil
        }
        let remainder = text[range.upperBound...]
        guard let end = remainder.firstIndex(of: "\"") else { return nil }
        let raw = String(remainder[..<end])
            .replacingOccurrences(of: "\\\\", with: "\\")
            .replacingOccurrences(of: "\\\"", with: "\"")
        let expanded = (raw as NSString).expandingTildeInPath
        guard !expanded.isEmpty else { return nil }
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }
    #endif
}

nonisolated enum ZoteroDatabaseValidator {
    private static let requiredTables: Set<String> = [
        "items", "itemtypes", "itemdata", "itemdatavalues", "fields"
    ]

    static func hasSQLiteHeader(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 16) else { return false }
        return data.starts(with: Data("SQLite format 3\u{0}".utf8))
    }

    static func isValidZoteroDatabase(at url: URL) -> Bool {
        do {
            try validate(at: url)
            return true
        } catch {
            return false
        }
    }

    static func validate(at url: URL) throws {
        guard hasSQLiteHeader(at: url) else {
            throw LibraryImportError.invalidZoteroLibrary
        }

        let database = try openReadonly(url)
        defer { sqlite3_close(database) }

        let tables = Set(tableNames(database).map { $0.lowercased() })
        guard requiredTables.isSubset(of: tables) else {
            throw LibraryImportError.invalidZoteroLibrary
        }
        if tables.contains("zpaper") {
            throw LibraryImportError.invalidZoteroLibrary
        }

        let itemTypeColumns = Set(columnNames(database, table: "itemTypes").map { $0.lowercased() })
        guard itemTypeColumns.contains("typename") else {
            throw LibraryImportError.invalidZoteroLibrary
        }

        let fieldColumns = Set(columnNames(database, table: "fields").map { $0.lowercased() })
        guard fieldColumns.contains("fieldname") else {
            throw LibraryImportError.invalidZoteroLibrary
        }

        if tables.contains("version") {
            let rows = query(database, sql: "SELECT schema FROM version WHERE schema = 'userdata' LIMIT 1")
            guard !rows.isEmpty else {
                throw LibraryImportError.invalidZoteroLibrary
            }
        }
    }

    private static func openReadonly(_ url: URL) throws -> OpaquePointer {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let database else {
            if let database {
                sqlite3_close(database)
            }
            throw LibraryImportError.invalidZoteroLibrary
        }
        return database
    }

    private static func tableNames(_ database: OpaquePointer) -> [String] {
        query(database, sql: "SELECT name FROM sqlite_master WHERE type = 'table'").compactMap { $0["name"] }
    }

    private static func columnNames(_ database: OpaquePointer, table: String) -> [String] {
        let escaped = table.replacingOccurrences(of: "'", with: "''")
        return query(database, sql: "SELECT name FROM pragma_table_info('\(escaped)')").compactMap { $0["name"] }
    }

    private static func query(_ database: OpaquePointer, sql: String) -> [[String: String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return []
        }
        defer { sqlite3_finalize(statement) }

        var rows: [[String: String]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: String] = [:]
            let columnCount = sqlite3_column_count(statement)
            for index in 0..<columnCount {
                guard let namePointer = sqlite3_column_name(statement, index) else { continue }
                let name = String(cString: namePointer)
                if let valuePointer = sqlite3_column_text(statement, index) {
                    row[name] = String(cString: valuePointer)
                } else {
                    row[name] = ""
                }
            }
            rows.append(row)
        }
        return rows
    }
}

nonisolated enum PaperFocusLibraryStore {
    static let rejectedDefaultsKey = "library.paperfocus.storeRejected"

    static func defaultStoreURL() -> URL {
        ModelConfiguration().url
    }

    static func isOpenStore(_ url: URL) -> Bool {
        let rejected = UserDefaults.standard.bool(forKey: rejectedDefaultsKey)
        guard !rejected else { return false }
        return url.standardizedFileURL.path == defaultStoreURL().standardizedFileURL.path
    }

    static func isValidStore(at url: URL) -> Bool {
        guard ZoteroDatabaseValidator.hasSQLiteHeader(at: url) else { return false }
        return tableNames(at: url).contains { $0.uppercased() == "ZPAPER" }
    }

    static func containsStore(in directory: URL) -> Bool {
        let fileManager = FileManager.default
        let direct = directory.appendingPathComponent("default.store")
        if fileManager.fileExists(atPath: direct.path), isValidStore(at: direct) {
            return true
        }
        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }
        return children.contains { child in
            child.pathExtension.lowercased() == "store" && isValidStore(at: child)
        }
    }

    static func shouldRejectDefaultStore() -> Bool {
        let url = defaultStoreURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        guard size > 0 else { return false }
        return !isValidStore(at: url)
    }

    private static func tableNames(at url: URL) -> [String] {
        guard ZoteroDatabaseValidator.hasSQLiteHeader(at: url) else { return [] }
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            return []
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            database,
            "SELECT name FROM sqlite_master WHERE type = 'table'",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return []
        }
        defer { sqlite3_finalize(statement) }

        var names: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let value = sqlite3_column_text(statement, 0) {
                names.append(String(cString: value))
            }
        }
        return names
    }
}

nonisolated enum PaperFocusLibraryReader {
    static func items(at url: URL) throws -> [PaperFocusLibraryItem] {
        let kind = LiteratureLibraryKind.detect(at: url)
        switch kind {
        case .paperFocusExport:
            return try itemsFromExport(at: url)
        case .paperFocusStore:
            let storeURL = resolveStoreURL(from: url)
            return try itemsFromStore(at: storeURL)
        default:
            throw LibraryImportError.invalidPaperFocusLibrary
        }
    }

    private static func resolveStoreURL(from url: URL) -> URL {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            let direct = url.appendingPathComponent("default.store")
            if FileManager.default.fileExists(atPath: direct.path) {
                return direct
            }
            if let children = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ), let match = children.first(where: { $0.pathExtension.lowercased() == "store" }) {
                return match
            }
        }
        return url
    }

    private static func itemsFromExport(at url: URL) throws -> [PaperFocusLibraryItem] {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = json as? [String: Any],
              ((dictionary["format"] as? String) ?? "").lowercased() == "paperfocus.library",
              let papers = dictionary["papers"] as? [[String: Any]] else {
            throw LibraryImportError.invalidPaperFocusLibrary
        }
        return papers.map(item(fromJSON:))
    }

    private static func item(fromJSON dictionary: [String: Any]) -> PaperFocusLibraryItem {
        var item = PaperFocusLibraryItem()
        item.uuid = text(dictionary["uuid"])
        item.title = text(dictionary["title"])
        item.subtitle = text(dictionary["subtitle"])
        item.authors = text(dictionary["authors"])
        item.editors = text(dictionary["editors"])
        item.citationKey = text(dictionary["citationKey"])
        item.itemType = text(dictionary["itemType"]).isEmpty ? "journalArticle" : text(dictionary["itemType"])
        item.journal = text(dictionary["journal"])
        item.publisher = text(dictionary["publisher"])
        item.volume = text(dictionary["volume"])
        item.issue = text(dictionary["issue"])
        item.pages = text(dictionary["pages"])
        item.year = intValue(dictionary["year"])
        item.dateText = text(dictionary["dateText"])
        item.doi = text(dictionary["doi"])
        item.url = text(dictionary["url"])
        item.isbn = text(dictionary["isbn"])
        item.issn = text(dictionary["issn"])
        item.pmid = text(dictionary["pmid"])
        item.abstractText = text(dictionary["abstractText"])
        item.notes = text(dictionary["notes"])
        item.language = text(dictionary["language"])
        item.tagsText = text(dictionary["tagsText"])
        item.collectionPath = text(dictionary["collectionPath"])
        item.pdfPath = text(dictionary["pdfPath"])
        return item
    }

    private static func itemsFromStore(at url: URL) throws -> [PaperFocusLibraryItem] {
        guard PaperFocusLibraryStore.isValidStore(at: url) else {
            throw LibraryImportError.invalidPaperFocusLibrary
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            throw LibraryImportError.invalidPaperFocusLibrary
        }
        defer { sqlite3_close(database) }

        let columns = columnNames(database)
        guard !columns.isEmpty else {
            throw LibraryImportError.invalidPaperFocusLibrary
        }

        let selected = columns.joined(separator: ", ")
        let sql = "SELECT \(selected) FROM ZPAPER"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            throw LibraryImportError.invalidPaperFocusLibrary
        }
        defer { sqlite3_finalize(statement) }

        var items: [PaperFocusLibraryItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var values: [String: String] = [:]
            for (index, name) in columns.enumerated() {
                let column = Int32(index)
                if sqlite3_column_type(statement, column) == SQLITE_NULL {
                    values[name.uppercased()] = ""
                } else if let text = sqlite3_column_text(statement, column) {
                    values[name.uppercased()] = String(cString: text)
                } else {
                    values[name.uppercased()] = String(sqlite3_column_int64(statement, column))
                }
            }
            items.append(item(fromColumns: values))
        }
        return items
    }

    private static func columnNames(_ database: OpaquePointer) -> [String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT name FROM pragma_table_info('ZPAPER')", -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return []
        }
        defer { sqlite3_finalize(statement) }
        var names: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let value = sqlite3_column_text(statement, 0) {
                let name = String(cString: value)
                if name.uppercased().hasPrefix("Z"), name.uppercased() != "Z_PK", name.uppercased() != "Z_ENT", name.uppercased() != "Z_OPT" {
                    names.append(name)
                }
            }
        }
        return names
    }

    private static func item(fromColumns values: [String: String]) -> PaperFocusLibraryItem {
        func value(_ name: String) -> String {
            values["Z\(name.uppercased())"] ?? ""
        }

        var item = PaperFocusLibraryItem()
        item.uuid = value("uuid")
        item.title = value("title")
        item.subtitle = value("subtitle")
        item.authors = value("authors")
        item.editors = value("editors")
        item.citationKey = value("citationKey")
        let itemType = value("itemType")
        item.itemType = itemType.isEmpty ? "journalArticle" : itemType
        item.journal = value("journal")
        item.publisher = value("publisher")
        item.volume = value("volume")
        item.issue = value("issue")
        item.pages = value("pages")
        item.year = Int(value("year"))
        item.dateText = value("dateText")
        item.doi = value("doi")
        item.url = value("url")
        item.isbn = value("isbn")
        item.issn = value("issn")
        item.pmid = value("pmid")
        item.abstractText = value("abstractText")
        item.notes = value("notes")
        item.language = value("language")
        item.tagsText = value("tagsText")
        item.collectionPath = value("collectionPath")
        item.pdfPath = value("pdfPath")
        return item
    }

    private static func text(_ raw: Any?) -> String {
        if let string = raw as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let number = raw as? NSNumber {
            return number.stringValue
        }
        return ""
    }

    private static func intValue(_ raw: Any?) -> Int? {
        if let number = raw as? NSNumber {
            return number.intValue
        }
        if let string = raw as? String {
            return Int(string)
        }
        return nil
    }
}
