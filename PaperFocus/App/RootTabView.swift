//
//  RootTabView.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var navigationState = AppNavigationState()
    @AppStorage(AppSettings.zoteroLinkedDisplayPathKey)
    private var zoteroLinkedDisplayPath: String = AppSettings.defaultLinkedLibraryDisplayPath
    @AppStorage(AppSettings.endNoteLinkedDisplayPathKey)
    private var endNoteLinkedDisplayPath: String = AppSettings.defaultLinkedLibraryDisplayPath
    @AppStorage(AppSettings.zoteroLinkedDisplayNameKey)
    private var zoteroLinkedDisplayName: String = AppSettings.defaultLinkedLibraryDisplayName
    @AppStorage(AppSettings.endNoteLinkedDisplayNameKey)
    private var endNoteLinkedDisplayName: String = AppSettings.defaultLinkedLibraryDisplayName
    @AppStorage(AppSettings.libraryAutoSyncOnLaunchKey)
    private var libraryAutoSyncOnLaunch: Bool = AppSettings.defaultLibraryAutoSyncOnLaunch
    @AppStorage(AppSettings.libraryAutoRefreshIntervalMinutesKey)
    private var libraryAutoRefreshIntervalMinutes: Int = AppSettings.defaultLibraryAutoRefreshIntervalMinutes
    @AppStorage(AppSettings.preferLocalZoteroLibraryKey)
    private var preferLocalZoteroLibrary = AppSettings.defaultPreferLocalZoteroLibrary

    @State private var hasPerformedStartupLinkedSync = false
    @State private var didAttemptZoteroAdopt = false
    @State private var showLibraryImportSheet = false
    @State private var libraryImportMode: LibraryImportMode = .zotero
    @State private var librarySyncNoticeMessage = ""
    @State private var librarySyncNoticeToken = UUID()

    private let libraryImportService = LibraryImportService()

    private var hasLinkedLibrary: Bool {
        !zoteroLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !endNoteLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var autoRefreshTaskID: String {
        [
            libraryAutoRefreshIntervalMinutes.description,
            zoteroLinkedDisplayPath,
            endNoteLinkedDisplayPath
        ].joined(separator: "|")
    }

    var body: some View {
        Group {
            #if os(macOS)
            RootMacView()
            #else
            TabView {
                NavigationStack {
                    HomeView()
                }
                .tabItem {
                    Label("首页", systemImage: "house")
                }

                NavigationStack {
                    LibraryView()
                }
                .tabItem {
                    Label("文献库", systemImage: "books.vertical")
                }

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
            }
            .overlay(alignment: .topLeading) {
                SidebarFocusTimerView()
                    .environmentObject(navigationState)
                    .id(navigationState.timerReloadID)
                    .frame(width: 0, height: 0)
                    .clipped()
                    .opacity(0.001)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topTrailing) {
                FloatingFocusTimerHUD()
                    .environmentObject(navigationState)
            }
            #endif
        }
        .onAppear {
            if UserDefaults.standard.bool(forKey: AppSettings.paperFocusStoreRejectedKey) {
                showLibrarySyncNotice(AppSettings.localizedString("现有文献库文件不是 PaperFocus 文献库，因此未打开。当前文献库保持不变。"))
            }
            guard !hasPerformedStartupLinkedSync else { return }
            hasPerformedStartupLinkedSync = true
            Task {
                #if os(macOS)
                await adoptLocalZoteroIfNeeded()
                #endif
                guard libraryAutoSyncOnLaunch, hasLinkedLibrary else { return }
                await refreshLinkedLibrariesSilently(reason: .launch)
            }
        }
        #if os(macOS)
        .onChange(of: preferLocalZoteroLibrary) { _, isEnabled in
            guard isEnabled else { return }
            didAttemptZoteroAdopt = false
            Task { await adoptLocalZoteroIfNeeded() }
        }
        #endif
        .sheet(isPresented: $showLibraryImportSheet) {
            LibraryImportModeSheet(initialMode: libraryImportMode) { urls in
                _ = try await libraryImportService.importStandalonePDFs(from: urls, into: modelContext)
            } onFinished: { message in
                showLibrarySyncNotice(message)
            }
        }
        .task(id: autoRefreshTaskID) {
            guard libraryAutoRefreshIntervalMinutes > 0 else { return }

            while !Task.isCancelled {
                let seconds = UInt64(libraryAutoRefreshIntervalMinutes) * 60 * 1_000_000_000
                try? await Task.sleep(nanoseconds: seconds)
                guard !Task.isCancelled else { return }

                await refreshLinkedLibrariesSilently(reason: .scheduled)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !librarySyncNoticeMessage.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(librarySyncNoticeMessage)
                        .lineLimit(2)
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appMenuLibraryCommand)) { notification in
            #if os(macOS)
            guard let command = notification.object as? AppMenuLibraryCommand else { return }
            handleLibraryMenuCommand(command)
            #endif
        }
        .environmentObject(navigationState)
    }

    private enum LibrarySyncTrigger {
        case launch
        case scheduled
    }

    private func refreshLinkedLibrariesSilently(reason: LibrarySyncTrigger) async {
        guard hasLinkedLibrary else { return }

        do {
            var messages: [String] = []

            if !zoteroLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let summary = try await libraryImportService.refreshLinkedZoteroLibrary(into: modelContext)
                messages.append(AppSettings.localizedFormat("Zotero：%@", defaultValue: "Zotero: %@", summary.syncMessage))
            }

            if !endNoteLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let summary = try await libraryImportService.refreshLinkedEndNoteXML(
                    from: endNoteLinkedDisplayPath,
                    into: modelContext
                )
                messages.append(AppSettings.localizedFormat("EndNote：%@", defaultValue: "EndNote: %@", summary.syncMessage))
            }

            guard !messages.isEmpty else { return }
            let prefix = reason == .launch
                ? AppSettings.localizedString("启动同步完成")
                : AppSettings.localizedString("文库已自动同步")
            showLibrarySyncNotice(
                AppSettings.localizedFormat(
                    "%@：%@",
                    defaultValue: "%@: %@",
                    prefix,
                    messages.joined(separator: AppSettings.localizedString("；"))
                )
            )
        } catch {
            showLibrarySyncNotice(
                AppSettings.localizedFormat("自动同步失败：%@", defaultValue: "Auto sync failed: %@", error.localizedDescription)
            )
        }
    }

    private func showLibrarySyncNotice(_ message: String) {
        let token = UUID()
        librarySyncNoticeToken = token

        withAnimation(.easeInOut(duration: 0.2)) {
            librarySyncNoticeMessage = message
        }

        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                guard librarySyncNoticeToken == token else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    librarySyncNoticeMessage = ""
                }
            }
        }
    }

    #if os(macOS)
    private func handleLibraryMenuCommand(_ command: AppMenuLibraryCommand) {
        switch command {
        case .linkZotero:
            libraryImportMode = .zotero
            showLibraryImportSheet = true

        case .refreshZotero:
            guard !zoteroLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            Task {
                do {
                    let summary = try await libraryImportService.refreshLinkedZoteroLibrary(into: modelContext)
                    showLibrarySyncNotice(AppSettings.localizedFormat("Zotero：%@", defaultValue: "Zotero: %@", summary.syncMessage))
                } catch {
                    showLibrarySyncNotice(
                        AppSettings.localizedFormat("Zotero 操作失败：%@", defaultValue: "Zotero failed: %@", error.localizedDescription)
                    )
                }
            }

        case .unlinkZotero:
            SecurityScopedBookmarkStore.shared.clearBookmark(for: .zoteroLocal)
            AppSettings.clearZoteroLinkKind()
            zoteroLinkedDisplayPath = ""
            zoteroLinkedDisplayName = ""
            showLibrarySyncNotice(AppSettings.localizedString("已断开 Zotero 文献库关联。"))

        case .linkEndNote:
            libraryImportMode = .endNote
            showLibraryImportSheet = true

        case .refreshEndNote:
            guard !endNoteLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            Task {
                do {
                    let summary = try await libraryImportService.refreshLinkedEndNoteXML(
                        from: endNoteLinkedDisplayPath,
                        into: modelContext
                    )
                    showLibrarySyncNotice(AppSettings.localizedFormat("EndNote：%@", defaultValue: "EndNote: %@", summary.syncMessage))
                } catch {
                    showLibrarySyncNotice(
                        AppSettings.localizedFormat("EndNote 操作失败：%@", defaultValue: "EndNote failed: %@", error.localizedDescription)
                    )
                }
            }

        case .unlinkEndNote:
            SecurityScopedBookmarkStore.shared.clearBookmark(for: .endNoteXML)
            endNoteLinkedDisplayPath = ""
            endNoteLinkedDisplayName = ""
            showLibrarySyncNotice(AppSettings.localizedString("已断开 EndNote 本地库关联。"))

        case .importZoteroJSON:
            libraryImportMode = .zotero
            showLibraryImportSheet = true

        case .importEndNoteXML:
            libraryImportMode = .endNote
            showLibraryImportSheet = true

        case .importPDFFolder:
            libraryImportMode = .pdfFolder
            showLibraryImportSheet = true
        }
    }

    private func adoptLocalZoteroIfNeeded() async {
        guard !didAttemptZoteroAdopt else { return }
        didAttemptZoteroAdopt = true
        guard preferLocalZoteroLibrary else { return }
        guard zoteroLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let matches = await Task.detached(priority: .userInitiated) {
            ZoteroLibraryLocator.candidates()
        }.value

        if matches.count > 1 {
            showLibrarySyncNotice(AppSettings.localizedString("找到多个 Zotero 文献库。请在导入时选择要关联的文献库。"))
            return
        }

        guard let match = matches.first else { return }
        do {
            let result = try await libraryImportService.linkZoteroLibrary(from: match.rootURL, into: modelContext)
            zoteroLinkedDisplayPath = result.rootURL.path
            zoteroLinkedDisplayName = result.rootURL.lastPathComponent
            showLibrarySyncNotice(AppSettings.localizedFormat("Zotero：%@", defaultValue: "Zotero: %@", result.summary.syncMessage))
        } catch {
            showLibrarySyncNotice(
                AppSettings.localizedFormat("Zotero 操作失败：%@", defaultValue: "Zotero failed: %@", error.localizedDescription)
            )
        }
    }

    private func chooseFile(title: String, prompt: String, contentTypes: [UTType]) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = contentTypes

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private func chooseDirectory(title: String, prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private func chooseZoteroLibraryLocation(title: String, prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
    #endif
}

#if os(macOS)
private enum MacSidebarLayout {
    static let sidebarWidth: CGFloat = 320
    static let contentInset: CGFloat = 8
    static let overviewPaneMinimumHeight: CGFloat = 150
    static let folderPaneMinimumHeight: CGFloat = overviewPaneMinimumHeight
    static let minimumWindowHeight: CGFloat = 640
    static var panelContentMinWidth: CGFloat { sidebarWidth - (contentInset * 2) - 4 }
}

private struct RootMacView: View {
    @EnvironmentObject private var navigationState: AppNavigationState
    @ObservedObject private var pdfEditingCoordinator = PDFEditingCoordinator.shared
    @AppStorage(AppSettings.macShowMainInterfaceSettingsKey)
    private var showMainInterfaceSettings: Bool = AppSettings.defaultMacShowMainInterfaceSettings

    @State private var pendingSection: AppSidebarSection?
    @State private var showSaveConfirm = false

    var body: some View {
        HStack(spacing: 0) {
            MacSidebar { section in
                requestSectionChange(to: section)
            }
            .environmentObject(navigationState)
            .frame(width: MacSidebarLayout.sidebarWidth)

            Divider()

            Group {
                switch navigationState.selectedSection ?? .home {
                case .home:
                    NavigationStack {
                        HomeView()
                    }
                    .environmentObject(navigationState)

                case .library:
                    NavigationStack {
                        LibraryView()
                    }
                    .environmentObject(navigationState)

                case .settings:
                    NavigationStack {
                        SettingsView(showsToolbarPlaceholders: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: MacSidebarLayout.minimumWindowHeight, alignment: .topLeading)
        .confirmationDialog("当前 PDF 标注尚未保存", isPresented: $showSaveConfirm, titleVisibility: .visible) {
            Button("保存并切换") {
                _ = pdfEditingCoordinator.saveActiveDocument()
                applyPendingSection()
            }

            Button("不保存切换", role: .destructive) {
                pdfEditingCoordinator.discardUnsavedState()
                applyPendingSection()
            }

            Button("取消", role: .cancel) {
                pendingSection = nil
            }
        } message: {
            Text("当前 PDF 有未保存修改。切换页面前是否先保存？")
        }
        .onAppear {
            guard !showMainInterfaceSettings, navigationState.selectedSection == .settings else { return }
            navigationState.selectedSection = .home
        }
        .onChange(of: showMainInterfaceSettings) { _, newValue in
            guard !newValue, navigationState.selectedSection == .settings else { return }
            navigationState.selectedSection = .home
        }
    }

    private func requestSectionChange(to section: AppSidebarSection) {
        guard navigationState.selectedSection != section else { return }

        if pdfEditingCoordinator.hasUnsavedChanges {
            pendingSection = section
            showSaveConfirm = true
            return
        }

        navigationState.selectedSection = section
    }

    private func applyPendingSection() {
        if let pendingSection {
            navigationState.selectedSection = pendingSection
        }
        self.pendingSection = nil
    }
}

private struct MacSidebar: View {
    @EnvironmentObject private var navigationState: AppNavigationState
    @AppStorage(AppSettings.macReadingAIDialogEnabledKey)
    private var macReadingAIDialogEnabled: Bool = AppSettings.defaultMacReadingAIDialogEnabled
    @AppStorage(AppSettings.macShowMainInterfaceSettingsKey)
    private var showMainInterfaceSettings: Bool = AppSettings.defaultMacShowMainInterfaceSettings
    @AppStorage(AppSettings.macAllowMainFocusSidebarCollapseKey)
    private var macAllowMainFocusSidebarCollapse: Bool = AppSettings.defaultMacAllowMainFocusSidebarCollapse
    @AppStorage(AppSettings.zoteroLinkedDisplayPathKey)
    private var zoteroLinkedDisplayPath: String = AppSettings.defaultLinkedLibraryDisplayPath
    @AppStorage(AppSettings.endNoteLinkedDisplayPathKey)
    private var endNoteLinkedDisplayPath: String = AppSettings.defaultLinkedLibraryDisplayPath
    let onSelectSection: (AppSidebarSection) -> Void

    private var shouldUseReadingAIDialogLayout: Bool {
        navigationState.isReadingModeActive && macReadingAIDialogEnabled
    }

    private var displayedSections: [AppSidebarSection] {
        showMainInterfaceSettings ? AppSidebarSection.allCases : [.home, .library]
    }

    private let collapsedButtonSide: CGFloat = 40
    private let expandedButtonHeight: CGFloat = 40

    private var shouldShowLibraryFolderPane: Bool {
        navigationState.selectedSection == .library
            && !navigationState.isReadingModeActive
    }

    private var shouldShowHomeOverviewPane: Bool {
        navigationState.selectedSection == .home
            && !navigationState.isReadingModeActive
    }

    private var shouldShowReadingAIPane: Bool {
        navigationState.isReadingModeActive && macReadingAIDialogEnabled
    }

    private var shouldAllowMainFocusSidebarCollapse: Bool {
        macAllowMainFocusSidebarCollapse
            && !navigationState.isReadingModeActive
            && (navigationState.selectedSection == .home || navigationState.selectedSection == .library)
    }

    private var shouldShowFocusTimerPane: Bool {
        navigationState.isReadingModeActive || navigationState.selectedSection != .settings
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(displayedSections) { section in
                        sidebarButton(for: section)
                    }
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: navigationState.selectedSection)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: showMainInterfaceSettings)
            }
            .padding(MacSidebarLayout.contentInset)

            Divider()

            if shouldShowHomeOverviewPane {
                MacHomeOverviewPanel()
                    .frame(
                        minHeight: MacSidebarLayout.folderPaneMinimumHeight,
                        maxHeight: .infinity,
                        alignment: .top
                    )

                Divider()
            } else if shouldShowLibraryFolderPane {
                MacLinkedLibrarySidebarPanel()
                    .environmentObject(navigationState)
                    .frame(
                        minHeight: MacSidebarLayout.folderPaneMinimumHeight,
                        maxHeight: .infinity,
                        alignment: .top
                    )

                Divider()
            } else if shouldShowReadingAIPane {
                readingAssistantPane
                    .environmentObject(navigationState)
                    .frame(
                        minHeight: MacSidebarLayout.folderPaneMinimumHeight,
                        maxHeight: .infinity,
                        alignment: .top
                    )

                Divider()
            } else {
                Spacer(minLength: 0)
            }

            if shouldShowFocusTimerPane {
                Group {
                    if shouldUseReadingAIDialogLayout {
                        SidebarFocusTimerView(
                            displayMode: navigationState.isMacAIDialogExpanded ? .compact : .full,
                            showsAssistantToggle: true,
                            fillsAvailableHeight: !navigationState.isMacAIDialogExpanded,
                            onOpenAssistant: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    if navigationState.isMacAIDialogExpanded {
                                        navigationState.collapseMacAIDialog()
                                    } else {
                                        navigationState.presentMacAIDialog()
                                    }
                                }
                            }
                        )
                            .id(navigationState.timerReloadID)
                            .frame(maxWidth: .infinity, alignment: .bottom)
                    } else if navigationState.isReadingModeActive {
                        SidebarFocusTimerView(
                            displayMode: .full,
                            showsAssistantToggle: false,
                            fillsAvailableHeight: false
                        )
                            .environmentObject(navigationState)
                            .id(navigationState.timerReloadID)
                            .frame(maxWidth: .infinity, alignment: .bottom)
                    } else {
                        SidebarFocusTimerView(
                            displayMode: shouldAllowMainFocusSidebarCollapse && !navigationState.isMacFocusSidebarExpanded ? .compact : .full,
                            showsAssistantToggle: shouldAllowMainFocusSidebarCollapse,
                            fillsAvailableHeight: shouldAllowMainFocusSidebarCollapse ? navigationState.isMacFocusSidebarExpanded : true,
                            onOpenAssistant: shouldAllowMainFocusSidebarCollapse ? {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    if navigationState.isMacFocusSidebarExpanded {
                                        navigationState.compactMacFocusSidebar()
                                    } else {
                                        navigationState.expandMacFocusSidebar()
                                    }
                                }
                            } : nil
                        )
                            .environmentObject(navigationState)
                            .id(navigationState.timerReloadID)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
                .padding(MacSidebarLayout.contentInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if !shouldUseReadingAIDialogLayout {
                navigationState.expandMacFocusSidebar()
            } else {
                navigationState.presentMacAIDialog()
            }
        }
        .onChange(of: macReadingAIDialogEnabled) { _, newValue in
            if navigationState.isReadingModeActive {
                if newValue {
                    navigationState.presentMacAIDialog()
                } else {
                    navigationState.collapseMacAIDialog()
                }
            } else {
                navigationState.expandMacFocusSidebar()
            }
        }
        .onChange(of: macAllowMainFocusSidebarCollapse) { _, newValue in
            if !newValue && !navigationState.isReadingModeActive {
                navigationState.expandMacFocusSidebar()
            }
        }
        .onChange(of: navigationState.isReadingModeActive) { _, newValue in
            if newValue {
                if macReadingAIDialogEnabled {
                    navigationState.presentMacAIDialog()
                } else {
                    navigationState.expandMacFocusSidebar()
                }
            } else {
                navigationState.expandMacFocusSidebar()
            }
        }
    }

    private var readingAssistantPane: some View {
        MacReadingAIDialogView(
            isExpanded: Binding(
                get: { navigationState.isMacAIDialogExpanded },
                set: { newValue in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if newValue {
                            navigationState.presentMacAIDialog()
                        } else {
                            navigationState.collapseMacAIDialog()
                        }
                    }
                }
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func sidebarButton(for section: AppSidebarSection) -> some View {
        let isSelected = navigationState.selectedSection == section
        let showsExpandedLabel = !showMainInterfaceSettings || isSelected

        Button {
            onSelectSection(section)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 18)

                if showsExpandedLabel {
                    Text(section.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .frame(
                width: showsExpandedLabel ? expandedButtonWidth(for: section) : collapsedButtonSide,
                height: expandedButtonHeight,
                alignment: .center
            )
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.24) : Color.secondary.opacity(0.12),
                        lineWidth: 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(section.title)
    }

    private func expandedButtonWidth(for section: AppSidebarSection) -> CGFloat {
        switch section {
        case .home:
            return 98
        case .library:
            return 104
        case .settings:
            return 98
        }
    }
}

private struct MacLinkedLibrarySidebarPanel: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationState: AppNavigationState
    @Query(sort: \Paper.createdAt, order: .reverse) private var papers: [Paper]

    @AppStorage(AppSettings.zoteroLinkedDisplayPathKey)
    private var zoteroLinkedDisplayPath: String = AppSettings.defaultLinkedLibraryDisplayPath
    @AppStorage(AppSettings.endNoteLinkedDisplayPathKey)
    private var endNoteLinkedDisplayPath: String = AppSettings.defaultLinkedLibraryDisplayPath
    @AppStorage(AppSettings.zoteroLinkedDisplayNameKey)
    private var zoteroLinkedDisplayName: String = AppSettings.defaultLinkedLibraryDisplayName
    @AppStorage(AppSettings.endNoteLinkedDisplayNameKey)
    private var endNoteLinkedDisplayName: String = AppSettings.defaultLinkedLibraryDisplayName
    @AppStorage(AppSettings.zoteroSoleLibraryKey)
    private var zoteroSoleLibrary = AppSettings.defaultZoteroSoleLibrary

    @State private var isRefreshingLinkedLibrary = false
    @State private var panelMessage = ""
    @State private var showPanelAlert = false

    private let libraryImportService = LibraryImportService()

    private var activeFilter: LibrarySidebarFilter {
        navigationState.selectedLibrarySidebarFilter
    }

    private var availablePapers: [Paper] {
        zoteroSoleLibrary ? papers.filter { $0.sourceLibraryType == "zotero" } : papers
    }

    private var sections: [MacLinkedLibrarySection] {
        var result: [MacLinkedLibrarySection] = [
            MacLinkedLibrarySection(
                items: [
                    MacLinkedLibraryItem(
                        title: AppSettings.localizedString("全部条目"),
                        icon: "doc.text",
                        tint: .accentColor,
                        count: availablePapers.filter { !$0.isInTrash }.count,
                        level: 0,
                        filter: .all
                    )
                ]
            )
        ]

        if !zoteroLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(makeSection(for: "zotero", title: AppSettings.localizedString("我的文库"), tint: .blue))
        }

        if !zoteroSoleLibrary, !endNoteLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(makeSection(for: "endnote", title: AppSettings.localizedString("EndNote 文库"), tint: .orange))
        }

        return result
    }

    private var hasLinkedLibrary: Bool {
        !zoteroLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !endNoteLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("文库")
                        .font(.headline)

                    Spacer()

                    Button {
                        refreshLinkedLibraries()
                    } label: {
                        if isRefreshingLinkedLibrary {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasLinkedLibrary || isRefreshingLinkedLibrary)
                    .help(hasLinkedLibrary ? AppSettings.localizedString("同步本地文献库") : AppSettings.localizedString("当前还没有可同步的本地文献库"))
                }
                .frame(minWidth: MacSidebarLayout.panelContentMinWidth, maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MacSidebarLayout.contentInset)
                .padding(.top, MacSidebarLayout.contentInset)

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(section.items) { item in
                            row(for: item)
                        }
                    }
                    .frame(minWidth: MacSidebarLayout.panelContentMinWidth, maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, MacSidebarLayout.contentInset - 2)
                }

                if !hasLinkedLibrary {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("还没有关联本地文献库")
                            .font(.subheadline.weight(.semibold))
                        Text("在设置里关联 Zotero 或 EndNote 后，这里会显示文件夹、未分类、回收站等文库结构。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(minWidth: MacSidebarLayout.panelContentMinWidth, maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, MacSidebarLayout.contentInset)
                    .padding(.top, 6)

                    HStack(spacing: 10) {
                        Button("关联 Zotero") {
                            linkZoteroLibrary()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("关联 EndNote") {
                            linkEndNoteLibrary()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(minWidth: MacSidebarLayout.panelContentMinWidth, maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, MacSidebarLayout.contentInset)
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.bottom, MacSidebarLayout.contentInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("文库", isPresented: $showPanelAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(panelMessage)
        }
    }

    private func row(for item: MacLinkedLibraryItem) -> some View {
        Button {
            navigationState.selectedLibrarySidebarFilter = item.filter
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .foregroundStyle(item.tint)
                    .frame(width: 16)

                Text(item.title)
                    .font(.system(size: 13, weight: activeFilter == item.filter ? .semibold : .regular))
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text("\(item.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 7)
            .padding(.leading, CGFloat(10 + item.level * 14))
            .padding(.trailing, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(activeFilter == item.filter ? Color.secondary.opacity(0.14) : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(item.title)
    }

    private func makeSection(for sourceType: String, title: String, tint: Color) -> MacLinkedLibrarySection {
        let sourcePapers = availablePapers.filter { $0.sourceLibraryType == sourceType }
        var items: [MacLinkedLibraryItem] = [
            MacLinkedLibraryItem(
                title: title,
                icon: "building.columns",
                tint: tint,
                count: sourcePapers.filter { !$0.isInTrash }.count,
                level: 0,
                filter: .linkedLibrary(sourceType)
            )
        ]

        items.append(contentsOf: collectionItems(for: sourceType, tint: tint))

        if sourceType == "zotero" {
            items.append(
                MacLinkedLibraryItem(
                    title: AppSettings.localizedString("我的出版物"),
                    icon: "doc.badge.gearshape",
                    tint: .green,
                    count: sourcePapers.filter { $0.isPublicationItem && !$0.isInTrash }.count,
                    level: 1,
                    filter: .publications(sourceType)
                )
            )
            items.append(
                MacLinkedLibraryItem(
                    title: AppSettings.localizedString("重复条目"),
                    icon: "square.on.square",
                    tint: .orange,
                    count: duplicatePaperIDs(for: sourceType).count,
                    level: 1,
                    filter: .duplicates(sourceType)
                )
            )
            items.append(
                MacLinkedLibraryItem(
                    title: AppSettings.localizedString("未分类条目"),
                    icon: "doc.on.doc",
                    tint: .orange,
                    count: sourcePapers.filter { $0.isUnfiled && !$0.isInTrash }.count,
                    level: 1,
                    filter: .unfiled(sourceType)
                )
            )
            items.append(
                MacLinkedLibraryItem(
                    title: AppSettings.localizedString("回收站"),
                    icon: "trash",
                    tint: .red,
                    count: sourcePapers.filter { $0.isInTrash }.count,
                    level: 1,
                    filter: .trash(sourceType)
                )
            )
        }

        return MacLinkedLibrarySection(items: items)
    }

    private func collectionItems(for sourceType: String, tint: Color) -> [MacLinkedLibraryItem] {
        let sourcePapers = availablePapers.filter { $0.sourceLibraryType == sourceType && !$0.isInTrash }
        let paths = sourcePapers
            .flatMap(\.collectionList)
            .filter { !$0.isEmpty }

        let uniquePaths = Array(Set(paths)).sorted()
        return uniquePaths.map { path in
            let level = max(1, path.split(separator: "/").count)
            return MacLinkedLibraryItem(
                title: path.split(separator: "/").last.map(String.init) ?? path,
                icon: "folder",
                tint: tint,
                count: sourcePapers.filter { paper in
                    paper.collectionList.contains(where: { $0 == path || $0.hasPrefix(path + "/") })
                }.count,
                level: level,
                filter: .collection(sourceType: sourceType, path: path)
            )
        }
    }

    private func duplicatePaperIDs(for sourceType: String) -> Set<String> {
        let sourcePapers = availablePapers.filter { $0.sourceLibraryType == sourceType && !$0.isInTrash }
        let groups = Dictionary(grouping: sourcePapers) { paper in
            if !paper.doi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "doi:\(paper.doi.lowercased())"
            }

            let normalizedTitle = paper.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedAuthors = paper.authors.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let yearPart = paper.year.map(String.init) ?? "noyear"
            return "text:\(normalizedTitle)|\(normalizedAuthors)|\(yearPart)"
        }

        return Set(groups.values.filter { $0.count > 1 }.flatMap { $0.map(\.uuid) })
    }

    private func refreshLinkedLibraries() {
        guard hasLinkedLibrary, !isRefreshingLinkedLibrary else { return }

        isRefreshingLinkedLibrary = true

        Task {
            defer { isRefreshingLinkedLibrary = false }

            do {
                var messages: [String] = []

                if !zoteroLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let summary = try await libraryImportService.refreshLinkedZoteroLibrary(into: modelContext)
                    messages.append(AppSettings.localizedFormat("Zotero：%@", defaultValue: "Zotero: %@", summary.syncMessage))
                }

                if !endNoteLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let summary = try await libraryImportService.refreshLinkedEndNoteXML(
                        from: endNoteLinkedDisplayPath,
                        into: modelContext
                    )
                    messages.append(AppSettings.localizedFormat("EndNote：%@", defaultValue: "EndNote: %@", summary.syncMessage))
                }

                panelMessage = messages.joined(separator: "\n")
                showPanelAlert = !panelMessage.isEmpty
            } catch {
                panelMessage = error.localizedDescription
                showPanelAlert = true
            }
        }
    }

    private func linkZoteroLibrary() {
        NotificationCenter.default.post(name: .appMenuLibraryCommand, object: AppMenuLibraryCommand.linkZotero)
    }

    private func linkEndNoteLibrary() {
        NotificationCenter.default.post(name: .appMenuLibraryCommand, object: AppMenuLibraryCommand.linkEndNote)
    }

    private func chooseFile(title: String, prompt: String, contentTypes: [UTType]) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = contentTypes

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private func chooseZoteroLibraryLocation(title: String, prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}

private struct MacHomeOverviewPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appearsActive) private var appearsActive
    @Query(sort: \Paper.createdAt, order: .reverse) private var papers: [Paper]
    @Query(sort: \FocusTask.createdAt, order: .reverse) private var focusTasks: [FocusTask]
    @AppStorage(AppSettings.zoteroSoleLibraryKey)
    private var zoteroSoleLibrary = AppSettings.defaultZoteroSoleLibrary

    private var catalogPapers: [Paper] {
        zoteroSoleLibrary ? papers.filter { $0.sourceLibraryType == "zotero" } : papers
    }

    private var effectiveCompletedTasks: [FocusTask] {
        focusTasks
            .filter { $0.state == .completed && $0.isEffectiveRecord }
            .sorted { ($0.finishedAt ?? $0.createdAt) > ($1.finishedAt ?? $1.createdAt) }
    }

    private var todayEffectiveCount: Int {
        let calendar = Calendar.current
        return effectiveCompletedTasks.filter {
            guard let finishedAt = $0.finishedAt else { return false }
            return calendar.isDateInToday(finishedAt)
        }.count
    }

    private var todayMinutes: Int {
        let calendar = Calendar.current
        return effectiveCompletedTasks.reduce(0) { partial, task in
            guard let finishedAt = task.finishedAt, calendar.isDateInToday(finishedAt) else {
                return partial
            }
            return partial + task.elapsedMinutes
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack {
                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("总览")
                            .font(.headline)
                            .frame(minWidth: MacSidebarLayout.panelContentMinWidth, maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 10) {
                            statsRow(
                                title: "总文献",
                                value: "\(catalogPapers.count)",
                                secondaryTitle: "有效专注",
                                secondaryValue: "\(effectiveCompletedTasks.count)"
                            )

                            statsRow(
                                title: "今日完成",
                                value: "\(todayEffectiveCount)",
                                secondaryTitle: "今日分钟",
                                secondaryValue: "\(todayMinutes)"
                            )
                        }
                        .frame(minWidth: MacSidebarLayout.panelContentMinWidth, maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, MacSidebarLayout.contentInset)
                    .padding(.vertical, 8)

                    Spacer(minLength: 0)
                }
                .frame(minHeight: proxy.size.height)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func statsRow(title: LocalizedStringKey, value: String, secondaryTitle: LocalizedStringKey, secondaryValue: String) -> some View {
        HStack(spacing: 10) {
            statCard(title: title, value: value)
            statCard(title: secondaryTitle, value: secondaryValue)
        }
        .frame(minWidth: MacSidebarLayout.panelContentMinWidth, maxWidth: .infinity, alignment: .center)
    }

    private func statCard(title: LocalizedStringKey, value: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        return VStack(spacing: 6) {
            Text(value)
                .font(.title3.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 72)
        .padding(.vertical, 10)
        .background(overviewStatCardBackground(shape: shape))
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.45),
                lineWidth: 0.8
            )
        )
    }

    @ViewBuilder
    private func overviewStatCardBackground(shape: RoundedRectangle) -> some View {
        #if os(macOS)
        if #available(macOS 26.0, *) {
            MacNativeOverviewGlassBackground(
                cornerRadius: 14,
                colorScheme: colorScheme,
                isWindowActive: appearsActive
            )
        } else {
            shape.fill(.thinMaterial)
        }
        #else
        shape.fill(.thinMaterial)
        #endif
    }
}

@available(macOS 26.0, *)
private struct MacNativeOverviewGlassBackground: NSViewRepresentable {
    let cornerRadius: CGFloat
    let colorScheme: ColorScheme
    let isWindowActive: Bool

    func makeNSView(context: Context) -> NSGlassEffectContainerView {
        let container = NSGlassEffectContainerView()
        container.spacing = 0
        container.wantsLayer = true

        let contentHost = NSView()
        contentHost.translatesAutoresizingMaskIntoConstraints = false
        container.contentView = contentHost

        let glassView = NSGlassEffectView()
        glassView.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(glassView)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            glassView.topAnchor.constraint(equalTo: contentHost.topAnchor),
            glassView.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor)
        ])

        context.coordinator.glassView = glassView
        updateGlassView(glassView)
        return container
    }

    func updateNSView(_ nsView: NSGlassEffectContainerView, context: Context) {
        if let glassView = context.coordinator.glassView {
            updateGlassView(glassView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func updateGlassView(_ glassView: NSGlassEffectView) {
        glassView.style = .regular
        glassView.cornerRadius = cornerRadius
        glassView.wantsLayer = true
        glassView.layer?.cornerCurve = .continuous
        glassView.layer?.masksToBounds = true
        glassView.tintColor = tintColor
    }

    private var tintColor: NSColor {
        if colorScheme == .dark {
            return NSColor(calibratedWhite: 0.02, alpha: isWindowActive ? 0.10 : 0.05)
        }
        return NSColor(calibratedWhite: 1.0, alpha: isWindowActive ? 0.10 : 0.04)
    }

    final class Coordinator {
        var glassView: NSGlassEffectView?
    }
}

private struct MacLinkedLibrarySection: Identifiable {
    let id = UUID()
    let items: [MacLinkedLibraryItem]
}

private struct MacLinkedLibraryItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    let count: Int
    let level: Int
    let filter: LibrarySidebarFilter
}
#endif

#Preview {
    RootTabView()
}
