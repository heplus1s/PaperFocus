//
//  LibraryImportService.swift
//  PaperFocus
//

import Foundation
import SwiftData
import SQLite3

struct LibraryImportSummary {
    var importedCount: Int = 0
    var updatedCount: Int = 0
    var skippedCount: Int = 0
    var removedCount: Int = 0
    var totalCount: Int?

    var importMessage: String {
        var parts: [String] = []
        if importedCount > 0 {
            parts.append(AppSettings.localizedFormat("新增 %d 条", defaultValue: "新增 %d 条", importedCount))
        }
        if updatedCount > 0 {
            parts.append(AppSettings.localizedFormat("更新 %d 条", defaultValue: "更新 %d 条", updatedCount))
        }
        if removedCount > 0 {
            parts.append(AppSettings.localizedFormat("删除 %d 条", defaultValue: "删除 %d 条", removedCount))
        }
        if skippedCount > 0 {
            parts.append(AppSettings.localizedFormat("跳过 %d 条", defaultValue: "跳过 %d 条", skippedCount))
        }
        return parts.isEmpty
            ? AppSettings.localizedString("没有可导入的记录。")
            : parts.joined(separator: AppSettings.localizedString("，"))
    }

    var syncMessage: String {
        var changes: [String] = []
        if importedCount > 0 {
            changes.append(AppSettings.localizedFormat("新增 %d 条", defaultValue: "新增 %d 条", importedCount))
        }
        if removedCount > 0 {
            changes.append(AppSettings.localizedFormat("减少 %d 条", defaultValue: "减少 %d 条", removedCount))
        }

        let changeText = changes.isEmpty
            ? AppSettings.localizedString("当前无新增或减少")
            : changes.joined(separator: AppSettings.localizedString("，"))
        if let totalCount {
            return AppSettings.localizedFormat("%@，共 %d 条", defaultValue: "%@，共 %d 条", changeText, totalCount)
        }
        return changeText
    }

    var message: String {
        importMessage
    }
}

struct LinkedZoteroLibraryLinkResult {
    let summary: LibraryImportSummary
    let rootURL: URL
}

nonisolated enum LibraryImportError: LocalizedError, Sendable {
    case invalidZoteroFile
    case invalidZoteroLibrary
    case invalidEndNoteFile
    case noSupportedRecords
    case cannotReadFolder
    case zoteroAccessDenied
    case zoteroDatabaseOpenFailed(String)
    case zoteroQueryFailed(String)
    case zoteroSnapshotFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidZoteroFile:
            return "无法识别 Zotero 导出文件，请选择 JSON 导出文件。"
        case .invalidZoteroLibrary:
            return "无法识别 Zotero 本地文献库，请选择包含 `zotero.sqlite` 的目录、它的上一级目录，或直接选择 `zotero.sqlite` 文件。"
        case .invalidEndNoteFile:
            return "无法识别 EndNote 导出文件，请选择 XML 导出文件。"
        case .noSupportedRecords:
            return "没有找到可导入的文献记录。"
        case .cannotReadFolder:
            return "无法读取选中的 PDF 文件夹。"
        case .zoteroAccessDenied:
            return "无法访问你选择的 Zotero 位置。请重新授权该目录或 `zotero.sqlite` 文件。"
        case .zoteroDatabaseOpenFailed(let message):
            return "无法打开 Zotero 数据库：\(message)"
        case .zoteroQueryFailed(let message):
            return "无法读取 Zotero 数据库内容：\(message)"
        case .zoteroSnapshotFailed(let message):
            return "无法创建 Zotero 数据库快照：\(message)"
        }
    }
}

final class LibraryImportService {
    nonisolated static func resolveZoteroLibraryRoot(from selectedURL: URL) throws -> URL {
        let fileManager = FileManager.default
        var candidateDirectories: [URL] = []

        if selectedURL.lastPathComponent.lowercased() == "zotero.sqlite" {
            candidateDirectories.append(selectedURL.deletingLastPathComponent())
        } else {
            candidateDirectories.append(selectedURL)
        }

        let directChildren = (try? fileManager.contentsOfDirectory(
            at: selectedURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        candidateDirectories.append(contentsOf: directChildren.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        })

        if let resolved = candidateDirectories.first(where: {
            fileManager.fileExists(atPath: $0.appendingPathComponent("zotero.sqlite").path)
        }) {
            return resolved
        }

        guard let enumerator = fileManager.enumerator(
            at: selectedURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw LibraryImportError.invalidZoteroLibrary
        }

        for case let url as URL in enumerator {
            let relativePath = url.path.replacingOccurrences(of: selectedURL.path, with: "")
            let depth = relativePath.split(separator: "/").count
            if depth > 3 {
                enumerator.skipDescendants()
                continue
            }

            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                continue
            }

            if fileManager.fileExists(atPath: url.appendingPathComponent("zotero.sqlite").path) {
                return url
            }
        }

        throw LibraryImportError.invalidZoteroLibrary
    }

    func linkZoteroLibrary(from selectedURL: URL, into modelContext: ModelContext) async throws -> LinkedZoteroLibraryLinkResult {
        let didAccess = selectedURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                selectedURL.stopAccessingSecurityScopedResource()
            }
        }

        let resolvedRootURL = try await Self.readOffMain {
            try LibraryImportService.resolveZoteroLibraryRoot(from: selectedURL)
        }
        let bookmarkURL = selectedURL.standardizedFileURL
        try SecurityScopedBookmarkStore.shared.saveBookmark(
            for: .zoteroLocal,
            url: bookmarkURL,
            associatedRootPath: resolvedRootURL.standardizedFileURL.path
        )
        let records = try await Self.readOffMain {
            try LibraryImportService.parseLinkedZoteroRecords(from: resolvedRootURL)
        }
        let summary = try persistLinkedSnapshot(
            records: records,
            into: modelContext,
            sourceLibraryType: "zotero",
            sourceLibraryName: resolvedRootURL.lastPathComponent,
            importMethod: "zoteroLinked",
            copyAttachmentsToLibrary: false
        )
        return LinkedZoteroLibraryLinkResult(summary: summary, rootURL: resolvedRootURL)
    }

    func refreshLinkedZoteroLibrary(into modelContext: ModelContext) async throws -> LibraryImportSummary {
        guard let handle = SecurityScopedBookmarkStore.shared.beginAccess(for: .zoteroLocal) else {
            throw LibraryImportError.zoteroAccessDenied
        }
        defer {
            SecurityScopedBookmarkStore.shared.endAccess(handle)
        }

        let rootURL = try storedLinkedZoteroRootURL()
        let records = try await Self.readOffMain {
            try LibraryImportService.parseLinkedZoteroRecords(from: rootURL)
        }
        return try persistLinkedSnapshot(
            records: records,
            into: modelContext,
            sourceLibraryType: "zotero",
            sourceLibraryName: rootURL.lastPathComponent,
            importMethod: "zoteroLinked",
            copyAttachmentsToLibrary: false
        )
    }

    func importZotero(from url: URL, into modelContext: ModelContext) async throws -> LibraryImportSummary {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let records = try await Self.readOffMain {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data)
            let parsed = try LibraryImportService.parseZoteroRecords(from: json, sourceURL: url)
            return LibraryImportService.storingCopiesInLibrary(parsed)
        }
        return try persist(records: records, into: modelContext, copyAttachmentsToLibrary: false)
    }

    func linkEndNoteXML(from url: URL, into modelContext: ModelContext) async throws -> LibraryImportSummary {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        try SecurityScopedBookmarkStore.shared.saveBookmark(for: .endNoteXML, url: url.deletingLastPathComponent())
        let records = try await Self.readOffMain {
            let data = try Data(contentsOf: url)
            return try EndNoteXMLImportParser(sourceURL: url, importMethod: "endnoteLinked").parse(data: data)
        }
        return try persistLinkedSnapshot(
            records: records,
            into: modelContext,
            sourceLibraryType: "endnote",
            sourceLibraryName: url.deletingPathExtension().lastPathComponent,
            importMethod: "endnoteLinked",
            copyAttachmentsToLibrary: false
        )
    }

    func refreshLinkedEndNoteXML(from linkedXMLPath: String, into modelContext: ModelContext) async throws -> LibraryImportSummary {
        guard let handle = SecurityScopedBookmarkStore.shared.beginAccess(for: .endNoteXML) else {
            throw LibraryImportError.invalidEndNoteFile
        }
        defer {
            SecurityScopedBookmarkStore.shared.endAccess(handle)
        }

        let url = URL(fileURLWithPath: linkedXMLPath)
        let records = try await Self.readOffMain {
            let data = try Data(contentsOf: url)
            return try EndNoteXMLImportParser(sourceURL: url, importMethod: "endnoteLinked").parse(data: data)
        }
        return try persistLinkedSnapshot(
            records: records,
            into: modelContext,
            sourceLibraryType: "endnote",
            sourceLibraryName: url.deletingPathExtension().lastPathComponent,
            importMethod: "endnoteLinked",
            copyAttachmentsToLibrary: false
        )
    }

    func importEndNoteXML(from url: URL, into modelContext: ModelContext) async throws -> LibraryImportSummary {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let records = try await Self.readOffMain {
            let data = try Data(contentsOf: url)
            let parsed = try EndNoteXMLImportParser(sourceURL: url).parse(data: data)
            return LibraryImportService.storingCopiesInLibrary(parsed)
        }
        return try persist(records: records, into: modelContext, copyAttachmentsToLibrary: false)
    }

    func importPDFFolder(from rootURL: URL, into modelContext: ModelContext) async throws -> LibraryImportSummary {
        let didAccess = rootURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                rootURL.stopAccessingSecurityScopedResource()
            }
        }

        let records = try await Self.readOffMain {
            let collected = try LibraryImportService.collectPDFFolderRecords(from: rootURL)
            return LibraryImportService.storingCopiesInLibrary(collected)
        }
        return try persist(records: records, into: modelContext, copyAttachmentsToLibrary: false)
    }

    private nonisolated static func readOffMain<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await Task.detached(priority: .userInitiated) {
            try work()
        }.value
    }

    private nonisolated static func collectPDFFolderRecords(from rootURL: URL) throws -> [ImportedPaperRecord] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw LibraryImportError.cannotReadFolder
        }

        var records: [ImportedPaperRecord] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "pdf" else { continue }

            let relativeDirectory = relativeCollectionPath(for: fileURL.deletingLastPathComponent(), rootURL: rootURL)
            let metadata = PaperMetadataImporter.localMetadata(from: fileURL)
            let fileAttributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = (fileAttributes?[.size] as? NSNumber)?.int64Value ?? 0

            records.append(
                ImportedPaperRecord(
                    sourceLibraryType: "folderImport",
                    sourceLibraryName: rootURL.lastPathComponent,
                    sourceRecordID: relativeDirectory.isEmpty ? fileURL.lastPathComponent : "\(relativeDirectory)/\(fileURL.lastPathComponent)",
                    importMethod: "folder",
                    databaseSource: metadata?.source.isEmpty == false ? metadata?.source ?? "Folder" : "Folder",
                    itemType: metadata?.itemType ?? "journalArticle",
                    citationKey: "",
                    title: metadata?.title.isEmpty == false ? metadata?.title ?? "" : fileURL.deletingPathExtension().lastPathComponent,
                    subtitle: "",
                    authors: metadata?.authors ?? "",
                    editors: "",
                    corporateAuthors: "",
                    journal: metadata?.journal ?? "",
                    journalAbbreviation: "",
                    conferenceName: "",
                    bookTitle: "",
                    publisher: metadata?.publisher ?? "",
                    publicationPlace: "",
                    volume: metadata?.volume ?? "",
                    issue: metadata?.issue ?? "",
                    pages: metadata?.pages ?? "",
                    articleNumber: "",
                    edition: "",
                    chapter: "",
                    series: "",
                    seriesTitle: "",
                    seriesText: "",
                    year: metadata?.year,
                    dateText: metadata?.dateText ?? "",
                    doi: metadata?.doi ?? "",
                    url: metadata?.url ?? "",
                    issn: "",
                    isbn: "",
                    pmid: "",
                    pmcid: "",
                    accessionNumber: "",
                    archive: "",
                    archiveLocation: "",
                    libraryCatalog: "",
                    callNumber: "",
                    abstractText: metadata?.abstractText ?? "",
                    notes: "",
                    extra: metadata?.extra ?? "",
                    language: metadata?.language ?? "",
                    rights: "",
                    tagsText: "",
                    collectionPaths: relativeDirectory.isEmpty ? [] : [relativeDirectory],
                    priority: "medium",
                    attachmentURL: fileURL,
                    sourceAttachmentPath: fileURL.path,
                    fileType: "pdf",
                    fileSize: fileSize,
                    hasPDF: true,
                    isInTrash: false,
                    isUnfiled: relativeDirectory.isEmpty,
                    isPublicationItem: false
                )
            )
        }

        guard !records.isEmpty else {
            throw LibraryImportError.noSupportedRecords
        }

        return records
    }

    private nonisolated static func parseZoteroRecords(from json: Any, sourceURL: URL) throws -> [ImportedPaperRecord] {
        let baseDirectory = sourceURL.deletingLastPathComponent()

        let rootDictionary = json as? [String: Any]
        let rawItems: [[String: Any]]

        if let items = rootDictionary?["items"] as? [[String: Any]] {
            rawItems = items
        } else if let items = json as? [[String: Any]] {
            rawItems = items
        } else {
            throw LibraryImportError.invalidZoteroFile
        }

        let collectionMap = makeZoteroCollectionMap(from: rootDictionary?["collections"])
        let attachmentMap = makeZoteroAttachmentMap(from: rawItems, baseDirectory: baseDirectory)
        let notesMap = makeZoteroNotesMap(from: rawItems)

        let records = rawItems.compactMap { item -> ImportedPaperRecord? in
            let itemType = stringValue(item["itemType"])
            let normalizedItemType = itemType.lowercased()

            guard !["note", "annotation"].contains(normalizedItemType) else {
                return nil
            }

            if normalizedItemType == "attachment" {
                let parentKey = stringValue(item["parentItem"])
                guard parentKey.isEmpty else { return nil }

                let pdfURL = resolvePrimaryPDFURL(from: item, baseDirectory: baseDirectory)
                    ?? attachmentMap[stringValue(item["key"])]
                let collectionPaths = resolveCollectionPaths(from: item["collections"], collectionMap: collectionMap)
                let notes = combinedNotes(item["notes"], extraNotes: notesMap[stringValue(item["key"])] ?? [])
                let tagsText = zoteroTagsText(from: item["tags"])

                return makeStandaloneAttachmentRecord(
                    sourceLibraryType: "zotero",
                    sourceLibraryName: sourceURL.deletingPathExtension().lastPathComponent,
                    sourceRecordID: stringValue(item["key"]),
                    importMethod: "zotero",
                    databaseSource: "Zotero",
                    attachmentURL: pdfURL,
                    title: stringValue(item["title"]),
                    language: stringValue(item["language"]),
                    dateText: stringValue(item["date"]),
                    notes: notes,
                    extra: stringValue(item["extra"]),
                    rights: stringValue(item["rights"]),
                    tagsText: tagsText,
                    collectionPaths: collectionPaths,
                    isInTrash: false,
                    isUnfiled: collectionPaths.isEmpty,
                    isPublicationItem: false
                )
            }

            let title = stringValue(item["title"])
            let authors = creatorsText(from: item["creators"], allowedTypes: Set(["author"]))
            let editors = creatorsText(from: item["creators"], allowedTypes: Set(["editor", "seriesEditor"]))
            let corporateAuthors = creatorsText(from: item["creators"], allowedTypes: Set(["contributor"]))
            let dateText = stringValue(item["date"])
            let year = extractYear(from: dateText)
            let collectionPaths = resolveCollectionPaths(from: item["collections"], collectionMap: collectionMap)
            let notes = combinedNotes(item["notes"], extraNotes: notesMap[stringValue(item["key"])] ?? [])
            let tagsText = zoteroTagsText(from: item["tags"])
            let pdfURL = resolvePrimaryPDFURL(from: item, baseDirectory: baseDirectory)
                ?? attachmentMap[stringValue(item["key"])]

            return ImportedPaperRecord(
                sourceLibraryType: "zotero",
                sourceLibraryName: sourceURL.deletingPathExtension().lastPathComponent,
                sourceRecordID: stringValue(item["key"]),
                importMethod: "zotero",
                databaseSource: "Zotero",
                itemType: itemType.isEmpty ? "journalArticle" : itemType,
                citationKey: stringValue(item["citationKey"]),
                title: title,
                subtitle: stringValue(item["shortTitle"]),
                authors: authors,
                editors: editors,
                corporateAuthors: corporateAuthors,
                journal: firstNonEmpty([
                    stringValue(item["publicationTitle"]),
                    stringValue(item["websiteTitle"])
                ]),
                journalAbbreviation: stringValue(item["journalAbbreviation"]),
                conferenceName: stringValue(item["conferenceName"]),
                bookTitle: stringValue(item["bookTitle"]),
                publisher: stringValue(item["publisher"]),
                publicationPlace: stringValue(item["place"]),
                volume: stringValue(item["volume"]),
                issue: stringValue(item["issue"]),
                pages: stringValue(item["pages"]),
                articleNumber: stringValue(item["articleNumber"]),
                edition: stringValue(item["edition"]),
                chapter: stringValue(item["chapter"]),
                series: stringValue(item["series"]),
                seriesTitle: stringValue(item["seriesTitle"]),
                seriesText: stringValue(item["seriesText"]),
                year: year,
                dateText: dateText,
                doi: firstNonEmpty([
                    stringValue(item["DOI"]),
                    stringValue(item["doi"])
                ]),
                url: stringValue(item["url"]),
                issn: stringValue(item["ISSN"]),
                isbn: stringValue(item["ISBN"]),
                pmid: stringValue(item["PMID"]),
                pmcid: stringValue(item["PMCID"]),
                accessionNumber: stringValue(item["accessionNumber"]),
                archive: stringValue(item["archive"]),
                archiveLocation: stringValue(item["archiveLocation"]),
                libraryCatalog: stringValue(item["libraryCatalog"]),
                callNumber: stringValue(item["callNumber"]),
                abstractText: stringValue(item["abstractNote"]),
                notes: notes,
                extra: stringValue(item["extra"]),
                language: stringValue(item["language"]),
                rights: stringValue(item["rights"]),
                tagsText: tagsText,
                collectionPaths: collectionPaths,
                priority: "medium",
                attachmentURL: pdfURL,
                sourceAttachmentPath: pdfURL?.path ?? "",
                fileType: pdfURL?.pathExtension.lowercased().isEmpty == false ? pdfURL?.pathExtension.lowercased() ?? "pdf" : "pdf",
                fileSize: fileSize(for: pdfURL),
                hasPDF: pdfURL != nil,
                isInTrash: false,
                isUnfiled: collectionPaths.isEmpty,
                isPublicationItem: false
            )
        }

        guard !records.isEmpty else {
            throw LibraryImportError.noSupportedRecords
        }

        return records
    }

    private func persist(
        records: [ImportedPaperRecord],
        into modelContext: ModelContext,
        copyAttachmentsToLibrary: Bool
    ) throws -> LibraryImportSummary {
        let descriptor = FetchDescriptor<Paper>()
        let existingPapers = try modelContext.fetch(descriptor)
        var lookup = PaperLookup(papers: existingPapers)
        var summary = LibraryImportSummary()

        for record in records {
            guard record.hasMeaningfulContent else {
                summary.skippedCount += 1
                continue
            }

            if let existing = lookup.match(record) {
                apply(record: record, to: existing, preferExistingContent: true, copyAttachmentsToLibrary: copyAttachmentsToLibrary)
                lookup.note(existing)
                summary.updatedCount += 1
            } else {
                let paper = Paper()
                apply(record: record, to: paper, preferExistingContent: false, copyAttachmentsToLibrary: copyAttachmentsToLibrary)
                modelContext.insert(paper)
                lookup.note(paper)
                summary.importedCount += 1
            }
        }

        guard summary.importedCount > 0 || summary.updatedCount > 0 else {
            throw LibraryImportError.noSupportedRecords
        }

        try modelContext.save()
        return summary
    }

    private func persistLinkedSnapshot(
        records: [ImportedPaperRecord],
        into modelContext: ModelContext,
        sourceLibraryType: String,
        sourceLibraryName: String,
        importMethod: String,
        copyAttachmentsToLibrary: Bool
    ) throws -> LibraryImportSummary {
        var summary = try persist(
            records: records,
            into: modelContext,
            copyAttachmentsToLibrary: copyAttachmentsToLibrary
        )

        let descriptor = FetchDescriptor<Paper>()
        let allPapers = try modelContext.fetch(descriptor)
        let scopedPapers = allPapers.filter {
            normalize($0.sourceLibraryType) == normalize(sourceLibraryType)
                && normalize($0.sourceLibraryName) == normalize(sourceLibraryName)
                && normalize($0.importMethod) == normalize(importMethod)
        }

        let activeRecordKeys = Set(records.compactMap(syncKey(for:)))
        let papersToRemove = scopedPapers.filter { paper in
            guard let key = syncKey(for: paper) else { return false }
            return !activeRecordKeys.contains(key)
        }

        for paper in papersToRemove {
            modelContext.delete(paper)
        }

        summary.removedCount = papersToRemove.count
        summary.totalCount = scopedPapers.count - papersToRemove.count

        try modelContext.save()
        return summary
    }

    private struct PaperLookup {
        private var byDOI: [String: Paper] = [:]
        private var bySource: [String: Paper] = [:]
        private var byText: [String: Paper] = [:]

        init(papers: [Paper]) {
            papers.forEach { note($0) }
        }

        mutating func note(_ paper: Paper) {
            let doi = normalized(paper.doi)
            if !doi.isEmpty, byDOI[doi] == nil {
                byDOI[doi] = paper
            }

            let sourceID = normalized(paper.sourceRecordID)
            if !sourceID.isEmpty {
                let key = normalized(paper.sourceLibraryType) + "\u{1f}" + sourceID
                if bySource[key] == nil {
                    bySource[key] = paper
                }
            }

            let title = normalized(paper.title)
            guard !title.isEmpty else { return }
            let yearPart = paper.year.map(String.init) ?? ""
            let key = title + "\u{1f}" + normalized(paper.authors) + "\u{1f}" + yearPart
            if byText[key] == nil {
                byText[key] = paper
            }
        }

        func match(_ record: ImportedPaperRecord) -> Paper? {
            let doi = normalized(record.doi)
            if !doi.isEmpty, let paper = byDOI[doi] {
                return paper
            }

            let sourceID = normalized(record.sourceRecordID)
            if !sourceID.isEmpty, let paper = bySource[normalized(record.sourceLibraryType) + "\u{1f}" + sourceID] {
                return paper
            }

            let title = normalized(record.title)
            guard !title.isEmpty else { return nil }
            let yearPart = record.year.map(String.init) ?? ""
            return byText[title + "\u{1f}" + normalized(record.authors) + "\u{1f}" + yearPart]
        }

        private func normalized(_ text: String) -> String {
            text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    private func apply(
        record: ImportedPaperRecord,
        to paper: Paper,
        preferExistingContent: Bool,
        copyAttachmentsToLibrary: Bool
    ) {
        paper.uuid = paper.uuid.isEmpty ? UUID().uuidString : paper.uuid
        assign(&paper.citationKey, value: Self.firstNonEmpty([record.citationKey, makeCitationKey(authors: record.authors, title: record.title, year: record.year)]), preferExisting: preferExistingContent)
        assign(&paper.itemType, value: record.itemType, preferExisting: preferExistingContent)
        assign(&paper.title, value: record.title, preferExisting: preferExistingContent)
        assign(&paper.subtitle, value: record.subtitle, preferExisting: preferExistingContent)
        assign(&paper.authors, value: record.authors, preferExisting: preferExistingContent)
        assign(&paper.editors, value: record.editors, preferExisting: preferExistingContent)
        assign(&paper.corporateAuthors, value: record.corporateAuthors, preferExisting: preferExistingContent)
        assign(&paper.journal, value: record.journal, preferExisting: preferExistingContent)
        assign(&paper.journalAbbreviation, value: record.journalAbbreviation, preferExisting: preferExistingContent)
        assign(&paper.conferenceName, value: record.conferenceName, preferExisting: preferExistingContent)
        assign(&paper.bookTitle, value: record.bookTitle, preferExisting: preferExistingContent)
        assign(&paper.publisher, value: record.publisher, preferExisting: preferExistingContent)
        assign(&paper.publicationPlace, value: record.publicationPlace, preferExisting: preferExistingContent)
        assign(&paper.volume, value: record.volume, preferExisting: preferExistingContent)
        assign(&paper.issue, value: record.issue, preferExisting: preferExistingContent)
        assign(&paper.pages, value: record.pages, preferExisting: preferExistingContent)
        assign(&paper.articleNumber, value: record.articleNumber, preferExisting: preferExistingContent)
        assign(&paper.edition, value: record.edition, preferExisting: preferExistingContent)
        assign(&paper.chapter, value: record.chapter, preferExisting: preferExistingContent)
        assign(&paper.series, value: record.series, preferExisting: preferExistingContent)
        assign(&paper.seriesTitle, value: record.seriesTitle, preferExisting: preferExistingContent)
        assign(&paper.seriesText, value: record.seriesText, preferExisting: preferExistingContent)

        if let year = record.year, paper.year == nil || !preferExistingContent {
            paper.year = year
        }

        assign(&paper.dateText, value: record.dateText, preferExisting: preferExistingContent)
        assign(&paper.doi, value: record.doi, preferExisting: preferExistingContent)
        assign(&paper.url, value: record.url, preferExisting: preferExistingContent)
        assign(&paper.issn, value: record.issn, preferExisting: preferExistingContent)
        assign(&paper.isbn, value: record.isbn, preferExisting: preferExistingContent)
        assign(&paper.pmid, value: record.pmid, preferExisting: preferExistingContent)
        assign(&paper.pmcid, value: record.pmcid, preferExisting: preferExistingContent)
        assign(&paper.accessionNumber, value: record.accessionNumber, preferExisting: preferExistingContent)
        assign(&paper.archive, value: record.archive, preferExisting: preferExistingContent)
        assign(&paper.archiveLocation, value: record.archiveLocation, preferExisting: preferExistingContent)
        assign(&paper.libraryCatalog, value: record.libraryCatalog, preferExisting: preferExistingContent)
        assign(&paper.callNumber, value: record.callNumber, preferExisting: preferExistingContent)
        assign(&paper.abstractText, value: record.abstractText, preferExisting: preferExistingContent)
        assign(&paper.notes, value: record.notes, preferExisting: preferExistingContent)
        assign(&paper.extra, value: record.extra, preferExisting: preferExistingContent)
        assign(&paper.language, value: record.language, preferExisting: preferExistingContent)
        assign(&paper.rights, value: record.rights, preferExisting: preferExistingContent)
        assign(&paper.tagsText, value: record.tagsText, preferExisting: preferExistingContent)

        let collectionPath = record.collectionPaths.first ?? ""
        assign(&paper.collection, value: collectionPath.split(separator: "/").last.map(String.init) ?? collectionPath, preferExisting: preferExistingContent)
        assign(&paper.collectionPath, value: collectionPath, preferExisting: preferExistingContent)
        assign(&paper.collectionsText, value: record.collectionPaths.joined(separator: "; "), preferExisting: preferExistingContent)
        assign(&paper.priority, value: record.priority, preferExisting: preferExistingContent)
        assign(&paper.databaseSource, value: record.databaseSource, preferExisting: preferExistingContent)
        assign(&paper.importMethod, value: record.importMethod, preferExisting: preferExistingContent)
        assign(&paper.sourceRecordID, value: record.sourceRecordID, preferExisting: preferExistingContent)
        assign(&paper.sourceLibraryType, value: record.sourceLibraryType, preferExisting: preferExistingContent)
        assign(&paper.sourceLibraryName, value: record.sourceLibraryName, preferExisting: preferExistingContent)
        assign(&paper.sourceAttachmentPath, value: record.sourceAttachmentPath, preferExisting: preferExistingContent)
        paper.isInTrash = record.isInTrash
        paper.isUnfiled = record.isUnfiled
        paper.isPublicationItem = record.isPublicationItem

        if let preparedFile = prepareAttachment(from: record.attachmentURL, copyAttachmentsToLibrary: copyAttachmentsToLibrary) {
            paper.pdfPath = preparedFile.path
            paper.pdfFileName = preparedFile.fileName
            paper.fileType = preparedFile.fileType
            paper.fileSize = preparedFile.fileSize
            paper.hasPDF = true
        } else if !preferExistingContent {
            paper.fileType = record.fileType
            paper.fileSize = record.fileSize
            paper.hasPDF = record.hasPDF
        }

        if paper.statusRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            paper.statusRaw = PaperStatus.unread.rawValue
        }
        paper.updatedAt = .now
    }

    private nonisolated static func storingCopiesInLibrary(_ records: [ImportedPaperRecord]) -> [ImportedPaperRecord] {
        records.map { record in
            guard let sourceURL = record.attachmentURL else { return record }
            guard let copiedURL = try? PaperFileService.importPDFToLibrary(from: sourceURL) else {
                var unavailable = record
                unavailable.attachmentURL = nil
                unavailable.hasPDF = false
                return unavailable
            }

            var stored = record
            stored.attachmentURL = copiedURL
            stored.fileSize = fileSize(for: copiedURL)
            stored.hasPDF = true
            return stored
        }
    }

    private func prepareAttachment(from url: URL?, copyAttachmentsToLibrary: Bool) -> PreparedAttachment? {
        guard let url, url.pathExtension.lowercased() == "pdf" else { return nil }

        let finalURL: URL
        if copyAttachmentsToLibrary {
            finalURL = (try? PaperFileService.importPDFToLibrary(from: url)) ?? url
        } else {
            finalURL = url
        }
        let fileManager = FileManager.default
        let attributes = try? fileManager.attributesOfItem(atPath: finalURL.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0

        return PreparedAttachment(
            path: finalURL.path,
            fileName: finalURL.lastPathComponent,
            fileType: finalURL.pathExtension.lowercased().isEmpty ? "pdf" : finalURL.pathExtension.lowercased(),
            fileSize: fileSize
        )
    }

    private nonisolated static func makeStandaloneAttachmentRecord(
        sourceLibraryType: String,
        sourceLibraryName: String,
        sourceRecordID: String,
        importMethod: String,
        databaseSource: String,
        attachmentURL: URL?,
        title: String,
        language: String,
        dateText: String,
        notes: String,
        extra: String,
        rights: String,
        tagsText: String,
        collectionPaths: [String],
        isInTrash: Bool,
        isUnfiled: Bool,
        isPublicationItem: Bool
    ) -> ImportedPaperRecord? {
        guard let attachmentURL, attachmentURL.pathExtension.lowercased() == "pdf" else {
            return nil
        }

        let localMetadata = PaperMetadataImporter.localMetadata(from: attachmentURL)
        let fileStem = attachmentURL.deletingPathExtension().lastPathComponent
        let resolvedTitle = firstNonEmpty([
            title,
            localMetadata?.title ?? "",
            fileStem
        ])

        return ImportedPaperRecord(
            sourceLibraryType: sourceLibraryType,
            sourceLibraryName: sourceLibraryName,
            sourceRecordID: sourceRecordID,
            importMethod: importMethod,
            databaseSource: firstNonEmpty([localMetadata?.source ?? "", databaseSource]),
            itemType: firstNonEmpty([localMetadata?.itemType ?? "", "journalArticle"]),
            citationKey: "",
            title: resolvedTitle,
            subtitle: "",
            authors: localMetadata?.authors ?? "",
            editors: "",
            corporateAuthors: "",
            journal: localMetadata?.journal ?? "",
            journalAbbreviation: "",
            conferenceName: "",
            bookTitle: "",
            publisher: localMetadata?.publisher ?? "",
            publicationPlace: "",
            volume: localMetadata?.volume ?? "",
            issue: localMetadata?.issue ?? "",
            pages: localMetadata?.pages ?? "",
            articleNumber: "",
            edition: "",
            chapter: "",
            series: "",
            seriesTitle: "",
            seriesText: "",
            year: localMetadata?.year ?? extractYear(from: dateText),
            dateText: firstNonEmpty([localMetadata?.dateText ?? "", dateText]),
            doi: localMetadata?.doi ?? "",
            url: localMetadata?.url ?? "",
            issn: "",
            isbn: "",
            pmid: "",
            pmcid: "",
            accessionNumber: "",
            archive: "",
            archiveLocation: "",
            libraryCatalog: "",
            callNumber: "",
            abstractText: localMetadata?.abstractText ?? "",
            notes: notes,
            extra: firstNonEmpty([localMetadata?.extra ?? "", extra]),
            language: firstNonEmpty([localMetadata?.language ?? "", language]),
            rights: rights,
            tagsText: tagsText,
            collectionPaths: collectionPaths,
            priority: "medium",
            attachmentURL: attachmentURL,
            sourceAttachmentPath: attachmentURL.path,
            fileType: attachmentURL.pathExtension.lowercased().isEmpty ? "pdf" : attachmentURL.pathExtension.lowercased(),
            fileSize: fileSize(for: attachmentURL),
            hasPDF: true,
            isInTrash: isInTrash,
            isUnfiled: isUnfiled,
            isPublicationItem: isPublicationItem
        )
    }

    private func assign(_ target: inout String, value: String, preferExisting: Bool) {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedValue.isEmpty else { return }
        if preferExisting && !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        target = normalizedValue
    }

    private func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func syncKey(for record: ImportedPaperRecord) -> String? {
        if !record.sourceRecordID.isEmpty {
            return "source:\(normalize(record.sourceRecordID))"
        }

        if !record.doi.isEmpty {
            return "doi:\(normalize(record.doi))"
        }

        let normalizedTitle = normalize(record.title)
        guard !normalizedTitle.isEmpty else { return nil }
        let normalizedAuthors = normalize(record.authors)
        let yearPart = record.year.map(String.init) ?? "noyear"
        return "text:\(normalizedTitle)|\(normalizedAuthors)|\(yearPart)"
    }

    private func syncKey(for paper: Paper) -> String? {
        if !paper.sourceRecordID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "source:\(normalize(paper.sourceRecordID))"
        }

        if !paper.doi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "doi:\(normalize(paper.doi))"
        }

        let normalizedTitle = normalize(paper.title)
        guard !normalizedTitle.isEmpty else { return nil }
        let normalizedAuthors = normalize(paper.authors)
        let yearPart = paper.year.map(String.init) ?? "noyear"
        return "text:\(normalizedTitle)|\(normalizedAuthors)|\(yearPart)"
    }

    private func makeCitationKey(authors: String, title: String, year: Int?) -> String {
        let firstAuthor = authors
            .split(separator: ",")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"

        let authorPart = firstAuthor
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()

        let titleWords = title
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == ":" || $0 == "：" })
            .prefix(3)
            .map {
                $0.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
            }
            .joined()

        let yearPart = year.map(String.init) ?? "noyear"
        let titlePart = String(titleWords.prefix(24))
        let key = authorPart.lowercased() + titlePart + yearPart

        return key.isEmpty ? UUID().uuidString : key
    }

    private nonisolated static func relativeCollectionPath(for directoryURL: URL, rootURL: URL) -> String {
        let rootComponents = rootURL.standardizedFileURL.pathComponents
        let directoryComponents = directoryURL.standardizedFileURL.pathComponents
        guard directoryComponents.count >= rootComponents.count else { return "" }

        let relativeComponents = Array(directoryComponents.dropFirst(rootComponents.count))
        return relativeComponents.joined(separator: "/")
    }

    private nonisolated static func creatorsText(from rawCreators: Any?, allowedTypes: Set<String>) -> String {
        guard let creators = rawCreators as? [[String: Any]] else { return "" }

        return creators.compactMap { creator in
            let creatorType = stringValue(creator["creatorType"])
            guard allowedTypes.contains(creatorType) else { return nil }

            let singleName = stringValue(creator["name"])
            if !singleName.isEmpty {
                return singleName
            }

            let firstName = stringValue(creator["firstName"])
            let lastName = stringValue(creator["lastName"])
            let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
            return fullName.isEmpty ? nil : fullName
        }
        .joined(separator: ", ")
    }

    private nonisolated static func zoteroTagsText(from rawTags: Any?) -> String {
        guard let tags = rawTags as? [Any] else { return "" }

        let values = tags.compactMap { item -> String? in
            if let value = item as? String {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let dictionary = item as? [String: Any] {
                return stringValue(dictionary["tag"])
            }
            return nil
        }

        return values.filter { !$0.isEmpty }.joined(separator: "; ")
    }

    private nonisolated static func combinedNotes(_ rawNotes: Any?, extraNotes: [String]) -> String {
        var parts: [String] = []

        if let notes = rawNotes as? [Any] {
            for note in notes {
                if let value = note as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    parts.append(stripHTML(from: value))
                } else if let dictionary = note as? [String: Any] {
                    let noteValue = stringValue(dictionary["note"])
                    if !noteValue.isEmpty {
                        parts.append(stripHTML(from: noteValue))
                    }
                }
            }
        }

        parts.append(contentsOf: extraNotes.map(stripHTML))
        return parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private nonisolated static func makeZoteroAttachmentMap(from items: [[String: Any]], baseDirectory: URL) -> [String: URL] {
        var result: [String: URL] = [:]

        for item in items {
            let itemType = stringValue(item["itemType"]).lowercased()
            guard itemType == "attachment" else { continue }
            let parentKey = stringValue(item["parentItem"])
            guard !parentKey.isEmpty else { continue }
            guard let url = resolvePrimaryPDFURL(from: item, baseDirectory: baseDirectory) else { continue }
            result[parentKey] = url
        }

        return result
    }

    private nonisolated static func makeZoteroNotesMap(from items: [[String: Any]]) -> [String: [String]] {
        var result: [String: [String]] = [:]

        for item in items {
            let itemType = stringValue(item["itemType"]).lowercased()
            guard itemType == "note" else { continue }
            let parentKey = stringValue(item["parentItem"])
            let note = stripHTML(from: stringValue(item["note"]))
            guard !parentKey.isEmpty, !note.isEmpty else { continue }
            result[parentKey, default: []].append(note)
        }

        return result
    }

    private nonisolated static func resolvePrimaryPDFURL(from item: [String: Any], baseDirectory: URL) -> URL? {
        if let attachments = item["attachments"] as? [[String: Any]] {
            for attachment in attachments {
                if let url = resolveAttachmentURL(from: attachment, baseDirectory: baseDirectory) {
                    return url
                }
            }
        }

        return resolveAttachmentURL(from: item, baseDirectory: baseDirectory)
    }

    private nonisolated static func resolveAttachmentURL(from dictionary: [String: Any], baseDirectory: URL) -> URL? {
        let candidates = [
            stringValue(dictionary["localPath"]),
            stringValue(dictionary["path"]),
            stringValue(dictionary["filename"]),
            stringValue(dictionary["url"])
        ]

        for candidate in candidates {
            guard !candidate.isEmpty else { continue }

            if let resolved = resolvePath(candidate, baseDirectory: baseDirectory),
               resolved.pathExtension.lowercased() == "pdf" {
                return resolved
            }
        }

        return nil
    }

    private nonisolated static func resolvePath(_ rawValue: String, baseDirectory: URL) -> URL? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.hasPrefix("file://"), let url = URL(string: value) {
            return url
        }

        if value.hasPrefix("/") {
            return URL(fileURLWithPath: value)
        }

        if value.hasPrefix("storage:") {
            let relative = value.replacingOccurrences(of: "storage:", with: "")
            let storageURL = baseDirectory.appendingPathComponent("storage", isDirectory: true).appendingPathComponent(relative)
            return storageURL
        }

        return baseDirectory.appendingPathComponent(value)
    }

    private nonisolated static func makeZoteroCollectionMap(from rawCollections: Any?) -> [String: ZoteroCollectionNode] {
        var map: [String: ZoteroCollectionNode] = [:]

        if let dictionary = rawCollections as? [String: Any] {
            for (key, value) in dictionary {
                guard let item = value as? [String: Any] else { continue }
                let itemKey = stringValue(item["key"]).isEmpty ? key : stringValue(item["key"])
                map[itemKey] = ZoteroCollectionNode(
                    key: itemKey,
                    name: stringValue(item["name"]),
                    parentKey: stringValue(item["parentCollection"])
                )
            }
        } else if let array = rawCollections as? [[String: Any]] {
            for item in array {
                let key = stringValue(item["key"])
                guard !key.isEmpty else { continue }
                map[key] = ZoteroCollectionNode(
                    key: key,
                    name: stringValue(item["name"]),
                    parentKey: stringValue(item["parentCollection"])
                )
            }
        }

        return map
    }

    private nonisolated static func resolveCollectionPaths(from rawCollections: Any?, collectionMap: [String: ZoteroCollectionNode]) -> [String] {
        let keys: [String]
        if let values = rawCollections as? [String] {
            keys = values
        } else if let values = rawCollections as? [Any] {
            keys = values.compactMap {
                if let key = $0 as? String {
                    return key
                }
                if let dict = $0 as? [String: Any] {
                    return stringValue(dict["name"]).isEmpty ? stringValue(dict["key"]) : stringValue(dict["name"])
                }
                return nil
            }
        } else {
            keys = []
        }

        var paths: [String] = []
        for key in keys {
            if let node = collectionMap[key] {
                let path = buildCollectionPath(for: node, collectionMap: collectionMap, visited: [])
                if !path.isEmpty {
                    paths.append(path)
                }
            } else if !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                paths.append(key)
            }
        }

        return uniqueStrings(paths)
    }

    private nonisolated static func buildCollectionPath(
        for node: ZoteroCollectionNode,
        collectionMap: [String: ZoteroCollectionNode],
        visited: Set<String>
    ) -> String {
        guard !visited.contains(node.key) else { return node.name }

        let nextVisited = visited.union([node.key])
        let trimmedName = node.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return "" }

        if let parent = collectionMap[node.parentKey], !node.parentKey.isEmpty {
            let parentPath = buildCollectionPath(for: parent, collectionMap: collectionMap, visited: nextVisited)
            return parentPath.isEmpty ? trimmedName : "\(parentPath)/\(trimmedName)"
        }

        return trimmedName
    }

    private nonisolated static func stripHTML(from text: String) -> String {
        text
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func extractYear(from text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"\b((?:19|20)\d{2})\b"#) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return Int(text[valueRange])
    }

    private nonisolated static func stringValue(_ raw: Any?) -> String {
        if let string = raw as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let number = raw as? NSNumber {
            return number.stringValue
        }
        return ""
    }

    private nonisolated static func firstNonEmpty(_ values: [String]) -> String {
        values.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
    }

    private nonisolated static func fileSize(for url: URL?) -> Int64 {
        guard let url else { return 0 }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private nonisolated static func parseLinkedZoteroRecords(from rootURL: URL) throws -> [ImportedPaperRecord] {
        let databaseURL = rootURL.appendingPathComponent("zotero.sqlite")
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw LibraryImportError.invalidZoteroLibrary
        }

        let snapshot = try createZoteroDatabaseSnapshot(from: rootURL)
        defer { snapshot.cleanup() }

        let connection = try SQLiteConnection(url: snapshot.databaseURL)
        defer { connection.close() }

        let itemTypes = try connection.queryRows("""
            SELECT items.itemID, items.key, itemTypes.typeName
            FROM items
            JOIN itemTypes ON itemTypes.itemTypeID = items.itemTypeID
            LEFT JOIN itemAttachments ON itemAttachments.itemID = items.itemID
            WHERE itemTypes.typeName NOT IN ('note', 'annotation')
              AND (itemTypes.typeName != 'attachment' OR itemAttachments.parentItemID IS NULL)
        """)

        let fieldRows = try connection.queryRows("""
            SELECT itemData.itemID, fields.fieldName, itemDataValues.value
            FROM itemData
            JOIN fields ON fields.fieldID = itemData.fieldID
            JOIN itemDataValues ON itemDataValues.valueID = itemData.valueID
            WHERE itemData.itemID IN (
                SELECT items.itemID
                FROM items
                JOIN itemTypes ON itemTypes.itemTypeID = items.itemTypeID
                WHERE itemTypes.typeName NOT IN ('note', 'annotation')
                  AND (itemTypes.typeName != 'attachment' OR (
                        SELECT parentItemID
                        FROM itemAttachments
                        WHERE itemAttachments.itemID = items.itemID
                        LIMIT 1
                  ) IS NULL)
            )
        """)

        let creatorRows = try fetchZoteroCreatorRows(using: connection)

        let attachmentRows = try connection.queryRows("""
            SELECT itemAttachments.itemID AS attachmentItemID, itemAttachments.parentItemID, itemAttachments.path, itemAttachments.contentType, items.key AS attachmentKey
            FROM itemAttachments
            JOIN items ON items.itemID = itemAttachments.itemID
        """)

        let deletedRows = try connection.queryRowsIfPossible("""
            SELECT itemID
            FROM deletedItems
        """)

        let publicationRows = try connection.queryRowsIfPossible("""
            SELECT itemID
            FROM publicationsItems
        """)

        let noteRows = try connection.queryRows("""
            SELECT parentItemID, note
            FROM itemNotes
            WHERE parentItemID IS NOT NULL
        """)

        let tagRows = try connection.queryRows("""
            SELECT itemTags.itemID, tags.name
            FROM itemTags
            JOIN tags ON tags.tagID = itemTags.tagID
        """)

        let collectionRows = try connection.queryRows("""
            SELECT collections.collectionID, collections.collectionName, collections.parentCollectionID, collectionItems.itemID
            FROM collectionItems
            JOIN collections ON collections.collectionID = collectionItems.collectionID
        """)

        var fieldsByItemID: [Int64: [String: String]] = [:]
        for row in fieldRows {
            let itemID = row.int64("itemID")
            let fieldName = row.string("fieldName")
            let value = row.string("value")
            guard !fieldName.isEmpty, !value.isEmpty else { continue }
            fieldsByItemID[itemID, default: [:]][fieldName] = value
        }

        var creatorsByItemID: [Int64: [ZoteroCreatorRow]] = [:]
        for row in creatorRows {
            let itemID = row.int64("itemID")
            creatorsByItemID[itemID, default: []].append(
                ZoteroCreatorRow(
                    creatorType: row.string("creatorType"),
                    firstName: row.string("firstName"),
                    lastName: row.string("lastName"),
                    fieldMode: row.int64("fieldMode")
                )
            )
        }

        var attachmentPathByParentItemID: [Int64: URL] = [:]
        var standaloneAttachmentPathByItemID: [Int64: URL] = [:]
        for row in attachmentRows {
            let attachmentItemID = row.int64("attachmentItemID")
            let parentItemID = row.int64("parentItemID")
            let path = row.string("path")
            let contentType = row.string("contentType")
            let attachmentKey = row.string("attachmentKey")

            if !contentType.isEmpty && contentType != "application/pdf" {
                continue
            }

            guard let resolvedURL = resolveLinkedZoteroAttachment(
                path: path,
                attachmentKey: attachmentKey,
                rootURL: rootURL
            ) else {
                continue
            }

            if parentItemID > 0 {
                attachmentPathByParentItemID[parentItemID] = resolvedURL
            } else {
                standaloneAttachmentPathByItemID[attachmentItemID] = resolvedURL
            }
        }

        var notesByItemID: [Int64: [String]] = [:]
        for row in noteRows {
            let parentItemID = row.int64("parentItemID")
            let note = stripHTML(from: row.string("note"))
            guard !note.isEmpty else { continue }
            notesByItemID[parentItemID, default: []].append(note)
        }

        var tagsByItemID: [Int64: [String]] = [:]
        for row in tagRows {
            let itemID = row.int64("itemID")
            let name = row.string("name")
            guard !name.isEmpty else { continue }
            tagsByItemID[itemID, default: []].append(name)
        }

        var collectionNameByID: [Int64: String] = [:]
        var collectionParentByID: [Int64: Int64] = [:]
        var collectionIDsByItemID: [Int64: [Int64]] = [:]
        for row in collectionRows {
            let collectionID = row.int64("collectionID")
            collectionNameByID[collectionID] = row.string("collectionName")
            collectionParentByID[collectionID] = row.int64("parentCollectionID")
            collectionIDsByItemID[row.int64("itemID"), default: []].append(collectionID)
        }

        let deletedItemIDs = Set(deletedRows.map { $0.int64("itemID") })
        let publicationItemIDs = Set(publicationRows.map { $0.int64("itemID") })

        let libraryName = rootURL.lastPathComponent
        let records = itemTypes.compactMap { row -> ImportedPaperRecord? in
            let itemID = row.int64("itemID")
            let itemKey = row.string("key")
            let itemType = row.string("typeName")
            let fields = fieldsByItemID[itemID] ?? [:]
            let creators = creatorsByItemID[itemID] ?? []
            let authors = formatCreators(creators, types: ["author"])
            let editors = formatCreators(creators, types: ["editor", "seriesEditor"])
            let contributors = formatCreators(creators, types: ["contributor"])
            let isInTrash = deletedItemIDs.contains(itemID)
            let collectionPaths = uniqueStrings((collectionIDsByItemID[itemID] ?? []).compactMap { collectionID in
                buildZoteroCollectionPath(
                    collectionID: collectionID,
                    names: collectionNameByID,
                    parents: collectionParentByID
                )
            })
            let isUnfiled = collectionPaths.isEmpty && !isInTrash
            let attachmentURL = itemType.lowercased() == "attachment"
                ? standaloneAttachmentPathByItemID[itemID]
                : attachmentPathByParentItemID[itemID]

            if itemType.lowercased() == "attachment" {
                return makeStandaloneAttachmentRecord(
                    sourceLibraryType: "zotero",
                    sourceLibraryName: libraryName,
                    sourceRecordID: itemKey,
                    importMethod: "zoteroLinked",
                    databaseSource: "Zotero Local",
                    attachmentURL: attachmentURL,
                    title: fields["title"] ?? "",
                    language: fields["language"] ?? "",
                    dateText: fields["date"] ?? "",
                    notes: (notesByItemID[itemID] ?? []).joined(separator: "\n\n"),
                    extra: fields["extra"] ?? "",
                    rights: fields["rights"] ?? "",
                    tagsText: uniqueStrings(tagsByItemID[itemID] ?? []).joined(separator: "; "),
                    collectionPaths: collectionPaths,
                    isInTrash: isInTrash,
                    isUnfiled: isUnfiled,
                    isPublicationItem: publicationItemIDs.contains(itemID)
                )
            }

            return ImportedPaperRecord(
                sourceLibraryType: "zotero",
                sourceLibraryName: libraryName,
                sourceRecordID: itemKey,
                importMethod: "zoteroLinked",
                databaseSource: "Zotero Local",
                itemType: itemType.isEmpty ? "journalArticle" : itemType,
                citationKey: fields["citationKey"] ?? "",
                title: fields["title"] ?? "",
                subtitle: fields["shortTitle"] ?? "",
                authors: authors,
                editors: editors,
                corporateAuthors: contributors,
                journal: firstNonEmpty([
                    fields["publicationTitle"] ?? "",
                    fields["websiteTitle"] ?? "",
                    fields["proceedingsTitle"] ?? ""
                ]),
                journalAbbreviation: fields["journalAbbreviation"] ?? "",
                conferenceName: fields["conferenceName"] ?? "",
                bookTitle: firstNonEmpty([fields["bookTitle"] ?? "", fields["proceedingsTitle"] ?? ""]),
                publisher: fields["publisher"] ?? "",
                publicationPlace: fields["place"] ?? "",
                volume: fields["volume"] ?? "",
                issue: fields["issue"] ?? "",
                pages: fields["pages"] ?? "",
                articleNumber: fields["articleNumber"] ?? "",
                edition: fields["edition"] ?? "",
                chapter: firstNonEmpty([fields["chapter"] ?? "", fields["section"] ?? ""]),
                series: fields["series"] ?? "",
                seriesTitle: fields["seriesTitle"] ?? "",
                seriesText: fields["seriesText"] ?? "",
                year: extractYear(from: fields["date"] ?? ""),
                dateText: fields["date"] ?? "",
                doi: firstNonEmpty([fields["DOI"] ?? "", fields["doi"] ?? ""]),
                url: fields["url"] ?? "",
                issn: fields["ISSN"] ?? "",
                isbn: fields["ISBN"] ?? "",
                pmid: fields["PMID"] ?? "",
                pmcid: fields["PMCID"] ?? "",
                accessionNumber: fields["accessionNumber"] ?? "",
                archive: fields["archive"] ?? "",
                archiveLocation: fields["archiveLocation"] ?? "",
                libraryCatalog: fields["libraryCatalog"] ?? "",
                callNumber: fields["callNumber"] ?? "",
                abstractText: fields["abstractNote"] ?? "",
                notes: (notesByItemID[itemID] ?? []).joined(separator: "\n\n"),
                extra: fields["extra"] ?? "",
                language: fields["language"] ?? "",
                rights: fields["rights"] ?? "",
                tagsText: uniqueStrings(tagsByItemID[itemID] ?? []).joined(separator: "; "),
                collectionPaths: collectionPaths,
                priority: "medium",
                attachmentURL: attachmentURL,
                sourceAttachmentPath: attachmentURL?.path ?? "",
                fileType: attachmentURL?.pathExtension.lowercased().isEmpty == false ? attachmentURL?.pathExtension.lowercased() ?? "pdf" : "pdf",
                fileSize: fileSize(for: attachmentURL),
                hasPDF: attachmentURL != nil,
                isInTrash: isInTrash,
                isUnfiled: isUnfiled,
                isPublicationItem: publicationItemIDs.contains(itemID)
            )
        }

        guard !records.isEmpty else {
            throw LibraryImportError.noSupportedRecords
        }

        return records
    }

    private nonisolated static func createZoteroDatabaseSnapshot(from rootURL: URL) throws -> ZoteroDatabaseSnapshot {
        let fileManager = FileManager.default
        let sourceDatabaseURL = rootURL.appendingPathComponent("zotero.sqlite")
        let snapshotDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("PaperFocus-Zotero-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: snapshotDirectoryURL, withIntermediateDirectories: true)
            let snapshotDatabaseURL = snapshotDirectoryURL.appendingPathComponent("zotero.sqlite")
            try backupSQLiteDatabase(from: sourceDatabaseURL, to: snapshotDatabaseURL)
            return ZoteroDatabaseSnapshot(
                directoryURL: snapshotDirectoryURL,
                databaseURL: snapshotDatabaseURL
            )
        } catch let error as LibraryImportError {
            try? fileManager.removeItem(at: snapshotDirectoryURL)
            throw error
        } catch {
            try? fileManager.removeItem(at: snapshotDirectoryURL)
            throw LibraryImportError.zoteroSnapshotFailed(error.localizedDescription)
        }
    }

    private nonisolated static func backupSQLiteDatabase(from sourceURL: URL, to destinationURL: URL) throws {
        var sourcePointer: OpaquePointer?
        var destinationPointer: OpaquePointer?
        guard sqlite3_open_v2(sourceURL.path, &sourcePointer, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let message = sourcePointer.map { String(cString: sqlite3_errmsg($0)) } ?? "无法打开源数据库"
            if let sourcePointer {
                sqlite3_close(sourcePointer)
            }
            throw LibraryImportError.zoteroSnapshotFailed(message)
        }
        guard let source = sourcePointer else {
            throw LibraryImportError.zoteroSnapshotFailed("无法打开源数据库")
        }
        defer { sqlite3_close(source) }

        let destinationFlags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        guard sqlite3_open_v2(destinationURL.path, &destinationPointer, destinationFlags, nil) == SQLITE_OK else {
            let message = destinationPointer.map { String(cString: sqlite3_errmsg($0)) } ?? "无法创建快照数据库"
            if let destinationPointer {
                sqlite3_close(destinationPointer)
            }
            throw LibraryImportError.zoteroSnapshotFailed(message)
        }
        guard let destination = destinationPointer else {
            throw LibraryImportError.zoteroSnapshotFailed("无法创建快照数据库")
        }
        defer { sqlite3_close(destination) }

        guard let backup = sqlite3_backup_init(destination, "main", source, "main") else {
            throw LibraryImportError.zoteroSnapshotFailed(String(cString: sqlite3_errmsg(destination)))
        }

        var stepResult: Int32 = SQLITE_OK
        var busyAttempts = 0
        repeat {
            stepResult = sqlite3_backup_step(backup, 128)
            if stepResult == SQLITE_BUSY || stepResult == SQLITE_LOCKED {
                sqlite3_sleep(25)
                busyAttempts += 1
            } else {
                break
            }
        } while busyAttempts < 40

        let finishResult = sqlite3_backup_finish(backup)
        guard stepResult == SQLITE_DONE, finishResult == SQLITE_OK else {
            throw LibraryImportError.zoteroSnapshotFailed(String(cString: sqlite3_errmsg(destination)))
        }
    }

    private nonisolated static func fetchZoteroCreatorRows(using connection: SQLiteConnection) throws -> [SQLiteRow] {
        let creatorTypeColumn = try zoteroCreatorTypeColumn(using: connection)

        if connection.tableExists("creatorData") {
            return try connection.queryRows("""
                SELECT itemCreators.itemID, creatorTypes.\(creatorTypeColumn) AS creatorType, creatorData.firstName, creatorData.lastName, creatorData.fieldMode
                FROM itemCreators
                JOIN creators ON creators.creatorID = itemCreators.creatorID
                JOIN creatorData ON creatorData.creatorDataID = creators.creatorDataID
                JOIN creatorTypes ON creatorTypes.creatorTypeID = itemCreators.creatorTypeID
                ORDER BY itemCreators.itemID, itemCreators.orderIndex
            """)
        }

        let creatorColumns = connection.columnNames(in: "creators")
        guard !creatorColumns.isEmpty else { return [] }

        let firstNameExpression = creatorColumns.contains("firstName")
            ? "creators.firstName"
            : "''"
        let lastNameExpression: String
        let fieldModeExpression: String

        if creatorColumns.contains("lastName") {
            lastNameExpression = "creators.lastName"
            fieldModeExpression = creatorColumns.contains("fieldMode") ? "creators.fieldMode" : "0"
        } else if creatorColumns.contains("name") {
            lastNameExpression = "creators.name"
            fieldModeExpression = "1"
        } else {
            return []
        }

        return try connection.queryRows("""
            SELECT itemCreators.itemID, creatorTypes.\(creatorTypeColumn) AS creatorType, \(firstNameExpression) AS firstName, \(lastNameExpression) AS lastName, \(fieldModeExpression) AS fieldMode
            FROM itemCreators
            JOIN creators ON creators.creatorID = itemCreators.creatorID
            JOIN creatorTypes ON creatorTypes.creatorTypeID = itemCreators.creatorTypeID
            ORDER BY itemCreators.itemID, itemCreators.orderIndex
        """)
    }

    private nonisolated static func zoteroCreatorTypeColumn(using connection: SQLiteConnection) throws -> String {
        let columns = connection.columnNames(in: "creatorTypes")
        if columns.contains("creatorType") {
            return "creatorType"
        }
        if columns.contains("typeName") {
            return "typeName"
        }
        throw LibraryImportError.zoteroQueryFailed("creatorTypes 表缺少 creatorType/typeName 列")
    }

    private func storedLinkedZoteroRootURL() throws -> URL {
        if let storedPath = SecurityScopedBookmarkStore.shared.associatedRootPath(for: .zoteroLocal) {
            let storedURL = URL(fileURLWithPath: storedPath)
            if FileManager.default.fileExists(atPath: storedURL.appendingPathComponent("zotero.sqlite").path) {
                return storedURL
            }
        }

        if let accessURL = SecurityScopedBookmarkStore.shared.resolveURL(for: .zoteroLocal) {
            return try Self.resolveZoteroLibraryRoot(from: accessURL)
        }

        throw LibraryImportError.invalidZoteroLibrary
    }

    private nonisolated static func resolveLinkedZoteroAttachment(path: String, attachmentKey: String, rootURL: URL) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("storage:") {
            let relativePath = trimmed.replacingOccurrences(of: "storage:", with: "")
            let normalizedRelativePath = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let storageRootURL = rootURL.appendingPathComponent("storage", isDirectory: true)

            if normalizedRelativePath.contains("/") {
                return storageRootURL.appendingPathComponent(normalizedRelativePath)
            }

            let normalizedAttachmentKey = attachmentKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedAttachmentKey.isEmpty {
                return storageRootURL
                    .appendingPathComponent(normalizedAttachmentKey, isDirectory: true)
                    .appendingPathComponent(normalizedRelativePath)
            }

            return storageRootURL.appendingPathComponent(normalizedRelativePath)
        }

        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed)
        }

        if trimmed.hasPrefix("attachments:") {
            let relativePath = trimmed.replacingOccurrences(of: "attachments:", with: "")
            return rootURL.appendingPathComponent(relativePath)
        }

        return rootURL.appendingPathComponent(trimmed)
    }

    private nonisolated static func buildZoteroCollectionPath(
        collectionID: Int64,
        names: [Int64: String],
        parents: [Int64: Int64]
    ) -> String {
        var visited: Set<Int64> = []
        var currentID: Int64? = collectionID
        var components: [String] = []

        while let id = currentID, !visited.contains(id) {
            visited.insert(id)
            if let name = names[id], !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                components.insert(name, at: 0)
            }
            let parentID = parents[id] ?? 0
            currentID = parentID == 0 ? nil : parentID
        }

        return components.joined(separator: "/")
    }

    private nonisolated static func formatCreators(_ creators: [ZoteroCreatorRow], types: Set<String>) -> String {
        creators.compactMap { creator in
            guard types.contains(creator.creatorType) else { return nil }
            if creator.fieldMode == 1 {
                return creator.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let fullName = "\(creator.firstName) \(creator.lastName)"
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return fullName.isEmpty ? nil : fullName
        }
        .joined(separator: ", ")
    }

    private nonisolated static func uniqueStrings(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }

        return result
    }
}

nonisolated private struct ImportedPaperRecord: Sendable {
    let sourceLibraryType: String
    let sourceLibraryName: String
    let sourceRecordID: String
    let importMethod: String
    let databaseSource: String
    let itemType: String
    let citationKey: String
    let title: String
    let subtitle: String
    let authors: String
    let editors: String
    let corporateAuthors: String
    let journal: String
    let journalAbbreviation: String
    let conferenceName: String
    let bookTitle: String
    let publisher: String
    let publicationPlace: String
    let volume: String
    let issue: String
    let pages: String
    let articleNumber: String
    let edition: String
    let chapter: String
    let series: String
    let seriesTitle: String
    let seriesText: String
    let year: Int?
    let dateText: String
    let doi: String
    let url: String
    let issn: String
    let isbn: String
    let pmid: String
    let pmcid: String
    let accessionNumber: String
    let archive: String
    let archiveLocation: String
    let libraryCatalog: String
    let callNumber: String
    let abstractText: String
    let notes: String
    let extra: String
    let language: String
    let rights: String
    let tagsText: String
    let collectionPaths: [String]
    let priority: String
    var attachmentURL: URL?
    let sourceAttachmentPath: String
    let fileType: String
    var fileSize: Int64
    var hasPDF: Bool
    let isInTrash: Bool
    let isUnfiled: Bool
    let isPublicationItem: Bool

    var hasMeaningfulContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !doi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || attachmentURL != nil
    }
}

nonisolated private struct PreparedAttachment {
    let path: String
    let fileName: String
    let fileType: String
    let fileSize: Int64
}

nonisolated private struct ZoteroCollectionNode {
    let key: String
    let name: String
    let parentKey: String
}

nonisolated private struct ZoteroCreatorRow {
    let creatorType: String
    let firstName: String
    let lastName: String
    let fieldMode: Int64
}

nonisolated private final class EndNoteXMLImportParser: NSObject, XMLParserDelegate {
    private let sourceURL: URL
    private let importMethod: String
    private var records: [ImportedPaperRecord] = []
    private var currentRecord: EndNoteWorkingRecord?
    private var currentText = ""
    private var elementStack: [String] = []

    init(sourceURL: URL, importMethod: String = "endnote") {
        self.sourceURL = sourceURL
        self.importMethod = importMethod
    }

    func parse(data: Data) throws -> [ImportedPaperRecord] {
        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            throw parser.parserError ?? LibraryImportError.invalidEndNoteFile
        }

        guard !records.isEmpty else {
            throw LibraryImportError.noSupportedRecords
        }

        return records
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        elementStack.append(elementName)
        currentText = ""

        if elementName == "record" {
            currentRecord = EndNoteWorkingRecord()
            currentRecord?.refTypeName = attributeDict["name"] ?? ""
        }

        if elementName == "ref-type", let name = attributeDict["name"] {
            currentRecord?.refTypeName = name
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = elementStack.joined(separator: "/")

        if var record = currentRecord, !value.isEmpty {
            if path.hasSuffix("record/rec-number") {
                record.sourceRecordID = value
            } else if path.hasSuffix("record/titles/title") {
                record.title = value
            } else if path.hasSuffix("record/titles/secondary-title")
                || path.hasSuffix("record/periodical/full-title") {
                if record.journal.isEmpty {
                    record.journal = value
                }
            } else if path.hasSuffix("record/titles/tertiary-title") {
                record.bookTitle = value
            } else if path.hasSuffix("record/contributors/authors/author") {
                record.authors.append(value)
            } else if path.hasSuffix("record/contributors/secondary-authors/author")
                || path.hasSuffix("record/contributors/tertiary-authors/author") {
                record.editors.append(value)
            } else if path.hasSuffix("record/dates/year") {
                record.year = Int(value) ?? record.year
                record.dateText = value
            } else if path.hasSuffix("record/volume") {
                record.volume = value
            } else if path.hasSuffix("record/number") {
                record.issue = value
            } else if path.hasSuffix("record/pages") {
                record.pages = value
            } else if path.hasSuffix("record/abstract") {
                record.abstractText = value
            } else if path.hasSuffix("record/notes") {
                record.notes = value
            } else if path.hasSuffix("record/keywords/keyword") {
                record.tags.append(value)
            } else if path.hasSuffix("record/urls/related-urls/url")
                || path.hasSuffix("record/pdf-urls/url")
                || path.hasSuffix("record/urls/web-urls/url") {
                record.urls.append(value)
            } else if path.hasSuffix("record/electronic-resource-num") {
                if DOIExtractor.extractDOI(fromText: value) != nil {
                    record.doi = DOIExtractor.extractDOI(fromText: value) ?? ""
                } else if record.accessionNumber.isEmpty {
                    record.accessionNumber = value
                }
            } else if path.hasSuffix("record/accession-num") {
                record.accessionNumber = value
            } else if path.hasSuffix("record/database-provider") {
                record.databaseSource = value
            } else if path.hasSuffix("record/language") {
                record.language = value
            } else if path.hasSuffix("record/publisher") {
                record.publisher = value
            } else if path.hasSuffix("record/label")
                || path.hasSuffix("record/group-name")
                || path.hasSuffix("record/folder")
                || path.hasSuffix("record/custom1")
                || path.hasSuffix("record/custom2")
                || path.hasSuffix("record/custom3") {
                record.collectionCandidates.append(value)
            }

            currentRecord = record
        }

        if elementName == "record", let record = currentRecord {
            let attachmentURL = resolveEndNoteAttachmentURL(from: record.urls)
            let fileSize = attachmentURL.flatMap(fileSize(for:))
                ?? 0
            records.append(
                ImportedPaperRecord(
                    sourceLibraryType: "endnote",
                    sourceLibraryName: sourceURL.deletingPathExtension().lastPathComponent,
                    sourceRecordID: record.sourceRecordID,
                    importMethod: importMethod,
                    databaseSource: record.databaseSource.isEmpty ? "EndNote" : record.databaseSource,
                    itemType: mapEndNoteType(record.refTypeName),
                    citationKey: "",
                    title: record.title,
                    subtitle: "",
                    authors: record.authors.joined(separator: ", "),
                    editors: record.editors.joined(separator: ", "),
                    corporateAuthors: "",
                    journal: record.journal,
                    journalAbbreviation: "",
                    conferenceName: "",
                    bookTitle: record.bookTitle,
                    publisher: record.publisher,
                    publicationPlace: "",
                    volume: record.volume,
                    issue: record.issue,
                    pages: record.pages,
                    articleNumber: "",
                    edition: "",
                    chapter: "",
                    series: "",
                    seriesTitle: "",
                    seriesText: "",
                    year: record.year,
                    dateText: record.dateText,
                    doi: record.doi,
                    url: record.urls.first(where: { !$0.lowercased().hasSuffix(".pdf") }) ?? "",
                    issn: "",
                    isbn: "",
                    pmid: "",
                    pmcid: "",
                    accessionNumber: record.accessionNumber,
                    archive: "",
                    archiveLocation: "",
                    libraryCatalog: "",
                    callNumber: "",
                    abstractText: record.abstractText,
                    notes: record.notes,
                    extra: "",
                    language: record.language,
                    rights: "",
                    tagsText: record.tags.joined(separator: "; "),
                    collectionPaths: normalizeCollectionCandidates(record.collectionCandidates),
                    priority: "medium",
                    attachmentURL: attachmentURL,
                    sourceAttachmentPath: attachmentURL?.path ?? "",
                    fileType: attachmentURL?.pathExtension.lowercased().isEmpty == false ? attachmentURL?.pathExtension.lowercased() ?? "pdf" : "pdf",
                    fileSize: fileSize,
                    hasPDF: attachmentURL != nil,
                    isInTrash: false,
                    isUnfiled: normalizeCollectionCandidates(record.collectionCandidates).isEmpty,
                    isPublicationItem: false
                )
            )
            currentRecord = nil
        }

        _ = elementStack.popLast()
        currentText = ""
    }

    private func resolveEndNoteAttachmentURL(from rawURLs: [String]) -> URL? {
        for raw in rawURLs {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("file://"), let url = URL(string: trimmed), url.pathExtension.lowercased() == "pdf" {
                return url
            }

            if trimmed.hasPrefix("/") {
                let url = URL(fileURLWithPath: trimmed)
                if url.pathExtension.lowercased() == "pdf" {
                    return url
                }
            }
        }

        return nil
    }

    private func fileSize(for url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func mapEndNoteType(_ rawValue: String) -> String {
        let normalized = rawValue.lowercased()
        if normalized.contains("journal") {
            return "journalArticle"
        }
        if normalized.contains("conference") {
            return "conferencePaper"
        }
        if normalized.contains("book chapter") {
            return "bookChapter"
        }
        if normalized.contains("book") {
            return "book"
        }
        if normalized.contains("thesis") || normalized.contains("dissertation") {
            return "thesis"
        }
        return normalized.isEmpty ? "journalArticle" : rawValue
    }

    private func normalizeCollectionCandidates(_ values: [String]) -> [String] {
        let normalized = values.compactMap { value -> String? in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let cleaned = trimmed
                .replacingOccurrences(of: ">", with: "/")
                .replacingOccurrences(of: "\\", with: "/")
                .replacingOccurrences(of: #"[/]{2,}"#, with: "/", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return cleaned.isEmpty ? nil : cleaned
        }

        return uniqueStrings(normalized)
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }

        return result
    }
}

nonisolated private struct EndNoteWorkingRecord {
    var sourceRecordID: String = ""
    var refTypeName: String = ""
    var title: String = ""
    var journal: String = ""
    var bookTitle: String = ""
    var authors: [String] = []
    var editors: [String] = []
    var year: Int?
    var dateText: String = ""
    var volume: String = ""
    var issue: String = ""
    var pages: String = ""
    var doi: String = ""
    var accessionNumber: String = ""
    var abstractText: String = ""
    var notes: String = ""
    var urls: [String] = []
    var tags: [String] = []
    var collectionCandidates: [String] = []
    var databaseSource: String = ""
    var language: String = ""
    var publisher: String = ""
}

nonisolated private struct SQLiteRow {
    fileprivate let values: [String: String]

    func string(_ column: String) -> String {
        values[column] ?? ""
    }

    func int64(_ column: String) -> Int64 {
        Int64(values[column] ?? "") ?? 0
    }
}

nonisolated private struct ZoteroDatabaseSnapshot {
    let directoryURL: URL
    let databaseURL: URL

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

nonisolated private final class SQLiteConnection {
    private var database: OpaquePointer?

    init(url: URL) throws {
        if sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "未知错误"
            if let database {
                sqlite3_close(database)
                self.database = nil
            }
            throw LibraryImportError.zoteroDatabaseOpenFailed(message)
        }
    }

    deinit {
        close()
    }

    func close() {
        if let database {
            sqlite3_close(database)
            self.database = nil
        }
    }

    func queryRows(_ sql: String) throws -> [SQLiteRow] {
        guard let database else {
            throw LibraryImportError.invalidZoteroLibrary
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(database))
            sqlite3_finalize(statement)
            throw LibraryImportError.zoteroQueryFailed(message)
        }

        defer {
            sqlite3_finalize(statement)
        }

        var rows: [SQLiteRow] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE {
                break
            }
            guard result == SQLITE_ROW else {
                throw LibraryImportError.zoteroQueryFailed(String(cString: sqlite3_errmsg(database)))
            }

            let columnCount = sqlite3_column_count(statement)
            var values: [String: String] = [:]

            for columnIndex in 0..<columnCount {
                guard let rawName = sqlite3_column_name(statement, columnIndex) else { continue }
                let name = String(cString: rawName)

                if let rawValue = sqlite3_column_text(statement, columnIndex) {
                    values[name] = String(cString: rawValue)
                } else {
                    values[name] = ""
                }
            }

            rows.append(SQLiteRow(values: values))
        }

        return rows
    }

    func queryRowsIfPossible(_ sql: String) throws -> [SQLiteRow] {
        do {
            return try queryRows(sql)
        } catch {
            return []
        }
    }

    func tableExists(_ tableName: String) -> Bool {
        let escaped = tableName.replacingOccurrences(of: "'", with: "''")
        let rows = try? queryRows("""
            SELECT name
            FROM sqlite_master
            WHERE type = 'table' AND name = '\(escaped)'
            LIMIT 1
        """)
        return !(rows?.isEmpty ?? true)
    }

    func columnNames(in tableName: String) -> Set<String> {
        let rows = (try? queryRows("PRAGMA table_info(\(tableName))")) ?? []
        return Set(rows.map { $0.string("name") }.filter { !$0.isEmpty })
    }
}
