//
//  PDFService.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import Foundation

#if os(macOS)
import AppKit
#endif

enum PDFService {
    static func openPDF(at path: String) {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        #if os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    static func revealInFinder(at path: String) {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }
}
