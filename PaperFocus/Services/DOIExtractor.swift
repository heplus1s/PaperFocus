//
//  DOIExtractor.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

//
//  DOIExtractor.swift
//  PaperFocus
//

import Foundation

enum DOIExtractor {
    static func extractDOI(from url: URL, maxPages: Int = 3) -> String? {
        let text = PDFTextExtractor.extractText(from: url, maxPages: maxPages)
        return extractDOI(fromText: text)
    }

    static func extractDOI(fromText text: String) -> String? {
        let normalizedText = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "doi:", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "DOI:", with: " ")
            .replacingOccurrences(of: "https://doi.org/", with: "")
            .replacingOccurrences(of: "http://doi.org/", with: "")

        let pattern = #"10\.\d{4,9}/[-._;()/:A-Z0-9]+"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let range = NSRange(normalizedText.startIndex..<normalizedText.endIndex, in: normalizedText)
        guard let match = regex.firstMatch(in: normalizedText, options: [], range: range),
              let matchRange = Range(match.range, in: normalizedText) else {
            return nil
        }

        var doi = String(normalizedText[matchRange])
        doi = doi.trimmingCharacters(in: CharacterSet(charactersIn: " \n\t\r.,;)]}>"))

        return doi
    }
}
