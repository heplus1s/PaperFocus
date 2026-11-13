//
//  PDFTextExtractor.swift
//  PaperFocus
//

import Foundation
import PDFKit

nonisolated struct TransferablePDFDocument: @unchecked Sendable {
    let document: PDFDocument?
}

nonisolated enum PDFTextExtractor {
    private static let queue = DispatchQueue(label: "app.paperfocus.pdfkit", qos: .userInitiated)

    static func extractText(from url: URL, maxPages: Int = 3) -> String {
        queue.sync {
            autoreleasepool {
                guard let document = PDFDocument(url: url) else { return "" }

                let pageCount = min(document.pageCount, max(0, maxPages))
                var text = ""
                text.reserveCapacity(pageCount * 2_000)

                for index in 0..<pageCount {
                    if let page = document.page(at: index),
                       let pageText = page.string {
                        text += pageText
                        text += "\n"
                    }
                }

                return text
            }
        }
    }

    static func loadDocument(at url: URL) -> TransferablePDFDocument {
        let document = queue.sync {
            autoreleasepool {
                PDFDocument(url: url)
            }
        }
        return TransferablePDFDocument(document: document)
    }
}
