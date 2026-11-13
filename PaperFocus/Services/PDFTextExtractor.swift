//
//  PDFTextExtractor.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

//
//  PDFTextExtractor.swift
//  PaperFocus
//

import Foundation
import PDFKit

enum PDFTextExtractor {
    static func extractText(from url: URL, maxPages: Int = 3) -> String {
        guard let document = PDFDocument(url: url) else { return "" }

        let pageCount = min(document.pageCount, maxPages)
        var text = ""

        for index in 0..<pageCount {
            if let page = document.page(at: index),
               let pageText = page.string {
                text += pageText + "\n"
            }
        }

        return text
    }
}
