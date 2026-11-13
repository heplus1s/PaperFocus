//
//  ZoteroWebLibraryClient.swift
//  PaperFocus
//

import Foundation

struct ZoteroWebLibrary {
    var userID: String
    var username: String
    var items: [[String: Any]]
    var collections: [[String: Any]]
}

enum ZoteroWebLibraryClient {
    static func fetchLibrary(apiKey: String) async throws -> ZoteroWebLibrary {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw LibraryImportError.zoteroAccountRejected("请输入 Zotero API 密钥。")
        }

        let identity = try await fetchIdentity(apiKey: trimmedKey)
        let userID = identity.userID
        let items = try await fetchPaged(path: "users/\(userID)/items", apiKey: trimmedKey)
        let collections = try await fetchPaged(path: "users/\(userID)/collections", apiKey: trimmedKey)

        return ZoteroWebLibrary(
            userID: userID,
            username: identity.username,
            items: items,
            collections: collections
        )
    }

    private static func fetchIdentity(apiKey: String) async throws -> (userID: String, username: String) {
        let payload = try await send(path: "keys/current", apiKey: apiKey)
        guard let userID = stringValue(payload["userID"]), !userID.isEmpty else {
            throw LibraryImportError.zoteroAccountRejected("Zotero 未返回可用的账户标识。请检查 API 密钥权限。")
        }
        let username = stringValue(payload["username"]) ?? ""
        return (userID, username)
    }

    private static func fetchPaged(path: String, apiKey: String) async throws -> [[String: Any]] {
        var start = 0
        let limit = 100
        var collected: [[String: Any]] = []

        while collected.count < 50_000 {
            var components = URLComponents(string: "https://api.zotero.org/\(path)")
            components?.queryItems = [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "start", value: "\(start)"),
                URLQueryItem(name: "format", value: "json")
            ]
            guard let url = components?.url else {
                throw LibraryImportError.zoteroAccountRejected("Zotero 接口地址无效。")
            }

            let (data, response) = try await request(url: url, apiKey: apiKey)
            try validate(response: response, data: data)
            let page = try decodeArray(data)
            collected.append(contentsOf: page)
            if page.count < limit {
                break
            }
            start += page.count
        }

        return collected
    }

    private static func send(path: String, apiKey: String) async throws -> [String: Any] {
        guard let url = URL(string: "https://api.zotero.org/\(path)") else {
            throw LibraryImportError.zoteroAccountRejected("Zotero 接口地址无效。")
        }
        let (data, response) = try await request(url: url, apiKey: apiKey)
        try validate(response: response, data: data)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = json as? [String: Any] else {
            throw LibraryImportError.zoteroAccountRejected("Zotero 返回的账户信息无法读取。")
        }
        return dictionary
    }

    private static func request(url: URL, apiKey: String) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Zotero-API-Key")
        request.setValue("3", forHTTPHeaderField: "Zotero-API-Version")
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw LibraryImportError.zoteroAccountRejected("无法连接 Zotero。请检查网络后重试。")
        }
    }

    private static func validate(response: URLResponse, data _: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw LibraryImportError.zoteroAccountRejected("Zotero 返回的响应无效。")
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 403 || http.statusCode == 401 {
                throw LibraryImportError.zoteroAccountRejected("Zotero API 密钥无效或没有文献库读取权限。")
            }
            throw LibraryImportError.zoteroAccountRejected("Zotero 请求失败（\(http.statusCode)）。")
        }
    }

    private static func decodeArray(_ data: Data) throws -> [[String: Any]] {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let array = json as? [[String: Any]] else {
            throw LibraryImportError.zoteroAccountRejected("Zotero 文献数据无法读取。")
        }
        return array
    }

    private static func stringValue(_ raw: Any?) -> String? {
        if let string = raw as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = raw as? NSNumber {
            return number.stringValue
        }
        return nil
    }
}
