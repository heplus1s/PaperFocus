//
//  MacReadingAIDialogView.swift
//  PaperFocus
//
//  Created by Codex on 11/4/2026.
//

#if os(macOS)
import SwiftUI
import SwiftData

private enum PaperChatQuestionScope: String, CaseIterable, Identifiable {
    case selection
    case document

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selection:
            return AppSettings.localizedString("当前划词")
        case .document:
            return AppSettings.localizedString("整篇 PDF")
        }
    }
}

struct MacReadingAIDialogView: View {
    @EnvironmentObject private var navigationState: AppNavigationState
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \Paper.createdAt, order: .reverse) private var papers: [Paper]

    @Binding var isExpanded: Bool

    @AppStorage(AppSettings.paperSummaryProviderKey)
    private var aiProvider: String = AppSettings.defaultPaperSummaryProvider

    @AppStorage(AppSettings.paperSummaryExternalEndpointKey)
    private var aiEndpoint: String = AppSettings.defaultPaperSummaryExternalEndpoint

    @AppStorage(AppSettings.paperSummaryExternalAPIKey)
    private var aiAPIKey: String = AppSettings.defaultPaperSummaryExternalAPIKey

    @AppStorage(AppSettings.paperSummaryExternalModelKey)
    private var aiModel: String = AppSettings.defaultPaperSummaryExternalModel

    @State private var messages: [PaperChatConversationTurn] = []
    @State private var draftQuestion: String = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var extractedPaperUUID = ""
    @State private var extractedPDFText = ""
    @State private var questionScope: PaperChatQuestionScope = .document

    private var selectedPaper: Paper? {
        guard let id = navigationState.selectedPaperID else { return nil }
        return papers.first { $0.persistentModelID == id }
    }

    private var providerName: String {
        PaperSummaryProviderID.normalized(from: aiProvider).displayName
    }

    private var selectedExcerpt: String {
        navigationState.readingSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSelectedExcerpt: Bool {
        !selectedExcerpt.isEmpty
    }

    private var effectiveQuestionScope: PaperChatQuestionScope {
        hasSelectedExcerpt ? questionScope : .document
    }

    private var questionPlaceholder: String {
        effectiveQuestionScope == .selection
            ? AppSettings.localizedString("针对当前划词提问…")
            : AppSettings.localizedString("向当前 PDF 提问…")
    }

    var body: some View {
        expandedPanel
        .onChange(of: navigationState.selectedPaperID) { _, _ in
            resetConversation()
        }
        .onChange(of: navigationState.readingSelectedText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if questionScope == .selection {
                    questionScope = .document
                }
            } else if messages.isEmpty {
                questionScope = .selection
            }
        }
        .onChange(of: aiProvider) { _, _ in
            resetConversation(preserveExtractedText: true)
        }
        .onChange(of: aiEndpoint) { _, _ in
            resetConversation(preserveExtractedText: true)
        }
        .onChange(of: aiAPIKey) { _, _ in
            resetConversation(preserveExtractedText: true)
        }
        .onChange(of: aiModel) { _, _ in
            resetConversation(preserveExtractedText: true)
        }
    }

    private var expandedPanel: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI 提问")
                        .font(.headline)
                    Text(providerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let paper = selectedPaper, let _ = paper.pdfURL {
                scopePanel
                messageList(for: paper)
                composer(for: paper)
            } else {
                ContentUnavailableView(
                    "当前没有可对话的 PDF",
                    systemImage: "doc.text",
                    description: Text("请先在文献库中打开一篇已关联 PDF 的论文，再使用 AI 提问。")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(aiPaneBackground)
    }

    @ViewBuilder
    private var aiPaneBackground: some View {
        #if os(macOS)
        if #available(macOS 26.0, *) {
            Color.clear
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    colorScheme == .dark ? Color.white.opacity(0.08) : Color.secondary.opacity(0.14),
                    lineWidth: 1
                )
        }
        #else
        Color.clear
        #endif
    }

    @ViewBuilder
    private var scopePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("提问范围", selection: $questionScope) {
                if hasSelectedExcerpt {
                    Text(PaperChatQuestionScope.selection.title).tag(PaperChatQuestionScope.selection)
                }
                Text(PaperChatQuestionScope.document.title).tag(PaperChatQuestionScope.document)
            }
            .pickerStyle(.segmented)

            if hasSelectedExcerpt {
                VStack(alignment: .leading, spacing: 6) {
                    Text("当前划词")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(selectedExcerpt)
                        .font(.caption)
                        .textSelection(.enabled)
                        .lineLimit(questionScope == .selection ? 6 : 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text("当前没有划词，将按整篇 PDF 内容回答。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func messageList(for paper: Paper) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if messages.isEmpty {
                        Text(hasSelectedExcerpt ? "可以直接针对当前划词提问，也可以切换到整篇 PDF 范围继续追问。" : "可以围绕当前 PDF 自由提问，例如“这篇文章主要讲了什么？”、“作者提出了哪些关键方法？”或“这部分结论该怎么理解？”")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        ForEach(messages) { message in
                            HStack {
                                if message.role == "assistant" {
                                    messageBubble(message.content, assistant: true)
                                    Spacer(minLength: 24)
                                } else {
                                    Spacer(minLength: 24)
                                    messageBubble(message.content, assistant: false)
                                }
                            }
                            .id(message.id)
                        }
                    }

                    if isLoading {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("AI 正在回答...")
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: messages.count) { _, _ in
                if let lastID = messages.last?.id {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func composer(for paper: Paper) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(paper.displayTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            TextField(questionPlaceholder, text: $draftQuestion)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)
                .onSubmit {
                    sendQuestion(for: paper)
                }
#if os(iOS)
                .submitLabel(.send)
#endif
        }
    }

    private func messageBubble(_ text: String, assistant: Bool) -> some View {
        Text(text)
            .font(.subheadline)
            .textSelection(.enabled)
            .padding(12)
            .frame(maxWidth: 320, alignment: .leading)
            .background(
                assistant ? Color.secondary.opacity(0.10) : Color.accentColor.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 12)
            )
    }

    private func sendQuestion(for paper: Paper) {
        guard let pdfURL = paper.pdfURL else { return }
        let question = draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        errorMessage = ""
        draftQuestion = ""

        let userTurn = PaperChatConversationTurn(role: "user", content: question)
        messages.append(userTurn)
        isLoading = true

        let providerID = aiProvider
        let endpoint = aiEndpoint
        let apiKey = aiAPIKey
        let model = aiModel
        let targetPaperUUID = paper.uuid
        let history = messages
        let activeSelectedExcerpt = effectiveQuestionScope == .selection ? selectedExcerpt : ""

        Task {
            do {
                let extractedText = try await loadPDFTextIfNeeded(from: pdfURL, paperUUID: targetPaperUUID)
                let request = PaperChatRequest(
                    title: paper.displayTitle,
                    content: extractedText,
                    selectedExcerpt: activeSelectedExcerpt.isEmpty ? nil : activeSelectedExcerpt,
                    history: history.dropLast().map { $0 },
                    question: question
                )
                let answer = try await PaperChatService.ask(
                    request: request,
                    providerID: providerID,
                    externalEndpoint: endpoint,
                    externalAPIKey: apiKey,
                    externalModel: model
                )

                await MainActor.run {
                    guard selectedPaper?.uuid == targetPaperUUID else { return }
                    isLoading = false
                    messages.append(PaperChatConversationTurn(role: "assistant", content: answer))
                }
            } catch {
                await MainActor.run {
                    guard selectedPaper?.uuid == targetPaperUUID else { return }
                    isLoading = false
                    if messages.last?.role == "user", messages.last?.content == question {
                        _ = messages.popLast()
                    }
                    draftQuestion = question
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadPDFTextIfNeeded(from url: URL, paperUUID: String) async throws -> String {
        if extractedPaperUUID == paperUUID, !extractedPDFText.isEmpty {
            return extractedPDFText
        }

        let accessHandle = SecurityScopedBookmarkStore.shared.beginAccess(forExternalFile: url)
        defer { SecurityScopedBookmarkStore.shared.endAccess(accessHandle) }
        let text = await Task.detached(priority: .userInitiated) {
            PDFTextExtractor.extractText(from: url, maxPages: 12)
        }.value
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PaperChatError.emptyContent
        }

        await MainActor.run {
            extractedPaperUUID = paperUUID
            extractedPDFText = trimmed
        }

        return trimmed
    }

    private func resetConversation(preserveExtractedText: Bool = false) {
        messages = []
        draftQuestion = ""
        isLoading = false
        errorMessage = ""
        if !preserveExtractedText {
            extractedPaperUUID = ""
            extractedPDFText = ""
        }
    }
}
#endif
