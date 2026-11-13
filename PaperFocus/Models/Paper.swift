//
//  Paper.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import Foundation
import SwiftData

@Model
final class Paper {
    
    // MARK: - Core Identity
    
    /// 内部唯一标识辅助字段（可用于未来同步、导出）
    var uuid: String
    
    /// 引用关键词，例如 zengLargeLanguageModelaugmented2026
    var citationKey: String
    
    /// 条目类型，例如 journalArticle / conferencePaper / book / thesis
    var itemType: String
    
    // MARK: - Title & Author
    
    /// 主标题
    var title: String
    
    /// 副标题
    var subtitle: String
    
    /// 作者原始文本，先用字符串，后续再拆 Author 实体
    var authors: String
    
    /// 编辑者
    var editors: String
    
    /// 机构作者或团体作者
    var corporateAuthors: String
    
    // MARK: - Publication Info
    
    /// 期刊名 / 出版物名称
    var journal: String
    
    /// 期刊简称
    var journalAbbreviation: String
    
    /// 会议名称
    var conferenceName: String
    
    /// 书名
    var bookTitle: String
    
    /// 出版社
    var publisher: String
    
    /// 出版地点
    var publicationPlace: String
    
    /// 卷
    var volume: String
    
    /// 期
    var issue: String
    
    /// 页码，例如 123-135
    var pages: String
    
    /// 文章编号，例如 123628
    var articleNumber: String
    
    /// 版次
    var edition: String
    
    /// 章节
    var chapter: String
    
    /// 系列
    var series: String
    
    /// 系列标题
    var seriesTitle: String
    
    /// 系列描述
    var seriesText: String
    
    // MARK: - Date Info
    
    /// 年份，便于列表排序和筛选
    var year: Int?
    
    /// 原始日期字符串，例如 02/2026 或 2026-02-15
    var dateText: String
    
    /// 访问日期
    var accessDate: Date?
    
    // MARK: - Identifiers
    
    /// DOI
    var doi: String
    
    /// URL
    var url: String
    
    /// ISSN
    var issn: String
    
    /// ISBN
    var isbn: String
    
    /// PMID
    var pmid: String
    
    /// PMCID
    var pmcid: String
    
    /// 文献数据库中的 accession number / 索书号等
    var accessionNumber: String
    
    /// archive / repository
    var archive: String
    
    /// archive location / 存档位置
    var archiveLocation: String
    
    /// library catalog / 文库编目
    var libraryCatalog: String
    
    /// call number / 索书号
    var callNumber: String
    
    // MARK: - Content
    
    /// 摘要
    var abstractText: String
    
    /// 备注
    var notes: String
    
    /// 目录 / 额外内容说明
    var extra: String
    
    /// 语言
    var language: String
    
    /// 版权说明
    var rights: String
    
    // MARK: - File & Attachment
    
    /// PDF 本地路径
    var pdfPath: String
    
    /// 原始导入文件名
    var pdfFileName: String
    
    /// 文件类型，例如 pdf
    var fileType: String
    
    /// 文件大小（字节）
    var fileSize: Int64
    
    /// 是否已有本地 PDF
    var hasPDF: Bool
    
    // MARK: - Reading / Workflow
    
    /// 阅读状态：unread / reading / finished / archived
    var statusRaw: String
    
    /// 是否收藏
    var isFavorite: Bool
    
    /// 是否置顶
    var isPinned: Bool
    
    /// 是否已读完初稿
    var isRead: Bool
    
    /// 是否已做笔记
    var hasNotes: Bool
    
    /// 是否可作为候选引用
    var isRelevant: Bool
    
    /// 最近打开时间
    var lastOpenedAt: Date?
    
    /// 阅读进度（0~1）
    var readingProgress: Double
    
    /// PDF 最近阅读页码
    var lastReadPage: Int
    
    // MARK: - Classification
    
    /// 标签原始文本，先用分号或逗号分隔，后续再拆独立 Tag 实体
    var tagsText: String
    
    /// 文件夹/分组
    var collection: String

    /// 主文件夹层级路径，例如 社会科学/信息管理/知识组织
    var collectionPath: String

    /// 多个文件夹路径，使用分号分隔
    var collectionsText: String
    
    /// 优先级，例如 low / medium / high
    var priority: String
    
    // MARK: - Import Source
    
    /// 元数据来源，例如 Crossref / DOI.org / Manual / PubMed
    var databaseSource: String
    
    /// 导入方式，例如 doi / pdf / manual / drag
    var importMethod: String
    
    /// 原始来源记录 ID
    var sourceRecordID: String

    /// 外部文献库类型，例如 zotero / endnote / folderImport
    var sourceLibraryType: String

    /// 外部文献库名称，例如 我的 Zotero 库
    var sourceLibraryName: String

    /// 外部附件原始路径
    var sourceAttachmentPath: String

    /// 是否位于外部文献库回收站
    var isInTrash: Bool

    /// 是否为未分类条目
    var isUnfiled: Bool

    /// 是否属于我的出版物
    var isPublicationItem: Bool
    
    // MARK: - Timestamps
    
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .cascade)
    var focusTasks: [FocusTask] = []
    
    // MARK: - Init
    
    init(
        uuid: String = UUID().uuidString,
        citationKey: String = "",
        itemType: String = "journalArticle",
        
        title: String = "",
        subtitle: String = "",
        authors: String = "",
        editors: String = "",
        corporateAuthors: String = "",
        
        journal: String = "",
        journalAbbreviation: String = "",
        conferenceName: String = "",
        bookTitle: String = "",
        publisher: String = "",
        publicationPlace: String = "",
        volume: String = "",
        issue: String = "",
        pages: String = "",
        articleNumber: String = "",
        edition: String = "",
        chapter: String = "",
        series: String = "",
        seriesTitle: String = "",
        seriesText: String = "",
        
        year: Int? = nil,
        dateText: String = "",
        accessDate: Date? = nil,
        
        doi: String = "",
        url: String = "",
        issn: String = "",
        isbn: String = "",
        pmid: String = "",
        pmcid: String = "",
        accessionNumber: String = "",
        archive: String = "",
        archiveLocation: String = "",
        libraryCatalog: String = "",
        callNumber: String = "",
        
        abstractText: String = "",
        notes: String = "",
        extra: String = "",
        language: String = "",
        rights: String = "",
        
        pdfPath: String = "",
        pdfFileName: String = "",
        fileType: String = "pdf",
        fileSize: Int64 = 0,
        hasPDF: Bool = false,
        
        statusRaw: String = "unread",
        isFavorite: Bool = false,
        isPinned: Bool = false,
        isRead: Bool = false,
        hasNotes: Bool = false,
        isRelevant: Bool = false,
        lastOpenedAt: Date? = nil,
        readingProgress: Double = 0.0,
        lastReadPage: Int = 1,
        
        tagsText: String = "",
        collection: String = "",
        collectionPath: String = "",
        collectionsText: String = "",
        priority: String = "medium",
        
        databaseSource: String = "",
        importMethod: String = "",
        sourceRecordID: String = "",
        sourceLibraryType: String = "",
        sourceLibraryName: String = "",
        sourceAttachmentPath: String = "",
        isInTrash: Bool = false,
        isUnfiled: Bool = false,
        isPublicationItem: Bool = false,
        
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.uuid = uuid
        self.citationKey = citationKey
        self.itemType = itemType
        
        self.title = title
        self.subtitle = subtitle
        self.authors = authors
        self.editors = editors
        self.corporateAuthors = corporateAuthors
        
        self.journal = journal
        self.journalAbbreviation = journalAbbreviation
        self.conferenceName = conferenceName
        self.bookTitle = bookTitle
        self.publisher = publisher
        self.publicationPlace = publicationPlace
        self.volume = volume
        self.issue = issue
        self.pages = pages
        self.articleNumber = articleNumber
        self.edition = edition
        self.chapter = chapter
        self.series = series
        self.seriesTitle = seriesTitle
        self.seriesText = seriesText
        
        self.year = year
        self.dateText = dateText
        self.accessDate = accessDate
        
        self.doi = doi
        self.url = url
        self.issn = issn
        self.isbn = isbn
        self.pmid = pmid
        self.pmcid = pmcid
        self.accessionNumber = accessionNumber
        self.archive = archive
        self.archiveLocation = archiveLocation
        self.libraryCatalog = libraryCatalog
        self.callNumber = callNumber
        
        self.abstractText = abstractText
        self.notes = notes
        self.extra = extra
        self.language = language
        self.rights = rights
        
        self.pdfPath = pdfPath
        self.pdfFileName = pdfFileName
        self.fileType = fileType
        self.fileSize = fileSize
        self.hasPDF = hasPDF
        
        self.statusRaw = statusRaw
        self.isFavorite = isFavorite
        self.isPinned = isPinned
        self.isRead = isRead
        self.hasNotes = hasNotes
        self.isRelevant = isRelevant
        self.lastOpenedAt = lastOpenedAt
        self.readingProgress = readingProgress
        self.lastReadPage = lastReadPage
        
        self.tagsText = tagsText
        self.collection = collection
        self.collectionPath = collectionPath
        self.collectionsText = collectionsText
        self.priority = priority
        
        self.databaseSource = databaseSource
        self.importMethod = importMethod
        self.sourceRecordID = sourceRecordID
        self.sourceLibraryType = sourceLibraryType
        self.sourceLibraryName = sourceLibraryName
        self.sourceAttachmentPath = sourceAttachmentPath
        self.isInTrash = isInTrash
        self.isUnfiled = isUnfiled
        self.isPublicationItem = isPublicationItem
        
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Paper {
    
    var status: PaperStatus {
        get { PaperStatus(rawValue: statusRaw) ?? .unread }
        set {
            statusRaw = newValue.rawValue
            updatedAt = .now
        }
    }
    
    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名文献" : title
    }
    
    var displayAuthors: String {
        authors.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : authors
    }
    
    var displayJournal: String {
        journal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : journal
    }
    
    var displayYear: String {
        if let year {
            return String(year)
        }
        return "—"
    }
    
    var displayDOI: String {
        doi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : doi
    }
    
    var pdfURL: URL? {
        guard !pdfPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return URL(fileURLWithPath: pdfPath)
    }
    
    var tagList: [String] {
        tagsText
            .split(whereSeparator: { $0 == ";" || $0 == "," || $0 == "，" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var collectionList: [String] {
        collectionsText
            .split(whereSeparator: { $0 == ";" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var displayCollectionPath: String {
        let normalizedPath = collectionPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedPath.isEmpty {
            return normalizedPath
        }

        let normalizedCollection = collection.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedCollection.isEmpty ? "—" : normalizedCollection
    }
    
    func touch() {
        updatedAt = .now
    }
}
