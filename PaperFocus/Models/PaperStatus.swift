//
//  PaperStatus.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import SwiftUI

enum PaperStatus: String, CaseIterable, Identifiable {
    case unread
    case skimmed
    case reading
    case finished

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unread:
            return AppSettings.localizedString("未读")
        case .skimmed:
            return AppSettings.localizedString("粗读")
        case .reading:
            return AppSettings.localizedString("精读中")
        case .finished:
            return AppSettings.localizedString("已读")
        }
    }

    var color: Color {
        switch self {
        case .unread:
            return .gray
        case .skimmed:
            return .blue
        case .reading:
            return .orange
        case .finished:
            return .green
        }
    }
}
