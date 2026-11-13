//
//  CrossrefServices.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import Foundation

enum CrossrefServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noMetadataFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Crossref 请求地址无效。"
        case .invalidResponse:
            return "Crossref 返回数据无效。"
        case .noMetadataFound:
            return "未找到文献信息。"
        }
    }
}

final class CrossrefService {
    private let mailto = "your_email@example.com"

    func fetchMetadata(byDOI doi: String) async throws -> PaperMetadata {
        let encodedDOI = doi.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? doi
        let urlString = "https://api.crossref.org/works/\(encodedDOI)?mailto=\(mailto)"

        guard let url = URL(string: urlString) else {
            throw CrossrefServiceError.invalidURL
        }

        let (data, response) = try await Self.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw CrossrefServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(CrossrefWorkResponse.self, from: data)
        return mapWorkToMetadata(decoded.message)
    }

    func searchMetadataByTitle(_ title: String) async throws -> PaperMetadata {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let urlString = "https://api.crossref.org/works?query.title=\(encodedTitle)&rows=1&mailto=\(mailto)"

        guard let url = URL(string: urlString) else {
            throw CrossrefServiceError.invalidURL
        }

        let (data, response) = try await Self.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw CrossrefServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(CrossrefSearchResponse.self, from: data)

        guard let first = decoded.message.items.first else {
            throw CrossrefServiceError.noMetadataFound
        }

        return mapWorkToMetadata(first)
    }

    private func mapWorkToMetadata(_ work: CrossrefWork) -> PaperMetadata {
        let title = work.title?.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知标题"

        let authors = work.author?
            .map { author in
                let given = author.given ?? ""
                let family = author.family ?? ""
                let name = "\(given) \(family)".trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? nil : name
            }
            .compactMap { $0 }
            .joined(separator: ", ") ?? ""

        let year =
            work.publishedPrint?.dateParts.first?.first
            ?? work.publishedOnline?.dateParts.first?.first
            ?? work.issued?.dateParts.first?.first

        let journal = work.containerTitle?.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let publisher = work.publisher?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let volume = work.volume?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let issue = work.issue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let pages = work.page?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let url = work.URL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let abstractText = cleanAbstract(work.abstract ?? "")
        let language = work.language?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let itemType = mapCrossrefType(work.type ?? "")
        let dateText = makeDateText(
            printDate: work.publishedPrint?.dateParts.first,
            onlineDate: work.publishedOnline?.dateParts.first,
            issuedDate: work.issued?.dateParts.first
        )

        return PaperMetadata(
            title: title,
            authors: authors,
            year: year,
            journal: journal,
            doi: work.DOI,
            source: "Crossref",
            publisher: publisher,
            volume: volume,
            issue: issue,
            pages: pages,
            url: url,
            abstractText: abstractText,
            language: language,
            itemType: itemType,
            dateText: dateText
        )
    }

    private func cleanAbstract(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }

        var text = raw

        // 去掉常见 JATS/XML 标签
        let patterns = [
            "<jats:p>",
            "</jats:p>",
            "<jats:title>",
            "</jats:title>",
            "<jats:italic>",
            "</jats:italic>",
            "<jats:bold>",
            "</jats:bold>",
            "<jats:sub>",
            "</jats:sub>",
            "<jats:sup>",
            "</jats:sup>"
        ]

        for pattern in patterns {
            text = text.replacingOccurrences(of: pattern, with: "")
        }

        // 粗略去掉其余 XML/HTML 标签
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeDateText(
        printDate: [Int]?,
        onlineDate: [Int]?,
        issuedDate: [Int]?
    ) -> String {
        let parts = printDate ?? onlineDate ?? issuedDate ?? []

        guard !parts.isEmpty else { return "" }

        if parts.count >= 3 {
            return String(format: "%04d-%02d-%02d", parts[0], parts[1], parts[2])
        } else if parts.count == 2 {
            return String(format: "%04d-%02d", parts[0], parts[1])
        } else {
            return "\(parts[0])"
        }
    }

    private static func data(from url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("PaperFocus", forHTTPHeaderField: "User-Agent")
        return try await URLSession.shared.data(for: request)
    }

    private func mapCrossrefType(_ rawType: String) -> String {
        switch rawType {
        case "journal-article":
            return "journalArticle"
        case "proceedings-article":
            return "conferencePaper"
        case "book-chapter":
            return "bookChapter"
        case "book":
            return "book"
        case "dissertation":
            return "thesis"
        default:
            return rawType.isEmpty ? "journalArticle" : rawType
        }
    }
}

// MARK: - Crossref JSON Models

private struct CrossrefWorkResponse: Decodable {
    let message: CrossrefWork
}

private struct CrossrefSearchResponse: Decodable {
    let message: CrossrefSearchMessage
}

private struct CrossrefSearchMessage: Decodable {
    let items: [CrossrefWork]
}

private struct CrossrefWork: Decodable {
    let DOI: String
    let title: [String]?
    let containerTitle: [String]?
    let author: [CrossrefAuthor]?
    let issued: CrossrefDateParts?

    let publishedPrint: CrossrefDateParts?
    let publishedOnline: CrossrefDateParts?

    let publisher: String?
    let volume: String?
    let issue: String?
    let page: String?
    let URL: String?
    let abstract: String?
    let language: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case DOI
        case title
        case author
        case issued
        case publisher
        case volume
        case issue
        case page
        case URL
        case abstract
        case language
        case type
        case containerTitle = "container-title"
        case publishedPrint = "published-print"
        case publishedOnline = "published-online"
    }
}

private struct CrossrefAuthor: Decodable {
    let given: String?
    let family: String?
}

private struct CrossrefDateParts: Decodable {
    let dateParts: [[Int]]

    enum CodingKeys: String, CodingKey {
        case dateParts = "date-parts"
    }
}
