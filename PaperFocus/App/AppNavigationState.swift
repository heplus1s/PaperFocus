//
//  AppNavigationState.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import Foundation
import Combine
import SwiftData

enum LibrarySidebarFilter: Hashable {
    case all
    case linkedLibrary(String)
    case collection(sourceType: String, path: String)
    case publications(String)
    case duplicates(String)
    case unfiled(String)
    case trash(String)
}

enum AppSidebarSection: String, CaseIterable, Identifiable {
    case home
    case library
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return AppSettings.localizedString("首页", defaultValue: "首页")
        case .library:
            return AppSettings.localizedString("文献库", defaultValue: "文献库")
        case .settings:
            return AppSettings.localizedString("设置", defaultValue: "设置")
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .library: return "books.vertical"
        case .settings: return "gearshape"
        }
    }
}

final class AppNavigationState: ObservableObject {
    @Published var selectedSection: AppSidebarSection? = .home
    @Published var selectedLibrarySidebarFilter: LibrarySidebarFilter = .all

    @Published var selectedPaperID: PersistentIdentifier?
    @Published var activeFocusTaskID: PersistentIdentifier?
    @Published var isReadingModeActive: Bool = false
    @Published var isMacFocusSidebarExpanded: Bool = true
    @Published var isMacAIDialogExpanded: Bool = false

    @Published var timerDraftTitle: String = ""
    @Published var timerReloadID = UUID()
    @Published var readingSelectedText: String = ""

    @Published var resumablePaperID: PersistentIdentifier?
    @Published var resumablePaperTitle: String = ""
    @Published var isResumeAvailable: Bool = false

    func prepareTimer(for paperTitle: String) {
        timerDraftTitle = paperTitle
        timerReloadID = UUID()
    }

    func markResumable(paperID: PersistentIdentifier?, title: String) {
        resumablePaperID = paperID
        resumablePaperTitle = title
        isResumeAvailable = true
    }

    func clearResumable() {
        resumablePaperID = nil
        resumablePaperTitle = ""
        isResumeAvailable = false
    }

    func resetReadingMode() {
        isReadingModeActive = false
        isMacFocusSidebarExpanded = true
        isMacAIDialogExpanded = false
        readingSelectedText = ""
    }

    func resumeLastReading() {
        guard let resumablePaperID else { return }
        selectedSection = .library
        selectedPaperID = resumablePaperID
        isReadingModeActive = true
        isResumeAvailable = false
    }

    func presentMacAIDialog() {
        isMacFocusSidebarExpanded = false
        isMacAIDialogExpanded = true
    }

    func collapseMacAIDialog() {
        isMacFocusSidebarExpanded = true
        isMacAIDialogExpanded = false
    }

    func expandMacFocusSidebar() {
        isMacFocusSidebarExpanded = true
        isMacAIDialogExpanded = false
    }

    func compactMacFocusSidebar() {
        isMacFocusSidebarExpanded = false
    }
}
