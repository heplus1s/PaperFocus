//
//  ChinesePaperMetadataExtractor.swift
//  PaperFocus
//

import Foundation

nonisolated enum ChinesePaperMetadataExtractor {
    static func extractMetadata(from text: String) -> PaperMetadata? {
        let lines = normalizedLines(from: text)
        guard !lines.isEmpty else { return nil }

        let title = extractTitle(from: lines)
        let authors = extractAuthors(from: lines, title: title)
        let journal = extractJournal(from: lines)
        let year = extractYear(from: lines)
        let abstractText = extractSectionBody(prefixes: ["摘要", "摘 要", "Abstract"], from: lines)
        let keywords = extractSectionBody(prefixes: ["关键词", "关键字", "Key words", "Keywords"], from: lines)

        guard !title.isEmpty || !journal.isEmpty || year != nil else { return nil }

        var extraParts: [String] = []
        if !keywords.isEmpty {
            extraParts.append("关键词：\(keywords)")
        }
        if isLikelyCNKI(text: text) {
            extraParts.append("来源：知网 PDF")
        }

        return PaperMetadata(
            title: title,
            authors: authors,
            year: year,
            journal: journal,
            doi: "",
            source: isLikelyCNKI(text: text) ? "CNKI PDF" : "Chinese PDF",
            publisher: "",
            volume: extractValue(using: #"(?:(?:第)?\s*([0-9]+)\s*卷)"#, in: lines.joined(separator: "\n")),
            issue: extractValue(using: #"(?:(?:第)?\s*([0-9]+)\s*期)"#, in: lines.joined(separator: "\n")),
            pages: extractValue(using: #"([0-9]+\s*[-~]\s*[0-9]+)"#, in: lines.joined(separator: "\n")),
            url: "",
            abstractText: abstractText,
            language: "zh-Hans",
            itemType: "journalArticle",
            dateText: year.map(String.init) ?? "",
            extra: extraParts.joined(separator: "\n")
        )
    }

    static func isLikelyCNKI(text: String) -> Bool {
        let lowercased = text.lowercased()
        let markers = [
            "中国知网",
            "www.cnki.net",
            "cnki.net",
            "中国学术期刊",
            "中图分类号",
            "分类号",
            "关键词",
            "关键字"
        ]

        return markers.contains { lowercased.contains($0.lowercased()) }
    }

    static func preferredTitleCandidate(from text: String) -> String? {
        let lines = normalizedLines(from: text)
        let title = extractTitle(from: lines)
        return title.isEmpty ? nil : title
    }

    private static func normalizedLines(from text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map {
                $0.replacingOccurrences(of: "\t", with: " ")
                    .replacingOccurrences(of: "\u{00A0}", with: " ")
                    .replacingOccurrences(of: #"[\s]{2,}"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    private static func extractTitle(from lines: [String]) -> String {
        let frequency = lines.reduce(into: [String: Int]()) { partialResult, line in
            partialResult[line, default: 0] += 1
        }

        let candidates = lines.prefix(24).enumerated().compactMap { index, line -> (title: String, score: Int)? in
            guard let score = scoreTitleCandidate(line, at: index, in: lines, frequency: frequency) else {
                return nil
            }
            return (cleanedTitle(line), score)
        }

        return candidates.max(by: { $0.score < $1.score })?.title ?? ""
    }

    private static func extractAuthors(from lines: [String], title: String) -> String {
        guard let titleIndex = lines.firstIndex(of: title) else { return "" }

        let candidates = lines.dropFirst(titleIndex + 1).prefix(4)
        let blockedTokens = ["摘要", "关键词", "基金项目", "作者单位", "中国知网", "abstract", "email", "doi"]

        for line in candidates {
            let lowercased = line.lowercased()
            guard line.count >= 2, line.count <= 48 else { continue }
            guard !blockedTokens.contains(where: { lowercased.contains($0) }) else { continue }
            guard !line.contains("："), !line.contains(":"), !line.contains("http") else { continue }
            guard line.range(of: #"[0-9]{4}"#, options: .regularExpression) == nil else { continue }

            if line.contains(" ") || line.contains("，") || line.contains(",") || containsMostlyChineseNameTokens(line) {
                return line
            }
        }

        return ""
    }

    private static func extractJournal(from lines: [String]) -> String {
        for line in lines.prefix(40) {
            let quoted = extractValue(using: #"《([^》]{2,40})》"#, in: line)
            if !quoted.isEmpty {
                return quoted
            }
        }

        let journalHints = ["学报", "期刊", "杂志", "研究", "评论", "论坛", "大学学报", "社会科学", "工程", "医学"]
        for line in lines.prefix(40) {
            guard line.count >= 4, line.count <= 40 else { continue }
            guard journalHints.contains(where: { line.contains($0) }) else { continue }
            guard !line.contains("摘要"), !line.contains("关键词"), !line.contains("作者") else { continue }
            return line
        }

        return ""
    }

    private static func extractYear(from lines: [String]) -> Int? {
        for line in lines.prefix(40) {
            let yearText = extractValue(using: #"\b((?:19|20)\d{2})\b"#, in: line)
            if let year = Int(yearText) {
                return year
            }
        }

        return nil
    }

    private static func extractSectionBody(prefixes: [String], from lines: [String]) -> String {
        for (index, line) in lines.enumerated() {
            for prefix in prefixes {
                if line.lowercased().hasPrefix(prefix.lowercased()) {
                    let current = line
                        .replacingOccurrences(of: #"^[^：:]{0,20}[：:]\s*"#, with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !current.isEmpty && current.lowercased() != prefix.lowercased() {
                        return current
                    }

                    let nextLines = lines.dropFirst(index + 1).prefix(3)
                    let blockedPrefixes = ["关键词", "关键字", "Abstract", "引言", "一、", "1 "]
                    let merged = nextLines
                        .prefix { candidate in
                            !blockedPrefixes.contains(where: { candidate.lowercased().hasPrefix($0.lowercased()) })
                        }
                        .joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    return merged
                }
            }
        }

        return ""
    }

    private static func extractValue(using pattern: String, in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return ""
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return ""
        }

        return String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsMostlyChineseNameTokens(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        let chineseCount = scalars.filter {
            $0.value >= 0x4E00 && $0.value <= 0x9FFF
        }.count
        return chineseCount >= 2
    }

    private static func scoreTitleCandidate(
        _ rawLine: String,
        at index: Int,
        in lines: [String],
        frequency: [String: Int]
    ) -> Int? {
        let line = cleanedTitle(rawLine)
        let lowercased = line.lowercased()

        guard line.count >= 6, line.count <= 80 else { return nil }
        guard !line.contains("@"), !line.contains("http"), !line.contains("www.") else { return nil }
        guard !isObviouslyHeaderLike(line) else { return nil }

        let chineseCount = chineseCharacterCount(in: line)
        guard chineseCount >= 4 || line.count >= 12 else { return nil }

        var score = 0
        score += max(0, 24 - index * 2)
        score += min(chineseCount * 3, 36)

        switch line.count {
        case 10...32:
            score += 14
        case 8...50:
            score += 8
        default:
            score -= 8
        }

        if frequency[line, default: 0] > 1 {
            score -= 36
        }

        if containsJournalOrSourceHint(lowercased) {
            score -= 18
        }

        if hasAuthorLineNearby(after: index, in: lines) {
            score += 18
        }

        if hasAbstractLineNearby(after: index, in: lines) {
            score += 16
        }

        if line.contains("：") || line.contains(":") {
            score += 4
        }

        return score > 0 ? score : nil
    }

    private static func cleanedTitle(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"^[\p{P}\p{S}\s]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[\p{P}\p{S}\s]+$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func chineseCharacterCount(in text: String) -> Int {
        text.unicodeScalars.filter { scalar in
            scalar.value >= 0x4E00 && scalar.value <= 0x9FFF
        }.count
    }

    private static func isObviouslyHeaderLike(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        let blockedTokens = [
            "摘要",
            "摘 要",
            "abstract",
            "关键词",
            "关键字",
            "doi",
            "基金项目",
            "作者简介",
            "中国知网",
            "中图分类号",
            "文献标识码",
            "文章编号",
            "收稿日期",
            "修回日期",
            "网络首发",
            "在线出版",
            "issn",
            "cnki.net"
        ]

        guard !blockedTokens.contains(where: { lowercased.contains($0) }) else { return true }

        let headerPatterns = [
            #"^\(?\d+\)?$"#,
            #"^第\s*\d+\s*页$"#,
            #"^第\s*\d+\s*卷"#,
            #"^第\s*\d+\s*期"#,
            #"^vol\.?\s*\d+"#,
            #"^no\.?\s*\d+"#,
            #"^(19|20)\d{2}\s*年"#,
            #"^\d+\s*-\s*\d+$"#
        ]

        return headerPatterns.contains { pattern in
            line.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private static func containsJournalOrSourceHint(_ lowercased: String) -> Bool {
        let hints = [
            "学报",
            "期刊",
            "杂志",
            "journal",
            "cnki",
            "中国知网",
            "issn",
            "vol.",
            "no."
        ]

        return hints.contains(where: { lowercased.contains($0) })
    }

    private static func hasAuthorLineNearby(after index: Int, in lines: [String]) -> Bool {
        let candidates = lines.dropFirst(index + 1).prefix(4)
        let blockedTokens = ["摘要", "关键词", "基金项目", "作者单位", "中国知网", "abstract", "email", "doi"]

        return candidates.contains { line in
            let lowercased = line.lowercased()
            guard line.count >= 2, line.count <= 48 else { return false }
            guard !blockedTokens.contains(where: { lowercased.contains($0) }) else { return false }
            guard !line.contains("："), !line.contains(":"), !line.contains("http") else { return false }
            guard line.range(of: #"[0-9]{4}"#, options: .regularExpression) == nil else { return false }

            return line.contains(" ")
                || line.contains("，")
                || line.contains(",")
                || containsMostlyChineseNameTokens(line)
        }
    }

    private static func hasAbstractLineNearby(after index: Int, in lines: [String]) -> Bool {
        lines
            .dropFirst(index + 1)
            .prefix(8)
            .contains { line in
                let lowercased = line.lowercased()
                return lowercased.hasPrefix("摘要")
                    || lowercased.hasPrefix("摘 要")
                    || lowercased.hasPrefix("abstract")
            }
    }
}
