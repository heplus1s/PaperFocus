//
//  PaperMetadataImporter.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

//
//  PaperMetadataImporter.swift
//  PaperFocus
//

import Foundation

final class PaperMetadataImporter {
    private let crossrefService = CrossrefService()

    func importMetadata(from pdfURL: URL) async throws -> PaperMetadata {
        let extractedText = PDFTextExtractor.extractText(from: pdfURL, maxPages: 4)

        if let doi = DOIExtractor.extractDOI(from: pdfURL) {
            do {
                return try await crossrefService.fetchMetadata(byDOI: doi)
            } catch {
                print("DOI 匹配失败，转标题匹配：\(error.localizedDescription)")
            }
        }

        if let chineseMetadata = Self.localMetadata(fromExtractedText: extractedText),
           chineseMetadata.source == "CNKI PDF" {
            return chineseMetadata
        }

        let titleCandidate = firstMeaningfulLine(from: extractedText)

        if let titleCandidate, !titleCandidate.isEmpty {
            do {
                return try await crossrefService.searchMetadataByTitle(titleCandidate)
            } catch {
                if let chineseMetadata = Self.localMetadata(fromExtractedText: extractedText) {
                    return chineseMetadata
                }
                throw error
            }
        }

        if let chineseMetadata = Self.localMetadata(fromExtractedText: extractedText) {
            return chineseMetadata
        }

        throw PaperMetadataImporterError.metadataNotFound
    }

    static func localMetadata(from pdfURL: URL) -> PaperMetadata? {
        let text = PDFTextExtractor.extractText(from: pdfURL, maxPages: 4)
        return localMetadata(fromExtractedText: text)
    }

    static func localMetadata(fromExtractedText text: String) -> PaperMetadata? {
        if let chineseMetadata = ChinesePaperMetadataExtractor.extractMetadata(from: text) {
            return chineseMetadata
        }

        guard let fallbackTitle = firstMeaningfulLine(from: text), !fallbackTitle.isEmpty else {
            return nil
        }

        return PaperMetadata(
            title: fallbackTitle,
            authors: "",
            year: extractYear(from: text),
            journal: "",
            doi: DOIExtractor.extractDOI(fromText: text) ?? "",
            source: "PDF Text",
            publisher: "",
            volume: "",
            issue: "",
            pages: "",
            url: "",
            abstractText: "",
            language: "",
            itemType: "journalArticle",
            dateText: ""
        )
    }

    private func firstMeaningfulLine(from text: String) -> String? {
        Self.firstMeaningfulLine(from: text)
    }

    private static func firstMeaningfulLine(from text: String) -> String? {
        if let chineseTitle = ChinesePaperMetadataExtractor.preferredTitleCandidate(from: text) {
            return chineseTitle
        }

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let filtered = lines.filter { line in
            line.count > 12 &&
            !line.lowercased().contains("abstract") &&
            !line.lowercased().contains("introduction") &&
            !line.lowercased().contains("doi") &&
            !line.lowercased().contains("received")
        }

        return filtered.first
    }

    private static func extractYear(from text: String) -> Int? {
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
}

enum PaperMetadataImporterError: LocalizedError {
    case metadataNotFound

    var errorDescription: String? {
        switch self {
        case .metadataNotFound:
            return "未能从 PDF 中识别文献信息。"
        }
    }
}
