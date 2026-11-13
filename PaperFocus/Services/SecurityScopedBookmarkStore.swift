//
//  SecurityScopedBookmarkStore.swift
//  PaperFocus
//

import Foundation

enum LinkedLibraryBookmarkKey: String, CaseIterable {
    case zoteroLocal = "library.link.zotero.bookmark"
    case endNoteXML = "library.link.endnote.bookmark"
}

final class SecurityScopedBookmarkStore {
    static let shared = SecurityScopedBookmarkStore()

    struct AccessHandle {
        fileprivate let rootPath: String
    }

    private let userDefaults = UserDefaults.standard
    private let grantedBookmarkDefaultsKey = "files.grantedResourceBookmarks"
    private var activeAccessCounts: [String: Int] = [:]
    private var activeURLs: [String: URL] = [:]
    private var resolvedURLsByPath: [String: URL] = [:]

    private init() { }

    func saveBookmark(for key: LinkedLibraryBookmarkKey, url: URL, associatedRootPath: String? = nil) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        userDefaults.set(data, forKey: key.rawValue)

        if let associatedRootPath, !associatedRootPath.isEmpty {
            userDefaults.set(associatedRootPath, forKey: associatedRootPathKey(for: key))
        } else {
            userDefaults.removeObject(forKey: associatedRootPathKey(for: key))
        }
    }

    func clearBookmark(for key: LinkedLibraryBookmarkKey) {
        if let resolved = resolveURL(for: key) {
            endAccessIfNeeded(forRootPath: resolved.standardizedFileURL.path)
        }
        userDefaults.removeObject(forKey: key.rawValue)
        userDefaults.removeObject(forKey: associatedRootPathKey(for: key))
    }

    func resolveURL(for key: LinkedLibraryBookmarkKey) -> URL? {
        guard let data = userDefaults.data(forKey: key.rawValue) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale {
            try? saveBookmark(for: key, url: url)
        }

        return url
    }

    func associatedRootPath(for key: LinkedLibraryBookmarkKey) -> String? {
        let rawValue = userDefaults.string(forKey: associatedRootPathKey(for: key))
        let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    func beginAccess(for key: LinkedLibraryBookmarkKey) -> AccessHandle? {
        guard let url = resolveURL(for: key) else { return nil }
        return beginAccess(toRootURL: url)
    }

    func saveGrantedResource(at url: URL) {
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return
        }

        var bookmarks = loadGrantedBookmarks()
        bookmarks[url.standardizedFileURL.path] = data
        storeGrantedBookmarks(bookmarks)
    }

    func resolvedReadingURL(for fileURL: URL) -> URL {
        resolvedURLsByPath[fileURL.standardizedFileURL.path] ?? fileURL
    }

    func beginAccess(forExternalFile fileURL: URL) -> AccessHandle? {
        let standardizedFileURL = fileURL.standardizedFileURL

        for key in LinkedLibraryBookmarkKey.allCases {
            guard let rootURL = resolveURL(for: key)?.standardizedFileURL else { continue }
            let rootPath = associatedRootPath(for: key) ?? rootURL.path
            let filePath = standardizedFileURL.path

            if Self.path(filePath, isInside: rootPath) {
                return beginAccess(toRootURL: rootURL)
            }
        }

        if let handle = beginAccessUsingGrantedBookmark(for: standardizedFileURL) {
            return handle
        }

        return beginAccess(toRootURL: standardizedFileURL)
    }

    func endAccess(_ handle: AccessHandle?) {
        guard let handle else { return }
        endAccessIfNeeded(forRootPath: handle.rootPath)
    }

    private func beginAccess(toRootURL url: URL) -> AccessHandle? {
        let rootPath = url.standardizedFileURL.path

        if let count = activeAccessCounts[rootPath] {
            activeAccessCounts[rootPath] = count + 1
            return AccessHandle(rootPath: rootPath)
        }

        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }

        activeAccessCounts[rootPath] = 1
        activeURLs[rootPath] = url
        return AccessHandle(rootPath: rootPath)
    }

    private func endAccessIfNeeded(forRootPath rootPath: String) {
        guard let count = activeAccessCounts[rootPath] else { return }

        if count > 1 {
            activeAccessCounts[rootPath] = count - 1
            return
        }

        activeAccessCounts[rootPath] = nil
        let url = activeURLs.removeValue(forKey: rootPath)
        url?.stopAccessingSecurityScopedResource()
    }

    private func associatedRootPathKey(for key: LinkedLibraryBookmarkKey) -> String {
        "\(key.rawValue).rootPath"
    }

    private func loadGrantedBookmarks() -> [String: Data] {
        guard let stored = userDefaults.dictionary(forKey: grantedBookmarkDefaultsKey) else {
            return [:]
        }
        var bookmarks: [String: Data] = [:]
        for (key, value) in stored {
            if let data = value as? Data {
                bookmarks[key] = data
            }
        }
        return bookmarks
    }

    private func storeGrantedBookmarks(_ bookmarks: [String: Data]) {
        userDefaults.set(bookmarks, forKey: grantedBookmarkDefaultsKey)
    }

    private func beginAccessUsingGrantedBookmark(for fileURL: URL) -> AccessHandle? {
        let filePath = fileURL.standardizedFileURL.path
        let bookmarks = loadGrantedBookmarks()
        if let data = bookmarks[filePath],
           let handle = beginAccess(bookmarkData: data, lookupPath: filePath, replacesReadingURL: true) {
            return handle
        }

        let containingPaths = bookmarks.keys.filter { storedPath in
            Self.path(filePath, isInside: storedPath)
        }
        guard let bestPath = containingPaths.max(by: { $0.count < $1.count }),
              let data = bookmarks[bestPath] else {
            return nil
        }
        return beginAccess(bookmarkData: data, lookupPath: filePath, replacesReadingURL: false)
    }

    private func beginAccess(bookmarkData: Data, lookupPath: String, replacesReadingURL: Bool) -> AccessHandle? {
        var isStale = false
        guard let resolved = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale {
            saveGrantedResource(at: resolved)
        }

        if replacesReadingURL {
            let resolvedPath = resolved.standardizedFileURL.path
            resolvedURLsByPath[lookupPath] = resolved
            resolvedURLsByPath[resolvedPath] = resolved
        }
        return beginAccess(toRootURL: resolved)
    }

    private static func path(_ filePath: String, isInside rootPath: String) -> Bool {
        let file = URL(fileURLWithPath: filePath).resolvingSymlinksInPath().standardizedFileURL.path
        let root = URL(fileURLWithPath: rootPath).resolvingSymlinksInPath().standardizedFileURL.path
        if file == root {
            return true
        }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return file.hasPrefix(prefix)
    }
}
