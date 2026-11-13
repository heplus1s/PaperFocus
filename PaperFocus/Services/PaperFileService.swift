//
//  PaperFileService.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import Foundation

nonisolated enum PaperFileServiceError: LocalizedError, Sendable {
    case cannotAccessSourceFile
    case copyFailed(String)
    case copyUnavailableOnIOS

    var errorDescription: String? {
        switch self {
        case .cannotAccessSourceFile:
            return "无法访问源 PDF 文件。"
        case .copyFailed(let message):
            return message.isEmpty ? "复制 PDF 到应用目录失败。" : "复制 PDF 到应用目录失败：\(message)"
        case .copyUnavailableOnIOS:
            return "在 iPhone 和 iPad 上，PaperFocus 直接打开“文件”中的原始 PDF，不会复制到应用内。"
        }
    }
}

nonisolated enum PaperFileService {
    static func importPDFToLibrary(from sourceURL: URL) throws -> URL {
        #if os(iOS)
        _ = sourceURL
        throw PaperFileServiceError.copyUnavailableOnIOS
        #else
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default

        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let libraryFolder = appSupport
            .appendingPathComponent("PaperFocus", isDirectory: true)
            .appendingPathComponent("Papers", isDirectory: true)

        if !fileManager.fileExists(atPath: libraryFolder.path) {
            try fileManager.createDirectory(at: libraryFolder, withIntermediateDirectories: true)
        }

        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.isEmpty ? "pdf" : sourceURL.pathExtension
        let safeBaseName = sanitizeFileName(originalName.isEmpty ? "Paper" : originalName)

        var destinationURL = libraryFolder.appendingPathComponent("\(safeBaseName).\(ext)")
        var index = 1

        while fileManager.fileExists(atPath: destinationURL.path) {
            destinationURL = libraryFolder.appendingPathComponent("\(safeBaseName)-\(index).\(ext)")
            index += 1
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            throw PaperFileServiceError.copyFailed(error.localizedDescription)
        }
        #endif
    }

    #if os(macOS)
    private static func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = name
            .components(separatedBy: invalid)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "Paper" : cleaned
    }
    #endif
}
