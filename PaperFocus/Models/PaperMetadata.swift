//
//  PaperMetadata.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import Foundation

nonisolated struct PaperMetadata: Identifiable, Equatable, Sendable {
    let id = UUID()

    var title: String
    var authors: String
    var year: Int?
    var journal: String
    var doi: String
    var source: String

    // MARK: - Extended Metadata

    var publisher: String
    var volume: String
    var issue: String
    var pages: String
    var url: String
    var abstractText: String
    var language: String
    var itemType: String
    var dateText: String
    var extra: String

    init(
        title: String = "",
        authors: String = "",
        year: Int? = nil,
        journal: String = "",
        doi: String = "",
        source: String = "",
        publisher: String = "",
        volume: String = "",
        issue: String = "",
        pages: String = "",
        url: String = "",
        abstractText: String = "",
        language: String = "",
        itemType: String = "journalArticle",
        dateText: String = "",
        extra: String = ""
    ) {
        self.title = title
        self.authors = authors
        self.year = year
        self.journal = journal
        self.doi = doi
        self.source = source

        self.publisher = publisher
        self.volume = volume
        self.issue = issue
        self.pages = pages
        self.url = url
        self.abstractText = abstractText
        self.language = language
        self.itemType = itemType
        self.dateText = dateText
        self.extra = extra
    }
}
