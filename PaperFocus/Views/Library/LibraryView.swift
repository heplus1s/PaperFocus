//
//  LibraryView.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

//
//  LibraryView.swift
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

private enum LibraryStatusFilter: String, CaseIterable, Identifiable {
    case all
    case unread
    case skimmed
    case reading
    case finished

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return AppSettings.localizedString("全部")
        case .unread:
            return PaperStatus.unread.displayName
        case .skimmed:
            return PaperStatus.skimmed.displayName
        case .reading:
            return PaperStatus.reading.displayName
        case .finished:
            return PaperStatus.finished.displayName
        }
    }

    var paperStatus: PaperStatus? {
        switch self {
        case .all:
            return nil
        case .unread:
            return .unread
        case .skimmed:
            return .skimmed
        case .reading:
            return .reading
        case .finished:
            return .finished
        }
    }
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationState: AppNavigationState

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @Query(sort: \Paper.createdAt, order: .reverse) private var queriedPapers: [Paper]
    @Query(sort: \FocusTask.createdAt, order: .reverse) private var focusTasks: [FocusTask]

    @State private var searchText: String = ""
    @State private var selectedStatus: LibraryStatusFilter = .all
    @State private var selectedPaperID: PersistentIdentifier?
    @State private var papersCache: [Paper] = []
    @State private var hasAttemptedInitialLinkedSync = false

    @State private var isImportingPDF = false
    @State private var showImportModes = false
    @State private var importMode: LibraryImportMode = .zotero
    @State private var stagedImportURL: URL?
    @State private var isRefreshingLinkedLibrary = false
    @State private var errorMessage: String = ""
    @State private var showErrorAlert = false
    @State private var showAddPaperSheet = false
    @ObservedObject private var pdfEditingCoordinator = PDFEditingCoordinator.shared
    @State private var showLeaveReadingSaveConfirm = false
    @State private var pendingLeaveReadingMode = false

    #if os(iOS)
    @State private var showPDFPicker = false
    #endif

    @AppStorage(AppSettings.minimumEffectiveMinutesKey)
    private var minimumEffectiveMinutes: Int = AppSettings.defaultMinimumEffectiveMinutes

    @AppStorage(AppSettings.paperSummaryProviderKey)
    private var paperSummaryProvider: String = AppSettings.defaultPaperSummaryProvider

    @AppStorage(AppSettings.paperSummaryExternalEndpointKey)
    private var paperSummaryExternalEndpoint: String = AppSettings.defaultPaperSummaryExternalEndpoint

    @AppStorage(AppSettings.paperSummaryExternalAPIKey)
    private var paperSummaryExternalAPIKey: String = AppSettings.defaultPaperSummaryExternalAPIKey

    @AppStorage(AppSettings.paperSummaryExternalModelKey)
    private var paperSummaryExternalModel: String = AppSettings.defaultPaperSummaryExternalModel
    @AppStorage(AppSettings.zoteroLinkedDisplayPathKey)
    private var zoteroLinkedDisplayPath: String = AppSettings.defaultLinkedLibraryDisplayPath
    @AppStorage(AppSettings.endNoteLinkedDisplayPathKey)
    private var endNoteLinkedDisplayPath: String = AppSettings.defaultLinkedLibraryDisplayPath
    @AppStorage(AppSettings.zoteroSoleLibraryKey)
    private var zoteroSoleLibrary = AppSettings.defaultZoteroSoleLibrary

    @State private var isGeneratingSummary = false
    @State private var summaryText = ""
    @State private var summaryPaperUUID = ""
    @State private var librarySyncHint = ""
    @State private var librarySyncHintToken = UUID()

    private let statusOptions = LibraryStatusFilter.allCases
    private let importer = PaperMetadataImporter()
    private let libraryImportService = LibraryImportService()

    private var selectedSidebarFilter: LibrarySidebarFilter {
        get { navigationState.selectedLibrarySidebarFilter }
        nonmutating set { navigationState.selectedLibrarySidebarFilter = newValue }
    }

    private var filteredPapers: [Paper] {
        papersCache.filter { paper in
            let matchesSidebar = matchesSidebarFilter(paper)
            let matchesStatus = selectedStatus.paperStatus.map { paper.status == $0 } ?? true

            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch: Bool

            if trimmedSearch.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch =
                    paper.title.localizedCaseInsensitiveContains(trimmedSearch) ||
                    paper.authors.localizedCaseInsensitiveContains(trimmedSearch) ||
                    paper.journal.localizedCaseInsensitiveContains(trimmedSearch) ||
                    paper.doi.localizedCaseInsensitiveContains(trimmedSearch) ||
                    paper.collectionPath.localizedCaseInsensitiveContains(trimmedSearch) ||
                    paper.collectionsText.localizedCaseInsensitiveContains(trimmedSearch) ||
                    paper.sourceLibraryName.localizedCaseInsensitiveContains(trimmedSearch)
            }

            return matchesSidebar && matchesStatus && matchesSearch
        }
    }

    private var effectiveSelectedPaperID: PersistentIdentifier? {
        selectedPaperID ?? navigationState.selectedPaperID
    }

    private var selectedPaper: Paper? {
        guard let id = effectiveSelectedPaperID else { return nil }

        return filteredPapers.first { $0.persistentModelID == id }
            ?? papersCache.first { $0.persistentModelID == id }
    }

    private var activeFocusTask: FocusTask? {
        guard let id = navigationState.activeFocusTaskID else { return nil }
        return focusTasks.first { $0.persistentModelID == id }
    }

    private func focusTaskMatchesPaper(_ focusTask: FocusTask, paper: Paper) -> Bool {
        if let taskPaper = focusTask.paper {
            return taskPaper.persistentModelID == paper.persistentModelID
        }

        return focusTask.paperTitleSnapshot == paper.displayTitle
    }

    private var shouldShowResumeToolbarButton: Bool {
        !navigationState.isReadingModeActive && navigationState.isResumeAvailable
    }

    private var hasLinkedLibrary: Bool {
        !zoteroLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !endNoteLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSummarizeSelectedPaper: Bool {
        guard let selectedPaper else { return false }
        return selectedPaper.pdfURL != nil
    }

    private var navigationTitleText: String {
        #if os(iOS)
        if navigationState.isReadingModeActive {
            return ""
        } else {
            return AppSettings.localizedString("文献库")
        }
        #else
        if navigationState.isReadingModeActive, let selectedPaper {
            return selectedPaper.displayTitle
        } else {
            return AppSettings.localizedString("文献库")
        }
        #endif
    }

    #if os(iOS)
    private var isCompactLibraryLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var shouldShowInspectorPane: Bool {
        !navigationState.isReadingModeActive && !isCompactLibraryLayout
    }
    #else
    private var shouldShowInspectorPane: Bool {
        !navigationState.isReadingModeActive
    }
    #endif

    var body: some View {
        HStack(spacing: 0) {
            centerPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if shouldShowInspectorPane {
                Divider()

                PaperInspectorView(
                    paper: selectedPaper,
                    summaryText: summaryText,
                    isGeneratingSummary: isGeneratingSummary,
                    canSummarize: canSummarizeSelectedPaper,
                    onGenerateSummary: generateSummaryForSelectedPaper
                )
                    .frame(width: 360)
                    .frame(maxHeight: .infinity)
                    .clipped()
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showPDFPicker) {
            PDFPicker { url in
                showPDFPicker = false
                Task {
                    try? await importPDFFiles([url])
                }
            }
        }
        #endif
        .sheet(isPresented: $showAddPaperSheet) {
            AddPaperView { title, authors, year, statusRaw, pdfPath in
                var finalPDFPath = ""
                var finalPDFFileName = ""

                if !pdfPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    do {
                        let sourceURL = URL(fileURLWithPath: pdfPath)
                        if AppSettings.importCopiesAttachments {
                            let importedURL = try PaperFileService.importPDFToLibrary(from: sourceURL)
                            finalPDFPath = importedURL.path
                            finalPDFFileName = importedURL.lastPathComponent
                        } else {
                            finalPDFPath = sourceURL.path
                            finalPDFFileName = sourceURL.lastPathComponent
                        }
                    } catch {
                        errorMessage = AppSettings.localizedFormat(
                            "导入手动选择的 PDF 失败：%@",
                            defaultValue: "Import selected PDF failed: %@",
                            error.localizedDescription
                        )
                        showErrorAlert = true
                        return
                    }
                }

                let paper = Paper(
                    title: title,
                    authors: authors,
                    journal: "",
                    year: year,
                    doi: "",
                    pdfPath: finalPDFPath,
                    statusRaw: statusRaw
                )

                paper.hasPDF = !finalPDFPath.isEmpty
                paper.pdfFileName = finalPDFFileName
                paper.importMethod = "manual"
                paper.databaseSource = "Manual"
                paper.citationKey = makeCitationKey(
                    authors: authors,
                    title: title,
                    year: year
                )
                paper.updatedAt = .now

                savePaper(paper)
            }
        }
        .alert("操作失败", isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog("当前 PDF 标注尚未保存", isPresented: $showLeaveReadingSaveConfirm, titleVisibility: .visible) {
            Button("保存并返回") {
                _ = pdfEditingCoordinator.saveActiveDocument()
                performExitReadingMode()
            }

            Button("不保存返回", role: .destructive) {
                pdfEditingCoordinator.discardUnsavedState()
                performExitReadingMode()
            }

            Button("取消", role: .cancel) {
                pendingLeaveReadingMode = false
            }
        } message: {
            Text("当前 PDF 有未保存修改。返回文献列表前是否先保存？")
        }
        .toolbar {
            if navigationState.isReadingModeActive {
                ToolbarItem(placement: .navigation) {
                    Button {
                        requestExitReadingMode()
                    } label: {
                        #if os(iOS)
                        Image(systemName: "chevron.left")
                        #else
                        Label("返回", systemImage: "chevron.left")
                        #endif
                    }
                }
            } else {
                #if os(macOS)
                if #available(macOS 26.0, *) {
                    ToolbarItem(placement: .navigation) {
                        toolbarLeadingPlaceholder
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .navigation) {
                        toolbarLeadingPlaceholder
                    }
                }
                #else
                ToolbarItem(placement: .navigation) {
                    toolbarLeadingPlaceholder
                }
                #endif
            }

            #if !os(macOS)
            ToolbarItem(placement: .principal) {
                if !navigationState.isReadingModeActive {
                    if shouldShowResumeToolbarButton {
                        ResumeFocusToolbarButton(title: navigationState.resumablePaperTitle) {
                            navigationState.resumeLastReading()
                        }
                    }
                }
            }
            #endif

            if !navigationState.isReadingModeActive {
                ToolbarItemGroup(placement: .automatic) {
                    #if os(macOS)
                    if shouldShowResumeToolbarButton {
                        ResumeFocusToolbarButton(title: navigationState.resumablePaperTitle) {
                            navigationState.resumeLastReading()
                        }
                    }
                    #endif

                    Button {
                        importMode = .zotero
                        stagedImportURL = nil
                        showImportModes = true
                    } label: {
                        #if os(iOS)
                        if isCompactLibraryLayout {
                            Image(systemName: "square.and.arrow.down")
                        } else {
                            Label("导入", systemImage: "square.and.arrow.down")
                        }
                        #else
                        Label("导入", systemImage: "square.and.arrow.down")
                        #endif
                    }

                    Button {
                        generateSummaryForSelectedPaper()
                    } label: {
                        if isGeneratingSummary {
                            Label("汇总中", systemImage: "sparkles")
                        } else {
                            Label("AI 汇总", systemImage: "sparkles")
                        }
                    }
                    .disabled(!canSummarizeSelectedPaper || isGeneratingSummary)

                    Button {
                        openSelectedPaperInApp()
                    } label: {
                        Label("打开 PDF", systemImage: "doc.richtext")
                    }
                    .disabled(selectedPaper?.pdfPath.isEmpty ?? true)

                    Button(role: .destructive) {
                        deleteSelectedPaper()
                    } label: {
                        Label("删除文献", systemImage: "trash")
                    }
                    .disabled(selectedPaper == nil)
                }
            }
        }
        .onAppear {
            refreshPapersFromStore()
            syncLinkedLibrariesIfNeeded(force: false)

            if selectedPaperID == nil {
                selectedPaperID = navigationState.selectedPaperID
            }

            if let paper = selectedPaper {
                navigationState.selectedPaperID = paper.persistentModelID
                navigationState.prepareTimer(for: paper.displayTitle)
            }
        }
        .onChange(of: selectedPaperID) { _, newValue in
            navigationState.selectedPaperID = newValue

            guard let newValue else {
                summaryText = ""
                summaryPaperUUID = ""
                return
            }

            guard let paper = papersCache.first(where: { $0.persistentModelID == newValue })
            else { return }

            if summaryPaperUUID != paper.uuid {
                summaryText = ""
                summaryPaperUUID = ""
            }

            if navigationState.timerDraftTitle != paper.displayTitle {
                navigationState.prepareTimer(for: paper.displayTitle)
            }
        }
        .onChange(of: navigationState.selectedPaperID) { _, newValue in
            if selectedPaperID != newValue {
                selectedPaperID = newValue
            }
        }
        .onChange(of: queriedPapers.count) { _, _ in
            refreshPapersFromStore()
        }
        .onChange(of: zoteroLinkedDisplayPath) { _, _ in
            selectedSidebarFilter = .all
            syncLinkedLibrariesIfNeeded(force: true)
        }
        .onChange(of: endNoteLinkedDisplayPath) { _, _ in
            selectedSidebarFilter = .all
            syncLinkedLibrariesIfNeeded(force: true)
        }
        .onChange(of: zoteroSoleLibrary) { _, _ in
            refreshPapersFromStore()
        }
        .sheet(isPresented: $showImportModes) {
            LibraryImportModeSheet(
                initialMode: importMode,
                stagedURL: stagedImportURL,
                importPDFs: { urls in
                    try await importPDFFiles(urls)
                },
                onFinished: { message in
                    showLibrarySyncHint(message)
                    refreshPapersFromStore()
                }
            )
        }
        .navigationTitle(navigationTitleText)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(navigationState.isReadingModeActive ? .hidden : .visible, for: .tabBar)
        #endif
    }

    @ViewBuilder
    private var centerPane: some View {
        if navigationState.isReadingModeActive,
           let paper = selectedPaper {
            readingPane(for: paper)
        } else {
            libraryListPane
        }
    }

    private var libraryListPane: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                #if os(macOS)
                if shouldShowFolderSidebar {
                    librarySidebar
                        .frame(width: min(max(proxy.size.width * 0.26, 220), 300))

                    Divider()
                }
                #endif

                libraryContentPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var libraryContentPane: some View {
        VStack(spacing: 12) {
            #if os(macOS)
            PaperDropZoneView(isImporting: isImportingPDF) { urls in
                handleDroppedFiles(urls)
            } onRequestImport: {
                importMode = .zotero
                stagedImportURL = nil
                showImportModes = true
            }
            #endif

            HStack(spacing: 12) {
                TextField("搜索标题、作者、期刊或 DOI", text: $searchText)

                Picker("状态筛选", selection: $selectedStatus) {
                    ForEach(statusOptions, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .frame(width: 220)

                if hasLinkedLibrary {
                    Button {
                        refreshLinkedLibraries()
                    } label: {
                        if isRefreshingLinkedLibrary {
                            Label("同步中", systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label("同步库", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isRefreshingLinkedLibrary)
                }
            }

            if !librarySyncHint.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(librarySyncHint)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if filteredPapers.isEmpty {
                VStack {
                    Spacer()

                    ContentUnavailableView(
                        "没有匹配的文献",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(emptyDescription)
                    )

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                paperListView
            }
        }
        .padding()
    }

    @ViewBuilder
    private func readingPane(for paper: Paper) -> some View {
        Group {
            if let pdfURL = paper.pdfURL {
                PDFPreviewView(
                    url: pdfURL,
                    title: paper.displayTitle
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "未关联 PDF",
                    systemImage: "doc.richtext",
                    description: Text("这篇文献当前没有可预览的 PDF 文件。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.background)
    }

    @ViewBuilder
    private var paperListView: some View {
        #if os(macOS)
        Table(filteredPapers, selection: $selectedPaperID) {
            TableColumn("状态") { paper in
                Text(paper.status.displayName)
                    .lineLimit(1)
                    .foregroundStyle(paper.status.color)
            }
            .width(min: 70, ideal: 80, max: 90)

            TableColumn("标题") { paper in
                Text(paper.displayTitle)
                    .lineLimit(2)
            }
            .width(min: 260, ideal: 360)

            TableColumn("作者") { paper in
                Text(paper.displayAuthors)
                    .lineLimit(2)
            }
            .width(min: 180, ideal: 240)

            TableColumn("期刊名") { paper in
                Text(paper.displayJournal)
                    .lineLimit(2)
            }
            .width(min: 140, ideal: 200)

            TableColumn("年份") { paper in
                Text(paper.displayYear)
            }
            .width(min: 60, ideal: 70, max: 80)

            TableColumn("文件夹") { paper in
                Text(paper.displayCollectionPath)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
            .width(min: 160, ideal: 220)
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { selection in
            if let id = selection.first,
               let paper = papersCache.first(where: { $0.persistentModelID == id }) {
                Button("在应用内阅读") {
                    openPaperInApp(paper)
                }

                Button("删除", role: .destructive) {
                    deletePaper(paper)
                }
            }
        } primaryAction: { selection in
            if let id = selection.first,
               let paper = papersCache.first(where: { $0.persistentModelID == id }) {
                openPaperInApp(paper)
            }
        }
        #else
        List(filteredPapers, selection: $selectedPaperID) { paper in
            Button {
                selectedPaperID = paper.persistentModelID
                openPaperInApp(paper)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(paper.displayTitle)
                            .font(.headline)
                        Spacer()
                        Text(paper.status.displayName)
                            .font(.caption)
                            .foregroundStyle(paper.status.color)
                    }

                    Text("\(paper.displayAuthors) · \(paper.displayYear)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if paper.displayJournal != "—" {
                        Text(paper.displayJournal)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if paper.displayCollectionPath != "—" {
                        Text(paper.displayCollectionPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        #endif
    }

    private var emptyDescription: String {
        if hasLinkedLibrary && selectedSidebarFilter != .all {
            return AppSettings.localizedString("当前分类下还没有匹配文献，请尝试切换文件夹、同步本地文献库，或修改搜索词。")
        }

        #if os(macOS)
        if papersCache.isEmpty {
            if zoteroSoleLibrary {
                return AppSettings.localizedString("已停用应用内文献库。请关联 Zotero 文献库后查看条目。")
            }
            return AppSettings.localizedString("当前还没有文献。请使用导入按钮选择 PDF、Zotero、EndNote 或 PaperFocus 文献库。")
        } else {
            return AppSettings.localizedString("请尝试修改搜索词或状态筛选条件。")
        }
        #else
        if papersCache.isEmpty {
            if zoteroSoleLibrary {
                return AppSettings.localizedString("已停用应用内文献库。请关联 Zotero 文献库后查看条目。")
            }
            return AppSettings.localizedString("当前还没有文献。请使用导入按钮选择 PDF、Zotero、EndNote 或 PaperFocus 文献库。")
        } else {
            return AppSettings.localizedString("请尝试修改搜索词或状态筛选条件。")
        }
        #endif
    }

    @ViewBuilder
    private var toolbarLeadingPlaceholder: some View {
        #if os(macOS)
        Color.clear
            .frame(width: 60, height: 1)
        #else
        EmptyView()
        #endif
    }

    #if os(macOS)
    private var shouldShowFolderSidebar: Bool {
        false
    }

    private var librarySidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(sidebarSections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: section.icon)
                                .foregroundStyle(section.tint)
                            Text(section.title)
                                .font(.headline)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 12)

                        ForEach(section.items) { item in
                            sidebarRow(for: item)
                        }
                    }
                    .padding(.bottom, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    )
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func sidebarRow(for item: LibrarySidebarItem) -> some View {
        Button {
            selectedSidebarFilter = item.filter
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .foregroundStyle(item.tint)
                    .frame(width: 18)

                Text(item.title)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text("\(item.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 9)
            .padding(.leading, CGFloat(14 + item.level * 16))
            .padding(.trailing, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedSidebarFilter == item.filter ? Color.secondary.opacity(0.18) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var sidebarSections: [LibrarySidebarSection] {
        var sections: [LibrarySidebarSection] = [
            LibrarySidebarSection(
                title: AppSettings.localizedString("全部文献"),
                icon: "books.vertical",
                tint: .accentColor,
                items: [
                    LibrarySidebarItem(
                        title: AppSettings.localizedString("全部条目"),
                        icon: "doc.text",
                        tint: .accentColor,
                        count: papersCache.filter { !$0.isInTrash }.count,
                        level: 0,
                        filter: .all
                    )
                ]
            )
        ]

        if !zoteroLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append(makeLinkedLibrarySection(for: "zotero", title: AppSettings.localizedString("我的文库"), tint: .blue))
        }

        if !zoteroSoleLibrary, !endNoteLinkedDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append(makeLinkedLibrarySection(for: "endnote", title: AppSettings.localizedString("EndNote 文库"), tint: .orange))
        }

        return sections
    }

    private func makeLinkedLibrarySection(for sourceType: String, title: String, tint: Color) -> LibrarySidebarSection {
        let sourcePapers = papersCache.filter { $0.sourceLibraryType == sourceType }
        var items: [LibrarySidebarItem] = [
            LibrarySidebarItem(
                title: title,
                icon: "building.columns",
                tint: tint,
                count: sourcePapers.filter { !$0.isInTrash }.count,
                level: 0,
                filter: .linkedLibrary(sourceType)
            )
        ]

        items.append(contentsOf: collectionSidebarItems(for: sourceType, tint: tint))

        if sourceType == "zotero" {
            items.append(
                LibrarySidebarItem(
                    title: AppSettings.localizedString("我的出版物"),
                    icon: "doc.badge.gearshape",
                    tint: .green,
                    count: sourcePapers.filter { $0.isPublicationItem && !$0.isInTrash }.count,
                    level: 1,
                    filter: .publications(sourceType)
                )
            )
            items.append(
                LibrarySidebarItem(
                    title: AppSettings.localizedString("重复条目"),
                    icon: "square.on.square",
                    tint: .orange,
                    count: duplicatePaperIDs(for: sourceType).count,
                    level: 1,
                    filter: .duplicates(sourceType)
                )
            )
            items.append(
                LibrarySidebarItem(
                    title: AppSettings.localizedString("未分类条目"),
                    icon: "doc.on.doc",
                    tint: .orange,
                    count: sourcePapers.filter { $0.isUnfiled && !$0.isInTrash }.count,
                    level: 1,
                    filter: .unfiled(sourceType)
                )
            )
            items.append(
                LibrarySidebarItem(
                    title: AppSettings.localizedString("回收站"),
                    icon: "trash",
                    tint: .red,
                    count: sourcePapers.filter { $0.isInTrash }.count,
                    level: 1,
                    filter: .trash(sourceType)
                )
            )
        }

        return LibrarySidebarSection(
            title: title,
            icon: sourceType == "zotero" ? "building.columns" : "books.vertical",
            tint: tint,
            items: items
        )
    }

    private func collectionSidebarItems(for sourceType: String, tint: Color) -> [LibrarySidebarItem] {
        let sourcePapers = papersCache.filter { $0.sourceLibraryType == sourceType && !$0.isInTrash }
        let paths = sourcePapers
            .flatMap(\.collectionList)
            .filter { !$0.isEmpty }

        let uniquePaths = Array(Set(paths)).sorted()
        return uniquePaths.map { path in
            let level = max(1, path.split(separator: "/").count)
            return LibrarySidebarItem(
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
    #endif

    private func matchesSidebarFilter(_ paper: Paper) -> Bool {
        switch selectedSidebarFilter {
        case .all:
            return !paper.isInTrash
        case .linkedLibrary(let sourceType):
            return paper.sourceLibraryType == sourceType && !paper.isInTrash
        case .collection(let sourceType, let path):
            return paper.sourceLibraryType == sourceType
                && !paper.isInTrash
                && paper.collectionList.contains(where: { $0 == path || $0.hasPrefix(path + "/") })
        case .publications(let sourceType):
            return paper.sourceLibraryType == sourceType && paper.isPublicationItem && !paper.isInTrash
        case .duplicates(let sourceType):
            return duplicatePaperIDs(for: sourceType).contains(paper.uuid) && !paper.isInTrash
        case .unfiled(let sourceType):
            return paper.sourceLibraryType == sourceType && paper.isUnfiled && !paper.isInTrash
        case .trash(let sourceType):
            return paper.sourceLibraryType == sourceType && paper.isInTrash
        }
    }

    private func duplicatePaperIDs(for sourceType: String) -> Set<String> {
        let sourcePapers = papersCache.filter { $0.sourceLibraryType == sourceType && !$0.isInTrash }
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

    private func syncLinkedLibrariesIfNeeded(force: Bool) {
        guard hasLinkedLibrary else {
            hasAttemptedInitialLinkedSync = true
            return
        }

        // Launch and interval syncs belong to the root view, which honors the
        // user's auto-sync setting. This view only reloads after the linked path changes.
        guard force else {
            hasAttemptedInitialLinkedSync = true
            return
        }

        refreshLinkedLibraries()
    }

    private func refreshLinkedLibraries() {
        guard !isRefreshingLinkedLibrary else { return }

        isRefreshingLinkedLibrary = true
        hasAttemptedInitialLinkedSync = true

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

                refreshPapersFromStore()
                if !messages.isEmpty {
                    showLibrarySyncHint(messages.joined(separator: "；"))
                }
            } catch {
                errorMessage = AppSettings.localizedFormat("同步本地文献库失败：%@", defaultValue: "Sync library failed: %@", error.localizedDescription)
                showErrorAlert = true
            }
        }
    }

    private func showLibrarySyncHint(_ message: String) {
        let token = UUID()
        librarySyncHintToken = token

        withAnimation(.easeInOut(duration: 0.2)) {
            librarySyncHint = message
        }

        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                guard librarySyncHintToken == token else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    librarySyncHint = ""
                }
            }
        }
    }

    private func generateSummaryForSelectedPaper() {
        guard let paper = selectedPaper, let pdfURL = paper.pdfURL else { return }

        isGeneratingSummary = true
        summaryText = ""
        let targetUUID = paper.uuid
        let providerID = paperSummaryProvider
        let externalEndpoint = paperSummaryExternalEndpoint
        let externalAPIKey = paperSummaryExternalAPIKey
        let externalModel = paperSummaryExternalModel

        Task {
            do {
                let accessHandle = SecurityScopedBookmarkStore.shared.beginAccess(forExternalFile: pdfURL)
                defer { SecurityScopedBookmarkStore.shared.endAccess(accessHandle) }
                let extractedText = await Task.detached(priority: .userInitiated) {
                    PDFTextExtractor.extractText(from: pdfURL, maxPages: 8)
                }.value

                let request = PaperSummaryRequest(
                    title: paper.displayTitle,
                    content: extractedText
                )
                let result = try await PaperSummaryService.summarize(
                    request: request,
                    providerID: providerID,
                    externalEndpoint: externalEndpoint,
                    externalAPIKey: externalAPIKey,
                    externalModel: externalModel
                )

                await MainActor.run {
                    guard selectedPaper?.uuid == targetUUID else {
                        isGeneratingSummary = false
                        return
                    }
                    summaryPaperUUID = targetUUID
                    summaryText = result
                    isGeneratingSummary = false
                }
            } catch {
                await MainActor.run {
                    guard selectedPaper?.uuid == targetUUID else {
                        isGeneratingSummary = false
                        return
                    }
                    isGeneratingSummary = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }

    private func finalizePausedTaskBeforeOpening(_ nextPaper: Paper) {
        guard let task = activeFocusTask else { return }
        guard task.state == .paused else { return }

        if focusTaskMatchesPaper(task, paper: nextPaper) {
            return
        }

        task.startedAt = nil
        task.pausedAt = nil
        task.finishedAt = .now

        let reachedThreshold = task.elapsedMinutes >= minimumEffectiveMinutes

        if reachedThreshold {
            task.isEffectiveRecord = true
            task.state = .completed
        } else {
            task.isEffectiveRecord = false
            task.state = .cancelled
        }

        do {
            try modelContext.save()
            navigationState.activeFocusTaskID = nil
        } catch {
            errorMessage = AppSettings.localizedFormat("结束上一轮阅读记录失败：%@", defaultValue: "Finish previous session failed: %@", error.localizedDescription)
            showErrorAlert = true
        }
    }

    private func openPaperInApp(_ paper: Paper) {
        finalizePausedTaskBeforeOpening(paper)

        if paper.status == .unread {
            paper.status = .reading
        }
        paper.lastOpenedAt = .now

        do {
            try modelContext.save()
        } catch {
            errorMessage = AppSettings.localizedFormat("更新文献阅读状态失败：%@", defaultValue: "Update reading status failed: %@", error.localizedDescription)
            showErrorAlert = true
        }

        selectedPaperID = paper.persistentModelID
        navigationState.selectedPaperID = paper.persistentModelID
        navigationState.prepareTimer(for: paper.displayTitle)
        navigationState.isReadingModeActive = true
    }

    private func openSelectedPaperInApp() {
        guard let selectedPaper else { return }
        openPaperInApp(selectedPaper)
    }

    private func exitReadingMode() {
        pauseActiveTaskIfNeeded()

        if let paper = selectedPaper {
            navigationState.markResumable(
                paperID: paper.persistentModelID,
                title: paper.displayTitle
            )
        }

        navigationState.isReadingModeActive = false
    }

    private func requestExitReadingMode() {
        if pdfEditingCoordinator.hasUnsavedChanges {
            pendingLeaveReadingMode = true
            showLeaveReadingSaveConfirm = true
            return
        }

        performExitReadingMode()
    }

    private func performExitReadingMode() {
        pendingLeaveReadingMode = false
        exitReadingMode()
    }

    private func pauseActiveTaskIfNeeded() {
        guard let task = activeFocusTask, task.state == .running else { return }

        let additionalSeconds: Int
        if let startedAt = task.startedAt {
            additionalSeconds = max(0, Int(Date().timeIntervalSince(startedAt)))
        } else {
            additionalSeconds = 0
        }

        task.elapsedSeconds += additionalSeconds
        task.startedAt = nil
        task.pausedAt = .now
        task.state = .paused

        do {
            try modelContext.save()
        } catch {
            errorMessage = AppSettings.localizedFormat("暂停阅读任务失败：%@", defaultValue: "Pause reading task failed: %@", error.localizedDescription)
            showErrorAlert = true
        }
    }

    private func importOnePDF(_ url: URL) async throws {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let shouldCopy = AppSettings.importCopiesAttachments
        let storedURL: URL
        if shouldCopy {
            storedURL = try await Task.detached(priority: .userInitiated) {
                try PaperFileService.importPDFToLibrary(from: url)
            }.value
        } else {
            storedURL = url
        }

        let fallbackTitle = storedURL.deletingPathExtension().lastPathComponent
        let paper = Paper(
            title: fallbackTitle.isEmpty ? AppSettings.localizedString("未命名文献") : fallbackTitle,
            authors: AppSettings.localizedString("未知作者"),
            journal: "",
            year: Calendar.current.component(.year, from: .now),
            doi: "",
            pdfPath: storedURL.path,
            statusRaw: PaperStatus.unread.rawValue
        )

        paper.hasPDF = true
        paper.pdfFileName = storedURL.lastPathComponent
        paper.importMethod = shouldCopy ? "libraryCopy" : "originalFile"
        paper.databaseSource = "PDF"
        paper.citationKey = makeCitationKey(
            authors: paper.authors,
            title: paper.title,
            year: paper.year
        )
        paper.updatedAt = .now
        let paperUUID = paper.uuid
        savePaper(paper)
        revealImportedPaper()

        do {
            let metadata = try await importMetadataWithTimeout(from: storedURL, seconds: 10)
            applyMetadata(metadata, toPaperUUID: paperUUID)
        } catch {
            // Metadata lookup can fail without discarding the imported record.
        }
    }

    private func importMetadataWithTimeout(from url: URL, seconds: Double) async throws -> PaperMetadata {
        try await withThrowingTaskGroup(of: PaperMetadata.self) { group in
            group.addTask {
                try await importer.importMetadata(from: url)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw PaperMetadataImporterError.metadataNotFound
            }

            guard let result = try await group.next() else {
                throw PaperMetadataImporterError.metadataNotFound
            }
            group.cancelAll()
            return result
        }
    }

    private func applyMetadata(_ metadata: PaperMetadata, toPaperUUID uuid: String) {
        guard let paper = papersCache.first(where: { $0.uuid == uuid }) else { return }

        let finalTitle = metadata.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? paper.title
            : metadata.title
        let finalAuthors = metadata.authors.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? paper.authors
            : metadata.authors

        paper.title = finalTitle
        paper.authors = finalAuthors
        paper.journal = metadata.journal
        paper.year = metadata.year ?? paper.year
        paper.doi = metadata.doi
        paper.databaseSource = metadata.source
        paper.publisher = metadata.publisher
        paper.volume = metadata.volume
        paper.issue = metadata.issue
        paper.pages = metadata.pages
        paper.url = metadata.url
        paper.abstractText = metadata.abstractText
        paper.language = metadata.language
        paper.itemType = metadata.itemType
        paper.dateText = metadata.dateText
        if !metadata.extra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            paper.extra = metadata.extra
        }
        paper.citationKey = makeCitationKey(
            authors: paper.authors,
            title: paper.title,
            year: paper.year
        )
        paper.updatedAt = .now

        do {
            try modelContext.save()
            refreshPapersFromStore()
        } catch {
            errorMessage = AppSettings.localizedFormat("更新文献元数据失败：%@", defaultValue: "Update metadata failed: %@", error.localizedDescription)
            showErrorAlert = true
        }
    }

    private func revealImportedPaper() {
        searchText = ""
        selectedStatus = .all
        navigationState.selectedSection = .library
        navigationState.isReadingModeActive = false
    }

    private func refreshPapersFromStore() {
        let descriptor = FetchDescriptor<Paper>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let fetched = (try? modelContext.fetch(descriptor)) ?? []
        papersCache = zoteroSoleLibrary
            ? fetched.filter { $0.sourceLibraryType == "zotero" }
            : fetched
    }

    private func handleDroppedFiles(_ urls: [URL]) {
        Task {
            var pdfs: [URL] = []
            var libraryURL: URL?
            var unrecognized = false
            for url in urls {
                let kind = await Task.detached(priority: .userInitiated) {
                    LiteratureLibraryKind.detect(at: url)
                }.value
                switch kind {
                case .pdf:
                    pdfs.append(url)
                case .zoteroDataDirectory, .zoteroJSON, .endNoteXML, .paperFocusExport, .paperFocusStore, .pdfFolder, .endNotePackage:
                    libraryURL = url
                case .unrecognized:
                    unrecognized = true
                }
            }

            if !pdfs.isEmpty {
                try? await importPDFFiles(pdfs)
            }
            if let libraryURL {
                stagedImportURL = libraryURL
                importMode = .zotero
                showImportModes = true
            } else if unrecognized && pdfs.isEmpty {
                errorMessage = AppSettings.localizedString("无法识别该文献库格式。请选择 Zotero 数据目录、Zotero JSON、EndNote XML 或 PaperFocus 文献库。")
                showErrorAlert = true
            }
        }
    }

    private func importPDFFiles(_ urls: [URL]) async throws {
        guard !urls.isEmpty else { return }
        isImportingPDF = true
        defer { isImportingPDF = false }
        var failures: [String] = []
        for url in urls {
            do {
                try await importOnePDF(url)
            } catch {
                failures.append(error.localizedDescription)
            }
        }
        refreshPapersFromStore()
        if let message = failures.first {
            throw LibraryImportError.zoteroAccountRejected(message)
        }
    }

    private func savePaper(_ paper: Paper) {
        modelContext.insert(paper)

        do {
            try modelContext.save()
            refreshPapersFromStore()
            selectedPaperID = paper.persistentModelID
            navigationState.selectedPaperID = paper.persistentModelID
            navigationState.prepareTimer(for: paper.displayTitle)
        } catch {
            modelContext.delete(paper)
            errorMessage = AppSettings.localizedFormat("保存文献失败：%@", defaultValue: "Save paper failed: %@", error.localizedDescription)
            showErrorAlert = true
        }
    }

    private func deleteSelectedPaper() {
        guard let paper = selectedPaper else { return }
        deletePaper(paper)
    }

    private func terminateOngoingFocusStateIfNeeded(for paper: Paper) {
        let relatedTasks = focusTasks.filter { task in
            focusTaskMatchesPaper(task, paper: paper) &&
            (task.state == .ready || task.state == .running || task.state == .paused)
        }

        for task in relatedTasks {
            if task.state == .running, let startedAt = task.startedAt {
                task.elapsedSeconds += max(0, Int(Date().timeIntervalSince(startedAt)))
            }

            task.startedAt = nil
            task.pausedAt = nil
            task.finishedAt = .now
            task.isEffectiveRecord = false
            task.state = .cancelled
        }

        let isDeletedPaperSelected = navigationState.selectedPaperID == paper.persistentModelID
            || selectedPaperID == paper.persistentModelID
        let isDeletedPaperResumable = navigationState.resumablePaperID == paper.persistentModelID
        let isDeletedPaperActiveTask = relatedTasks.contains { task in
            task.persistentModelID == navigationState.activeFocusTaskID
        }

        if isDeletedPaperSelected || isDeletedPaperResumable || isDeletedPaperActiveTask {
            navigationState.resetReadingMode()
            navigationState.activeFocusTaskID = nil
            navigationState.clearResumable()
            navigationState.timerDraftTitle = ""
        }
    }

    private func deletePaper(_ paper: Paper) {
        terminateOngoingFocusStateIfNeeded(for: paper)
        modelContext.delete(paper)

        do {
            try modelContext.save()
            refreshPapersFromStore()
            if navigationState.selectedPaperID == paper.persistentModelID {
                navigationState.selectedPaperID = nil
                navigationState.timerDraftTitle = ""
            }
            if selectedPaperID == paper.persistentModelID {
                selectedPaperID = nil
            }
        } catch {
            errorMessage = AppSettings.localizedFormat("删除文献失败：%@", defaultValue: "Delete paper failed: %@", error.localizedDescription)
            showErrorAlert = true
        }
    }

    private func makeCitationKey(authors: String, title: String, year: Int?) -> String {
        let firstAuthor = authors
            .split(separator: ",")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"

        let authorPart = firstAuthor
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()

        let titleWords = title
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == ":" })
            .prefix(3)
            .map {
                $0.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
            }
            .joined()

        let yearPart = year.map(String.init) ?? "noyear"
        let titlePart = String(titleWords.prefix(24))
        let key = authorPart.lowercased() + titlePart + yearPart

        return key.isEmpty ? UUID().uuidString : key
    }
}

private struct LibrarySidebarSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    let items: [LibrarySidebarItem]
}

private struct LibrarySidebarItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    let count: Int
    let level: Int
    let filter: LibrarySidebarFilter
}
