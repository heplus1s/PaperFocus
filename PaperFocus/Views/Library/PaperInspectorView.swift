//
//  PaperInspectorView.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import SwiftUI
import SwiftData

struct PaperInspectorView: View {
    @Environment(\.locale) private var locale

    let paper: Paper?
    let summaryText: String
    let isGeneratingSummary: Bool
    let canSummarize: Bool
    let onGenerateSummary: () -> Void

    @AppStorage(AppSettings.showPaperInspectorHeaderKey)
    private var showPaperInspectorHeader: Bool = AppSettings.defaultShowPaperInspectorHeader

    @AppStorage(AppSettings.showRecentFocusSummaryKey)
    private var showRecentFocusSummary: Bool = AppSettings.defaultShowRecentFocusSummary
    
    var body: some View {
        Group {
            if let paper {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection(paper)
                        recentFocusSummarySection(paper)
                        aiSummarySection
                        basicInfoSection(paper)
                        publicationSection(paper)
                        identifierSection(paper)
                        abstractSection(paper)
                        notesSection(paper)
                        fileSection(paper)
                        workflowSection(paper)
                        timestampSection(paper)
                    }
                    .padding(16)
                }
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
                .background(.background)
            } else {
                ContentUnavailableView(
                    "未选中文献",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("请在左侧文献表格中选择一篇文献。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerSection(_ paper: Paper) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(paper.displayTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                statusBadge(for: paper.status)

                if paper.isFavorite {
                    Label("收藏", systemImage: "star.fill")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.yellow.opacity(0.15), in: Capsule())
                }

                if paper.hasPDF {
                    Label("PDF", systemImage: "doc.richtext")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.12), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Basic Info

    @ViewBuilder
    private func basicInfoSection(_ paper: Paper) -> some View {
        inspectorSection("基本信息") {
            inspectorRow("标题", paper.displayTitle)
            inspectorRow("副标题", valueOrDash(paper.subtitle))
            inspectorRow("作者", paper.displayAuthors)
            inspectorRow("编辑者", valueOrDash(paper.editors))
            inspectorRow("机构作者", valueOrDash(paper.corporateAuthors))
            inspectorRow("类型", valueOrDash(paper.itemType))
            inspectorRow("引用键", valueOrDash(paper.citationKey))
            inspectorRow("标签", paper.tagList.isEmpty ? "—" : paper.tagList.joined(separator: ", "))
            inspectorRow("分组", valueOrDash(paper.collection))
            inspectorRow("文件夹路径", valueOrDash(paper.collectionPath))
            inspectorRow("全部文件夹", paper.collectionList.isEmpty ? "—" : paper.collectionList.joined(separator: " / "))
            inspectorRow("优先级", valueOrDash(paper.priority))
        }
    }

    // MARK: - Publication

    @ViewBuilder
    private func publicationSection(_ paper: Paper) -> some View {
        inspectorSection("出版信息") {
            inspectorRow("期刊", paper.displayJournal)
            inspectorRow("期刊简称", valueOrDash(paper.journalAbbreviation))
            inspectorRow("会议", valueOrDash(paper.conferenceName))
            inspectorRow("书名", valueOrDash(paper.bookTitle))
            inspectorRow("出版社", valueOrDash(paper.publisher))
            inspectorRow("出版地", valueOrDash(paper.publicationPlace))
            inspectorRow("年份", paper.displayYear)
            inspectorRow("日期", valueOrDash(paper.dateText))
            inspectorRow("卷", valueOrDash(paper.volume))
            inspectorRow("期", valueOrDash(paper.issue))
            inspectorRow("页码", valueOrDash(paper.pages))
            inspectorRow("文章编号", valueOrDash(paper.articleNumber))
            inspectorRow("版次", valueOrDash(paper.edition))
            inspectorRow("章节", valueOrDash(paper.chapter))
            inspectorRow("系列", valueOrDash(paper.series))
            inspectorRow("系列标题", valueOrDash(paper.seriesTitle))
        }
    }

    // MARK: - Identifier

    @ViewBuilder
    private func identifierSection(_ paper: Paper) -> some View {
        inspectorSection("标识信息") {
            if let doiURL = doiURL(from: paper.doi) {
                linkRow("DOI", text: paper.doi, url: doiURL)
            } else {
                inspectorRow("DOI", valueOrDash(paper.doi))
            }

            if let url = safeURL(from: paper.url) {
                linkRow("URL", text: paper.url, url: url)
            } else {
                inspectorRow("URL", valueOrDash(paper.url))
            }

            inspectorRow("ISSN", valueOrDash(paper.issn))
            inspectorRow("ISBN", valueOrDash(paper.isbn))
            inspectorRow("PMID", valueOrDash(paper.pmid))
            inspectorRow("PMCID", valueOrDash(paper.pmcid))
            inspectorRow("Accession", valueOrDash(paper.accessionNumber))
            inspectorRow("Archive", valueOrDash(paper.archive))
            inspectorRow("Archive 位置", valueOrDash(paper.archiveLocation))
            inspectorRow("文库编目", valueOrDash(paper.libraryCatalog))
            inspectorRow("索书号", valueOrDash(paper.callNumber))
            inspectorRow("语言", valueOrDash(paper.language))
            inspectorRow("版权", valueOrDash(paper.rights))
        }
    }

    // MARK: - Abstract

    @ViewBuilder
    private func abstractSection(_ paper: Paper) -> some View {
        inspectorSection("摘要") {
            Text(paper.abstractText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppSettings.localizedString("暂无摘要") : paper.abstractText)
                .foregroundStyle(
                    paper.abstractText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .primary
                )
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Notes

    @ViewBuilder
    private func notesSection(_ paper: Paper) -> some View {
        inspectorSection("备注") {
            Text(paper.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppSettings.localizedString("暂无备注") : paper.notes)
                .foregroundStyle(
                    paper.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .primary
                )
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !paper.extra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider()
                inspectorRow("Extra", paper.extra)
            }
        }
    }

    // MARK: - File

    @ViewBuilder
    private func fileSection(_ paper: Paper) -> some View {
        inspectorSection("本地文件") {
            inspectorRow("是否有 PDF", AppSettings.localizedBool(paper.hasPDF))
            inspectorRow("文件名", valueOrDash(paper.pdfFileName))
            inspectorRow("文件类型", valueOrDash(paper.fileType))
            inspectorRow("文件大小", formatFileSize(paper.fileSize))
            inspectorRow("路径", valueOrDash(paper.pdfPath))
            inspectorRow("原始附件路径", valueOrDash(paper.sourceAttachmentPath))

            if let pdfURL = paper.pdfURL {
                HStack {
                    Button("打开 PDF") {
                        PDFService.openPDF(at: pdfURL.path)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("在 Finder 中显示") {
                        PDFService.revealInFinder(at: pdfURL.path)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Workflow

    @ViewBuilder
    private func workflowSection(_ paper: Paper) -> some View {
        inspectorSection("阅读状态") {
            inspectorRow("状态", paper.status.displayName)
            inspectorRow("收藏", AppSettings.localizedBool(paper.isFavorite))
            inspectorRow("置顶", AppSettings.localizedBool(paper.isPinned))
            inspectorRow("已读", AppSettings.localizedBool(paper.isRead))
            inspectorRow("有笔记", AppSettings.localizedBool(paper.hasNotes))
            inspectorRow("相关", AppSettings.localizedBool(paper.isRelevant))
            inspectorRow("阅读进度", "\(Int(paper.readingProgress * 100))%")
            inspectorRow("最近页码", "\(paper.lastReadPage)")
            inspectorRow("来源数据库", valueOrDash(paper.databaseSource))
            inspectorRow("导入方式", valueOrDash(paper.importMethod))
            inspectorRow("来源记录 ID", valueOrDash(paper.sourceRecordID))
            inspectorRow("来源文献库", valueOrDash(paper.sourceLibraryType))
            inspectorRow("文献库名称", valueOrDash(paper.sourceLibraryName))
        }
    }

    // MARK: - Timestamp

    @ViewBuilder
    private func timestampSection(_ paper: Paper) -> some View {
        inspectorSection("时间信息") {
            inspectorRow("创建时间", formatDate(paper.createdAt))
            inspectorRow("更新时间", formatDate(paper.updatedAt))
            inspectorRow("最近打开", optionalDateString(paper.lastOpenedAt))
            inspectorRow("访问日期", optionalDateString(paper.accessDate))
            inspectorRow("UUID", valueOrDash(paper.uuid))
        }
    }

    // MARK: - Shared UI

    @ViewBuilder
    private func inspectorSection<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func inspectorRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)

            Text(value.isEmpty ? "—" : value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func linkRow(_ title: LocalizedStringKey, text: String, url: URL) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)

            Link(text, destination: url)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func statusBadge(for status: PaperStatus) -> some View {
        Text(status.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15), in: Capsule())
    }

    @ViewBuilder
    private func recentFocusSummarySection(_ paper: Paper) -> some View {
        let completedTasks = paper.focusTasks
            .filter { $0.state == .completed }
            .sorted { ($0.finishedAt ?? $0.updatedAt) > ($1.finishedAt ?? $1.updatedAt) }

        let totalMinutes = completedTasks.reduce(0) { $0 + $1.elapsedMinutes }
        let recentThree = Array(completedTasks.prefix(3))

        inspectorSection("最近专注") {
            inspectorRow("累计时长", AppSettings.localizedMinutes(totalMinutes))

            if recentThree.isEmpty {
                inspectorRow("最近记录", AppSettings.localizedString("暂无已完成专注"))
            } else {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(recentThree) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(task.mode.displayName) · \(task.displayGoal)")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(
                                AppSettings.localizedFormat(
                                    "单次时长：%@",
                                    defaultValue: "Duration: %@",
                                    AppSettings.localizedMinutes(task.elapsedMinutes)
                                )
                            )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if task.persistentModelID != recentThree.last?.persistentModelID {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var aiSummarySection: some View {
        inspectorSection("AI 汇总") {
            Button {
                onGenerateSummary()
            } label: {
                if isGeneratingSummary {
                    Label("汇总中…", systemImage: "sparkles")
                } else {
                    Label("AI 汇总", systemImage: "sparkles")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSummarize || isGeneratingSummary)

            if isGeneratingSummary {
                ProgressView("正在生成摘要…")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if summaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("暂未生成摘要。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(summaryText)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    
    // MARK: - Helpers

    private func valueOrDash(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : text
    }

    private func safeURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    private func doiURL(from doi: String) -> URL? {
        let trimmed = doi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "https://doi.org/\(trimmed)")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func optionalDateString(_ date: Date?) -> String {
        guard let date else { return "—" }
        return formatDate(date)
    }

    private func formatFileSize(_ size: Int64) -> String {
        guard size > 0 else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
