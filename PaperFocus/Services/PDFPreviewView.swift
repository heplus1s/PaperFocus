//
//  PDFPreviewView.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import SwiftUI
import PDFKit
import Combine
#if canImport(Translation)
import Translation
#endif

#if os(iOS)
import UIKit
typealias PlatformColor = UIColor
#elseif os(macOS)
import AppKit
typealias PlatformColor = NSColor
#endif

struct PDFPreviewView: View {
    @EnvironmentObject private var navigationState: AppNavigationState

    let url: URL
    let title: String

    @StateObject private var reader = PDFReaderBridge()
    @State private var translationRequestTask: Task<Void, Never>?
    @State private var translationTimeoutTask: Task<Void, Never>?
    @State private var selectionDebounceTask: Task<Void, Never>?
    @State private var translationGeneration: Int = 0
    @State private var currentTranslationKey: String = ""

    private var translationProviderDisplayName: String {
        switch TranslationModeID.normalized(from: translationMode) {
        case .system:
            return TranslationModeID.system.displayName
        case .ai:
            return "AI 翻译 · \(PaperSummaryProviderID.normalized(from: aiSummaryProvider).displayName)"
        case .traditional:
            return AppSettings.traditionalTranslationProviderPreset(for: translationTraditionalProvider).name
        }
    }

    private var usesSystemTranslationProvider: Bool {
        TranslationModeID.normalized(from: translationMode) == .system
    }

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var bottomPanelBaseHeight: CGFloat = 220
    @GestureState private var bottomPanelDragOffset: CGFloat = 0
    #endif

    @AppStorage(AppSettings.pdfToolbarDisplayModeKey)
    private var toolbarDisplayMode: String = AppSettings.defaultPDFToolbarDisplayMode

    @AppStorage(AppSettings.pdfDefaultAnnotationColorKey)
    private var defaultAnnotationColor: String = AppSettings.defaultPDFAnnotationColor

    @AppStorage(AppSettings.translationAutoTranslateEnabledKey)
    private var autoTranslateEnabled: Bool = AppSettings.defaultTranslationAutoTranslateEnabled

    @AppStorage(AppSettings.translationSourceLanguageKey)
    private var sourceLanguageCode: String = AppSettings.defaultTranslationSourceLanguage

    @AppStorage(AppSettings.translationTargetLanguageKey)
    private var targetLanguageCode: String = AppSettings.defaultTranslationTargetLanguage

    @AppStorage(AppSettings.appLanguageKey)
    private var appLanguage: String = AppSettings.defaultAppLanguage

    @AppStorage(AppSettings.translationModeKey)
    private var translationMode: String = AppSettings.defaultTranslationMode

    @AppStorage(AppSettings.translationTraditionalProviderKey)
    private var translationTraditionalProvider: String = AppSettings.defaultTranslationTraditionalProvider

    @AppStorage(AppSettings.translationTraditionalEndpointKey)
    private var translationTraditionalEndpoint: String = AppSettings.defaultTranslationTraditionalEndpoint

    @AppStorage(AppSettings.translationTraditionalPrimaryCredentialKey)
    private var translationTraditionalPrimaryCredential: String = AppSettings.defaultTranslationTraditionalPrimaryCredential

    @AppStorage(AppSettings.translationTraditionalSecondaryCredentialKey)
    private var translationTraditionalSecondaryCredential: String = AppSettings.defaultTranslationTraditionalSecondaryCredential

    @AppStorage(AppSettings.paperSummaryProviderKey)
    private var aiSummaryProvider: String = AppSettings.defaultPaperSummaryProvider

    @AppStorage(AppSettings.paperSummaryExternalEndpointKey)
    private var aiSummaryExternalEndpoint: String = AppSettings.defaultPaperSummaryExternalEndpoint

    @AppStorage(AppSettings.paperSummaryExternalAPIKey)
    private var aiSummaryExternalAPIKey: String = AppSettings.defaultPaperSummaryExternalAPIKey

    @AppStorage(AppSettings.paperSummaryExternalModelKey)
    private var aiSummaryExternalModel: String = AppSettings.defaultPaperSummaryExternalModel

    #if canImport(Translation)
    @State private var translationConfiguration: TranslationSession.Configuration?
    #endif

    var body: some View {
        configuredView(baseView)
    }

    private var baseView: some View {
        GeometryReader { proxy in
            let size = proxy.size

            #if os(iOS)
            let safeBottom = proxy.safeAreaInsets.bottom
            let useBottomTranslation = shouldUseBottomTranslationPanel(for: size)
            let compactPhoneUI = isCompactPhoneUI(for: size)
            let maxBottomPanelHeight = maximumBottomPanelHeight(for: size, safeBottom: safeBottom)
            let bottomPanelHeight = currentBottomPanelHeight(maxHeight: maxBottomPanelHeight)

            Group {
                if useBottomTranslation {
                    VStack(spacing: 0) {
                        pdfCanvas
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Divider()

                        if reader.isTranslationSidebarExpanded {
                            translationBottomPanel(
                                compact: compactPhoneUI,
                                maxHeight: maxBottomPanelHeight
                            )
                            .frame(height: bottomPanelHeight)
                            .transaction { transaction in
                                transaction.animation = nil
                            }
                        } else {
                            collapsedBottomTranslationBar(
                                safeBottom: safeBottom,
                                restoreHeight: min(220, maxBottomPanelHeight)
                            )
                            .frame(height: 34 + safeBottom)
                            .transition(.move(edge: .bottom))
                        }
                    }
                } else {
                    HStack(spacing: 0) {
                        pdfCanvas
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Divider()

                        if reader.isTranslationSidebarExpanded {
                            translationSidebar(compact: compactPhoneUI, bottomMode: false)
                                .frame(width: compactPhoneUI ? 300 : 360)
                                .transition(.move(edge: .trailing))
                        } else {
                            collapsedTranslationBar
                                .frame(width: 28)
                                .transition(.move(edge: .trailing))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(pdfBackgroundColor)
            .ignoresSafeArea(edges: .all)
            #else
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    toolbar(for: size)

                    Divider()

                    pdfCanvas
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider()

                if reader.isTranslationSidebarExpanded {
                    translationSidebar(compact: false, bottomMode: false)
                        .frame(width: 360)
                        .transition(.move(edge: .trailing))
                } else {
                    collapsedTranslationBar
                        .frame(width: 28)
                        .transition(.move(edge: .trailing))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif
        }
        #if os(iOS)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            iosToolbarItems
        }
        #else
        .navigationTitle(title)
        #endif
    }

    @ViewBuilder
    private func configuredView<Content: View>(_ content: Content) -> some View {
        let lifecycleConfigured = content
            .onAppear(perform: handleViewAppear)
            .onDisappear(perform: handleViewDisappear)
            .onChange(of: defaultAnnotationColor) { _, newValue in
                handleAnnotationColorChange(newValue)
            }
            .onChange(of: reader.selectedText) { _, newValue in
                handleSelectedTextChange(newValue)
            }

        let translationConfigured = lifecycleConfigured
            .onChange(of: sourceLanguageCode) { _, _ in
                handleTranslationConfigurationChange()
            }
            .onChange(of: targetLanguageCode) { _, _ in
                handleTranslationConfigurationChange()
            }
            .onChange(of: translationMode) { _, _ in
                handleTranslationConfigurationChange()
            }

        let providerConfigured = translationConfigured
            .onChange(of: translationTraditionalProvider) { _, _ in
                retriggerTranslationIfNeeded(force: true)
            }
            .onChange(of: translationTraditionalEndpoint) { _, _ in
                retriggerTranslationIfNeeded(force: true)
            }
            .onChange(of: translationTraditionalPrimaryCredential) { _, _ in
                retriggerTranslationIfNeeded(force: true)
            }
            .onChange(of: translationTraditionalSecondaryCredential) { _, _ in
                retriggerTranslationIfNeeded(force: true)
            }
            .onChange(of: aiSummaryProvider) { _, _ in
                retriggerTranslationIfNeeded(force: true)
            }
            .onChange(of: aiSummaryExternalEndpoint) { _, _ in
                retriggerTranslationIfNeeded(force: true)
            }
            .onChange(of: aiSummaryExternalAPIKey) { _, _ in
                retriggerTranslationIfNeeded(force: true)
            }
            .onChange(of: aiSummaryExternalModel) { _, _ in
                retriggerTranslationIfNeeded(force: true)
            }
            .onChange(of: autoTranslateEnabled) { _, newValue in
                handleAutoTranslateChange(newValue)
            }

        #if canImport(Translation)
        providerConfigured.translationTask(translationConfiguration) { session in
            await translateSelection(using: session)
        }
        #else
        providerConfigured
        #endif
    }

    private func syncSelectedTextToNavigationState() {
        navigationState.readingSelectedText = reader.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleViewAppear() {
        reader.annotationColor = PDFMarkupColor(rawValue: defaultAnnotationColor) ?? .yellow
        reader.setDocumentURL(url)
        rebuildTranslationConfigurationForCurrentLanguages()
        syncSelectedTextToNavigationState()

        #if os(iOS)
        if bottomPanelBaseHeight <= 0 {
            bottomPanelBaseHeight = 220
        }
        #endif
    }

    private func handleViewDisappear() {
        navigationState.readingSelectedText = ""
        PDFEditingCoordinator.shared.detachIfNeeded(for: url)
    }

    private func handleAnnotationColorChange(_ newValue: String) {
        reader.annotationColor = PDFMarkupColor(rawValue: newValue) ?? .yellow
    }

    private func handleSelectedTextChange(_ newValue: String) {
        navigationState.readingSelectedText = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        scheduleTranslationAfterSelectionSettles(newValue)
    }

    private func handleTranslationConfigurationChange() {
        rebuildTranslationConfigurationForCurrentLanguages()
        retriggerTranslationIfNeeded(force: true)
    }

    private func handleAutoTranslateChange(_ newValue: Bool) {
        if newValue {
            rebuildTranslationConfigurationForCurrentLanguages()
            retriggerTranslationIfNeeded(force: true)
        } else {
            stopTranslation(clearResult: false)
        }
    }

    private var pdfCanvas: some View {
        PDFKitContainer(
            url: url,
            bridge: reader
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pdfBackgroundColor)
    }

    #if os(iOS)
    private func isCompactPhoneUI(for size: CGSize) -> Bool {
        horizontalSizeClass == .compact || size.width < 700
    }

    private func shouldUseBottomTranslationPanel(for size: CGSize) -> Bool {
        isCompactPhoneUI(for: size) && size.height > size.width
    }

    private func maximumBottomPanelHeight(for size: CGSize, safeBottom: CGFloat) -> CGFloat {
        let available = max(0, size.height - safeBottom - 20)
        return available * 0.75
    }

    private func currentBottomPanelHeight(maxHeight: CGFloat) -> CGFloat {
        let height = bottomPanelBaseHeight - bottomPanelDragOffset
        return min(max(height, 170), maxHeight)
    }

    private func commitBottomPanelHeight(_ rawHeight: CGFloat, maxHeight: CGFloat) {
        let clamped = min(max(rawHeight, 0), maxHeight)
        if clamped < 80 {
            withAnimation(.easeOut(duration: 0.12)) {
                reader.isTranslationSidebarExpanded = false
            }
        } else {
            bottomPanelBaseHeight = clamped
            if !reader.isTranslationSidebarExpanded {
                withAnimation(.easeOut(duration: 0.12)) {
                    reader.isTranslationSidebarExpanded = true
                }
            }
        }
    }

    private func restoreBottomPanel(to height: CGFloat) {
        bottomPanelBaseHeight = height
        withAnimation(.easeOut(duration: 0.12)) {
            reader.isTranslationSidebarExpanded = true
        }
    }

    private var isLandscapeToolbar: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .compact
    }

    @ToolbarContentBuilder
    private var iosToolbarItems: some ToolbarContent {
        if isLandscapeToolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 14) {
                    iosColorMenu

                    Button {
                        reader.addHighlight()
                    } label: {
                        Image(systemName: "highlighter")
                    }
                    .disabled(!reader.canApplyMarkup)

                    Button {
                        reader.addUnderline()
                    } label: {
                        Image(systemName: "underline")
                    }
                    .disabled(!reader.canApplyMarkup)

                    Button {
                        reader.copySelection()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(reader.selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        reader.undoLastAnnotationAction()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!reader.canUndoAnnotationAction)

                    Button {
                        _ = reader.saveDocument()
                    } label: {
                        Image(systemName: "externaldrive.fill")
                    }
                    .disabled(!reader.canSave)
                }
                .labelStyle(.iconOnly)
            }

            ToolbarItem(placement: .topBarTrailing) {
                if !reader.isTranslationSidebarExpanded {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            reader.isTranslationSidebarExpanded = true
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            reader.isTranslationSidebarExpanded = false
                        }
                    } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
                iosColorMenu

                Button {
                    reader.addHighlight()
                } label: {
                    Image(systemName: "highlighter")
                }
                .disabled(!reader.canApplyMarkup)

                Button {
                    reader.addUnderline()
                } label: {
                    Image(systemName: "underline")
                }
                .disabled(!reader.canApplyMarkup)

                Button {
                    reader.copySelection()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .disabled(reader.selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    reader.undoLastAnnotationAction()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!reader.canUndoAnnotationAction)

                Button {
                    _ = reader.saveDocument()
                } label: {
                    Image(systemName: "externaldrive.fill")
                }
                .disabled(!reader.canSave)
            }
        }
    }

    private var iosColorMenu: some View {
        Menu {
            ForEach(PDFMarkupColor.allCases, id: \.rawValue) { color in
                Button {
                    defaultAnnotationColor = color.rawValue
                    reader.annotationColor = color
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: reader.annotationColor == color ? "checkmark" : "circle")
                            .frame(width: 16)

                        Circle()
                            .fill(color.previewColor)
                            .frame(width: 12, height: 12)

                        Text(color.title)
                    }
                }
            }
        } label: {
            Circle()
                .fill(reader.annotationColor.previewColor)
                .frame(width: 18, height: 18)
        }
    }
    #endif

    @ViewBuilder
    private func toolbar(for size: CGSize) -> some View {
        #if os(iOS)
        EmptyView()
        #else
        let compact = shouldUseCompactToolbar(for: size.width)

        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    toolbarButton(
                        title: "缩小",
                        systemImage: "minus.magnifyingglass",
                        compact: compact
                    ) {
                        reader.zoomOut()
                    }

                    Button {
                        reader.resetZoom()
                    } label: {
                        Text("\(reader.zoomPercent)%")
                            .font(.subheadline.monospacedDigit())
                            .frame(minWidth: 54)
                    }
                    .buttonStyle(.bordered)

                    toolbarButton(
                        title: "放大",
                        systemImage: "plus.magnifyingglass",
                        compact: compact
                    ) {
                        reader.zoomIn()
                    }

                    Divider()
                        .frame(height: 22)

                    Menu {
                        ForEach(PDFMarkupColor.allCases, id: \.rawValue) { color in
                            Button {
                                defaultAnnotationColor = color.rawValue
                                reader.annotationColor = color
                            } label: {
                                Label {
                                    Text(color.title)
                                } icon: {
                                    Image(systemName: reader.annotationColor == color ? "checkmark.circle.fill" : "circle.fill")
                                        .foregroundStyle(color.previewColor)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(reader.annotationColor.previewColor)
                                .frame(width: 12, height: 12)

                            if !compact {
                                Text(reader.annotationColor.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .frame(width: 34, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, compact ? 4 : 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)

                    toolbarButton(
                        title: "高亮",
                        systemImage: "highlighter",
                        compact: compact
                    ) {
                        reader.addHighlight()
                    }
                    .disabled(!reader.canApplyMarkup)

                    toolbarButton(
                        title: "下划线",
                        systemImage: "underline",
                        compact: compact
                    ) {
                        reader.addUnderline()
                    }
                    .disabled(!reader.canApplyMarkup)

                    toolbarButton(
                        title: "复制",
                        systemImage: "doc.on.doc",
                        compact: compact
                    ) {
                        reader.copySelection()
                    }
                    .disabled(reader.selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    toolbarButton(
                        title: "回退一步",
                        systemImage: "arrow.uturn.backward",
                        compact: compact
                    ) {
                        reader.undoLastAnnotationAction()
                    }
                    .disabled(!reader.canUndoAnnotationAction)

                    Divider()
                        .frame(height: 22)

                    toolbarButton(
                        title: reader.hasUnsavedChanges ? "保存*" : "保存",
                        systemImage: "externaldrive.fill",
                        compact: compact
                    ) {
                        _ = reader.saveDocument()
                    }
                    .disabled(!reader.canSave)

                    Divider()
                        .frame(height: 22)

                    Text("第 \(reader.currentPage) / \(reader.totalPages) 页")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 100)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
        .frame(height: 52)
        #endif
    }

    private func shouldUseCompactToolbar(for width: CGFloat) -> Bool {
        #if os(macOS)
        if toolbarDisplayMode == "iconOnly" { return true }
        return width < 980
        #else
        return toolbarDisplayMode == "iconOnly"
        #endif
    }

    @ViewBuilder
    private func toolbarButton(
        title: String,
        systemImage: String,
        compact: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if compact {
                Image(systemName: systemImage)
            } else {
                Label(title, systemImage: systemImage)
            }
        }
        .buttonStyle(.bordered)
    }

    private var pdfBackgroundColor: Color {
        #if os(macOS)
        return Color(nsColor: .textBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }

    private func translationSidebar(compact: Bool, bottomMode: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    #if os(iOS)
                    if !compact || !bottomMode {
                        Text("翻译")
                            .font(.title3.weight(.semibold))
                    }
                    #else
                    Text("翻译")
                        .font(.title3.weight(.semibold))
                    #endif

                    Spacer()

                    #if os(iOS)
                    if !(horizontalSizeClass == .compact && verticalSizeClass == .regular) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                reader.isTranslationSidebarExpanded = false
                            }
                        } label: {
                            Image(systemName: "sidebar.right")
                        }
                        .buttonStyle(.bordered)
                    }
                    #else
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            reader.isTranslationSidebarExpanded = false
                        }
                    } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .buttonStyle(.bordered)
                    #endif
                }

                #if os(iOS)
                if horizontalSizeClass != .compact || !bottomMode {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("自动翻译", isOn: $autoTranslateEnabled)

                        if !autoTranslateEnabled {
                            Button("立即翻译当前选区") {
                                retriggerTranslationIfNeeded(force: true)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(reader.selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                } else if !autoTranslateEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Button("翻译当前选区") {
                            retriggerTranslationIfNeeded(force: true)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(reader.selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                }
                #else
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("自动翻译", isOn: $autoTranslateEnabled)

                    Picker("原文语言", selection: $sourceLanguageCode) {
                        ForEach(AppSettings.translationLanguages, id: \.code) { item in
                            Text(AppSettings.localizedLanguageName(for: item.code, appLanguage: appLanguage)).tag(item.code)
                        }
                    }

                    Picker("译文语言", selection: $targetLanguageCode) {
                        ForEach(AppSettings.translationLanguages, id: \.code) { item in
                            Text(AppSettings.localizedLanguageName(for: item.code, appLanguage: appLanguage)).tag(item.code)
                        }
                    }

                    if !autoTranslateEnabled {
                        Button("立即翻译当前选区") {
                            retriggerTranslationIfNeeded(force: true)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(reader.selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                #endif

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("译文")
                            .font(.headline)
                        Spacer()
                        Text("\(translationProviderDisplayName) · \(AppSettings.languageName(for: sourceLanguageCode)) → \(AppSettings.languageName(for: targetLanguageCode))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Group {
                        if reader.isTranslating {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(translationLoadingMessage)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                        } else if !reader.translationErrorMessage.isEmpty {
                            Text(reader.translationErrorMessage)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                        } else if !reader.translatedText.isEmpty {
                            Text(reader.translatedText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                        } else {
                            Text("选择 PDF 中的句子或段落后，这里会显示翻译结果。")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("原文")
                            .font(.headline)
                        Spacer()
                        Text("第 \(reader.currentPage) 页")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !reader.selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(reader.selectedText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("当前未选中文本。")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                HStack {
                    Button("复制译文") {
                        reader.copyText(reader.translatedText)
                    }
                    .buttonStyle(.bordered)
                    .disabled(reader.translatedText.isEmpty)

                    Button("复制原文") {
                        reader.copyText(reader.selectedText)
                    }
                    .buttonStyle(.bordered)
                    .disabled(reader.selectedText.isEmpty)
                }
            }
            .padding(16)
        }
        .background(.background)
    }

    #if os(iOS)
    private func translationBottomPanel(compact: Bool, maxHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 6)

                Capsule()
                    .fill(Color.secondary.opacity(0.42))
                    .frame(width: 144, height: 6)

                Color.clear
                    .frame(height: 28)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($bottomPanelDragOffset) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        let finalHeight = bottomPanelBaseHeight - value.translation.height
                        commitBottomPanelHeight(finalHeight, maxHeight: maxHeight)
                    }
            )

            translationSidebar(compact: compact, bottomMode: true)
        }
        .background(.background)
    }

    private func collapsedBottomTranslationBar(
        safeBottom: CGFloat,
        restoreHeight: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Button {
                restoreBottomPanel(to: restoreHeight)
            } label: {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.42))
                        .frame(width: 144, height: 6)
                        .padding(.top, 6)

                    Color.clear
                        .frame(height: max(10, safeBottom + 4))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .background(.background)
    }
    #endif

    private var collapsedTranslationBar: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    reader.isTranslationSidebarExpanded = true
                }
            } label: {
                Image(systemName: "sidebar.right")
                    .rotationEffect(.degrees(180))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)

            Spacer()

            Text("翻译")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(-90))

            Spacer()
        }
        .background(.background)
    }

    private func scheduleTranslationAfterSelectionSettles(_ text: String) {
        selectionDebounceTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            stopTranslation()
            return
        }

        selectionDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                let current = reader.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard current == trimmed else { return }
                handleSelectionChanged(current, force: false)
            }
        }
    }

    private func makeTranslationKey(for text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let mode = TranslationModeID.normalized(from: translationMode)
        let providerIdentity: String

        switch mode {
        case .system:
            providerIdentity = "system"
        case .ai:
            providerIdentity = "ai:\(aiSummaryProvider)|\(aiSummaryExternalEndpoint)|\(aiSummaryExternalModel)"
        case .traditional:
            providerIdentity = "traditional:\(translationTraditionalProvider)|\(translationTraditionalEndpoint)"
        }

        return "\(providerIdentity)|\(sourceLanguageCode)->\(targetLanguageCode)|\(normalized)"
    }

    private func rebuildTranslationConfigurationForCurrentLanguages() {
        #if canImport(Translation)
        if usesSystemTranslationProvider, #available(macOS 15.0, iOS 18.0, *) {
            translationConfiguration = TranslationSession.Configuration(
                source: Locale.Language(identifier: sourceLanguageCode),
                target: Locale.Language(identifier: targetLanguageCode)
            )
        } else {
            translationConfiguration = nil
        }
        #endif
    }

    private func stopTranslation(clearResult: Bool = true) {
        selectionDebounceTask?.cancel()
        selectionDebounceTask = nil

        translationRequestTask?.cancel()
        translationRequestTask = nil

        translationTimeoutTask?.cancel()
        translationTimeoutTask = nil

        reader.isTranslating = false
        reader.translationErrorMessage = ""

        if clearResult {
            reader.translatedText = ""
        }

        currentTranslationKey = ""
    }

    private func retriggerTranslationIfNeeded(force: Bool = false) {
        let trimmed = reader.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        selectionDebounceTask?.cancel()

        if autoTranslateEnabled || force {
            handleSelectionChanged(trimmed, force: true)
        }
    }

    private func handleSelectionChanged(_ text: String, force: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard autoTranslateEnabled || force else { return }
        guard trimmed.count >= 2 else { return }

        guard trimmed.count <= 1500 else {
            stopTranslation()
            reader.translationErrorMessage = "选中文本过长，请缩短选区后再试。"
            return
        }

        guard sourceLanguageCode != targetLanguageCode else {
            stopTranslation()
            reader.translationErrorMessage = "原文语言与译文语言不能相同。"
            return
        }

        let key = makeTranslationKey(for: trimmed)

        if !force, currentTranslationKey == key, reader.isTranslating {
            return
        }

        if !force, currentTranslationKey == key, !reader.translatedText.isEmpty {
            return
        }

        translationTimeoutTask?.cancel()
        translationTimeoutTask = nil

        currentTranslationKey = key
        translationGeneration += 1
        let generation = translationGeneration

        reader.isTranslating = true
        reader.translatedText = ""
        reader.translationErrorMessage = ""

        translationRequestTask?.cancel()
        translationRequestTask = nil

        translationTimeoutTask = Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)

            await MainActor.run {
                guard generation == self.translationGeneration else { return }
                guard self.reader.isTranslating else { return }

                self.translationGeneration += 1
                self.translationRequestTask?.cancel()
                self.translationRequestTask = nil
                self.reader.isTranslating = false
                self.reader.translatedText = ""
                self.reader.translationErrorMessage = "翻译超时。请重新选择文本后再试。"
            }
        }

        if usesSystemTranslationProvider {
            triggerSystemTranslation()
        } else {
            startExternalTranslation(for: trimmed, generation: generation, key: key)
        }
    }

    #if canImport(Translation)
    @available(macOS 15.0, iOS 18.0, *)
    private func translateSelection(using session: TranslationSession) async {
        let generation = translationGeneration
        let text = reader.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = makeTranslationKey(for: text)

        guard !text.isEmpty else {
            await MainActor.run {
                guard generation == self.translationGeneration else { return }
                self.reader.isTranslating = false
            }
            return
        }

        do {
            let response = try await session.translate(text)

            await MainActor.run {
                guard generation == self.translationGeneration else { return }

                let current = self.reader.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
                let currentKey = self.makeTranslationKey(for: current)
                guard currentKey == key else { return }

                self.translationTimeoutTask?.cancel()
                self.translationTimeoutTask = nil

                self.reader.translatedText = response.targetText
                self.reader.translationErrorMessage = ""
                self.reader.isTranslating = false
                self.currentTranslationKey = key
            }
        } catch {
            await MainActor.run {
                guard generation == self.translationGeneration else { return }

                self.translationTimeoutTask?.cancel()
                self.translationTimeoutTask = nil

                self.reader.translatedText = ""
                self.reader.translationErrorMessage = "翻译失败：\(error.localizedDescription)"
                self.reader.isTranslating = false
            }
        }
    }
    #endif

    private var translationLoadingMessage: String {
        if usesSystemTranslationProvider {
            return "正在翻译...\n若首次使用较慢，请先确认系统翻译语言包已安装。"
        }

        if TranslationModeID.normalized(from: translationMode) == .ai {
            return "正在使用 AI 翻译..."
        }

        return "正在通过 \(translationProviderDisplayName) 翻译..."
    }

    private func triggerSystemTranslation() {
        #if canImport(Translation)
        if #available(macOS 15.0, iOS 18.0, *) {
            if translationConfiguration == nil {
                rebuildTranslationConfigurationForCurrentLanguages()
            } else {
                translationConfiguration?.invalidate()
            }
        } else {
            reader.isTranslating = false
            reader.translationErrorMessage = "当前系统版本不支持应用内翻译。"
            translationTimeoutTask?.cancel()
            translationTimeoutTask = nil
        }
        #else
        reader.isTranslating = false
        reader.translationErrorMessage = "当前环境未启用系统翻译框架。"
        translationTimeoutTask?.cancel()
        translationTimeoutTask = nil
        #endif
    }

    private func startExternalTranslation(for text: String, generation: Int, key: String) {
        let request = TextTranslationRequest(
            text: text,
            sourceLanguage: sourceLanguageCode,
            targetLanguage: targetLanguageCode
        )
        let modeID = translationMode
        let traditionalProviderID = translationTraditionalProvider
        let traditionalEndpoint = translationTraditionalEndpoint
        let traditionalPrimaryCredential = translationTraditionalPrimaryCredential
        let traditionalSecondaryCredential = translationTraditionalSecondaryCredential
        let aiProviderID = aiSummaryProvider
        let aiEndpoint = aiSummaryExternalEndpoint
        let aiAPIKey = aiSummaryExternalAPIKey
        let aiModel = aiSummaryExternalModel

        translationRequestTask = Task {
            do {
                let translated = try await TextTranslationService.translate(
                    request: request,
                    modeID: modeID,
                    traditionalProviderID: traditionalProviderID,
                    traditionalEndpoint: traditionalEndpoint,
                    traditionalPrimaryCredential: traditionalPrimaryCredential,
                    traditionalSecondaryCredential: traditionalSecondaryCredential,
                    aiProviderID: aiProviderID,
                    aiEndpoint: aiEndpoint,
                    aiAPIKey: aiAPIKey,
                    aiModel: aiModel
                )

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard generation == self.translationGeneration else { return }

                    let current = self.reader.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let currentKey = self.makeTranslationKey(for: current)
                    guard currentKey == key else { return }

                    self.translationTimeoutTask?.cancel()
                    self.translationTimeoutTask = nil
                    self.translationRequestTask = nil
                    self.reader.translatedText = translated
                    self.reader.translationErrorMessage = ""
                    self.reader.isTranslating = false
                    self.currentTranslationKey = key
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    guard generation == self.translationGeneration else { return }

                    self.translationTimeoutTask?.cancel()
                    self.translationTimeoutTask = nil
                    self.translationRequestTask = nil
                    self.reader.translatedText = ""
                    self.reader.translationErrorMessage = error.localizedDescription
                    self.reader.isTranslating = false
                }
            }
        }
    }
}

final class PDFEditingCoordinator: ObservableObject {
    static let shared = PDFEditingCoordinator()

    @Published var activeDocumentURL: URL?
    @Published var hasUnsavedChanges: Bool = false

    weak var activeBridge: PDFReaderBridge?
    private var activeAccessHandle: SecurityScopedBookmarkStore.AccessHandle?

    private init() { }

    func attach(bridge: PDFReaderBridge, url: URL) {
        if activeDocumentURL != url {
            SecurityScopedBookmarkStore.shared.endAccess(activeAccessHandle)
            activeAccessHandle = SecurityScopedBookmarkStore.shared.beginAccess(forExternalFile: url)
        }
        activeBridge = bridge
        activeDocumentURL = url
        hasUnsavedChanges = bridge.hasUnsavedChanges
    }

    func update(url: URL?, dirty: Bool) {
        guard let url else { return }
        if activeDocumentURL == url {
            hasUnsavedChanges = dirty
        }
    }

    func detachIfNeeded(for url: URL) {
        if activeDocumentURL == url {
            SecurityScopedBookmarkStore.shared.endAccess(activeAccessHandle)
            activeAccessHandle = nil
            activeDocumentURL = nil
            activeBridge = nil
            hasUnsavedChanges = false
        }
    }

    @discardableResult
    func saveActiveDocument() -> Bool {
        guard let activeBridge else { return true }
        let ok = activeBridge.saveDocument()
        hasUnsavedChanges = activeBridge.hasUnsavedChanges
        return ok
    }

    func discardUnsavedState() {
        activeBridge?.discardUnsavedFlagOnly()
        hasUnsavedChanges = false
    }
}

enum PDFMarkupColor: String, CaseIterable, Equatable {
    case yellow
    case green
    case blue
    case pink

    var title: String {
        switch self {
        case .yellow: return "黄色"
        case .green: return "绿色"
        case .blue: return "蓝色"
        case .pink: return "粉色"
        }
    }

    var color: PlatformColor {
        switch self {
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .pink:
            #if os(macOS)
            return NSColor.systemPink
            #else
            return UIColor.systemPink
            #endif
        }
    }

    var previewColor: Color {
        #if os(iOS)
        return Color(uiColor: color)
        #else
        return Color(nsColor: color)
        #endif
    }
}

final class PDFReaderBridge: ObservableObject {
    @Published var currentPage: Int = 1
    @Published var totalPages: Int = 1
    @Published var selectedText: String = ""
    @Published var translatedText: String = ""
    @Published var translationErrorMessage: String = ""
    @Published var isTranslating: Bool = false
    @Published var isTranslationSidebarExpanded: Bool = true
    @Published var zoomPercent: Int = 100
    @Published var annotationColor: PDFMarkupColor = .yellow
    @Published var hasUnsavedChanges: Bool = false

    weak var pdfView: PDFView?
    private var documentURL: URL?

    private struct AnnotationSnapshot {
        let pageIndex: Int
        let subtype: String
        let bounds: CGRect
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
    }

    private enum AnnotationHistoryAction {
        case added([AnnotationSnapshot])
        case removed([AnnotationSnapshot])
    }

    private var annotationHistory: [AnnotationHistoryAction] = []

    var canApplyMarkup: Bool {
        pdfView?.currentSelection != nil
    }

    var canUndoAnnotationAction: Bool {
        !annotationHistory.isEmpty
    }

    var canSave: Bool {
        pdfView?.document != nil && documentURL != nil
    }

    func setDocumentURL(_ url: URL) {
        documentURL = url
        PDFEditingCoordinator.shared.attach(bridge: self, url: url)
    }

    func bind(pdfView: PDFView) {
        self.pdfView = pdfView
        if let documentURL {
            PDFEditingCoordinator.shared.attach(bridge: self, url: documentURL)
        }
    }

    func syncFromPDFView() {
        refreshDocumentInfo()
        refreshSelection()
        refreshZoomPercent()
    }

    func refreshDocumentInfo() {
        guard let pdfView, let document = pdfView.document else {
            currentPage = 1
            totalPages = 1
            return
        }

        totalPages = max(1, document.pageCount)

        if let page = pdfView.currentPage {
            currentPage = max(1, document.index(for: page) + 1)
        } else {
            currentPage = 1
        }
    }

    func refreshSelection() {
        let raw = pdfView?.currentSelection?.string ?? ""
        let normalized = normalizeSelectedText(raw)

        if selectedText != normalized {
            selectedText = normalized
        }
    }

    func refreshZoomPercent() {
        guard let pdfView else {
            zoomPercent = 100
            return
        }

        zoomPercent = max(10, Int((pdfView.scaleFactor * 100).rounded()))
    }

    func addHighlight() {
        guard let selection = pdfView?.currentSelection else { return }
        addMarkup(to: selection, type: .highlight)
    }

    func addUnderline() {
        guard let selection = pdfView?.currentSelection else { return }
        addMarkup(to: selection, type: .underline)
    }

    func undoLastAnnotationAction() {
        guard let lastAction = annotationHistory.popLast(),
              let document = pdfView?.document else { return }

        switch lastAction {
        case .added(let snapshots):
            for snapshot in snapshots.reversed() {
                guard let page = document.page(at: snapshot.pageIndex) else { continue }

                if let annotation = page.annotations.first(where: {
                    $0.type == snapshot.subtype && rectAlmostEqual($0.bounds, snapshot.bounds)
                }) {
                    page.removeAnnotation(annotation)
                }
            }

        case .removed(let snapshots):
            for snapshot in snapshots {
                guard let page = document.page(at: snapshot.pageIndex) else { continue }

                let annotation = PDFAnnotation(
                    bounds: snapshot.bounds,
                    forType: PDFAnnotationSubtype(rawValue: snapshot.subtype),
                    withProperties: nil
                )
                annotation.color = PlatformColor(
                    red: snapshot.red,
                    green: snapshot.green,
                    blue: snapshot.blue,
                    alpha: snapshot.alpha
                )
                page.addAnnotation(annotation)
            }
        }

        markDirty()
    }

    func copySelection() {
        copyText(selectedText)
    }

    func copyText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(trimmed, forType: .string)
        #else
        UIPasteboard.general.string = trimmed
        #endif
    }

    func zoomIn() {
        guard let pdfView else { return }
        pdfView.scaleFactor = min(pdfView.scaleFactor * 1.1, pdfView.maxScaleFactor)
        refreshZoomPercent()
    }

    func zoomOut() {
        guard let pdfView else { return }
        pdfView.scaleFactor = max(pdfView.scaleFactor / 1.1, pdfView.minScaleFactor)
        refreshZoomPercent()
    }

    func resetZoom() {
        guard let pdfView else { return }
        pdfView.autoScales = true
        refreshZoomPercent()
    }

    @discardableResult
    func saveDocument() -> Bool {
        guard let document = pdfView?.document, let documentURL else {
            return false
        }

        let ok = document.write(to: documentURL)
        if ok {
            hasUnsavedChanges = false
            PDFEditingCoordinator.shared.update(url: documentURL, dirty: false)
        }
        return ok
    }

    func discardUnsavedFlagOnly() {
        hasUnsavedChanges = false
        if let documentURL {
            PDFEditingCoordinator.shared.update(url: documentURL, dirty: false)
        }
    }

    private func addMarkup(to selection: PDFSelection, type: PDFAnnotationSubtype) {
        guard let document = pdfView?.document else { return }

        let lineSelections = selection.selectionsByLine()
        var didAdd = false
        var snapshots: [AnnotationSnapshot] = []

        for lineSelection in lineSelections {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard !bounds.isEmpty else { continue }

                let annotation = PDFAnnotation(bounds: bounds, forType: type, withProperties: nil)

                switch type {
                case .highlight:
                    annotation.color = annotationColor.color.withAlphaComponent(0.35)
                case .underline:
                    annotation.color = annotationColor.color
                default:
                    break
                }

                page.addAnnotation(annotation)
                didAdd = true

                let pageIndex = document.index(for: page)
                if let snapshot = snapshot(for: annotation, pageIndex: pageIndex) {
                    snapshots.append(snapshot)
                }
            }
        }

        if didAdd {
            if !snapshots.isEmpty {
                annotationHistory.append(.added(snapshots))
            }
            markDirty()
        }
    }

    private func snapshot(for annotation: PDFAnnotation, pageIndex: Int) -> AnnotationSnapshot? {
        guard let type = annotation.type else { return nil }

        let rgba = rgbaComponents(from: annotation.color)

        return AnnotationSnapshot(
            pageIndex: pageIndex,
            subtype: type,
            bounds: annotation.bounds,
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            alpha: rgba.alpha
        )
    }

    private func rgbaComponents(from color: PlatformColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        #if os(macOS)
        let converted = color.usingColorSpace(.deviceRGB) ?? .black
        return (
            red: converted.redComponent,
            green: converted.greenComponent,
            blue: converted.blueComponent,
            alpha: converted.alphaComponent
        )
        #else
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
        #endif
    }

    private func rectAlmostEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 1.0) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) <= tolerance &&
        abs(lhs.origin.y - rhs.origin.y) <= tolerance &&
        abs(lhs.size.width - rhs.size.width) <= tolerance &&
        abs(lhs.size.height - rhs.size.height) <= tolerance
    }

    private func normalizeSelectedText(_ text: String) -> String {
        guard !text.isEmpty else { return "" }

        var result = text
        result = result.replacingOccurrences(
            of: #"-\s*\n\s*"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\s*\n\s*"#,
            with: " ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"[ \t]+"#,
            with: " ",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func markDirty() {
        hasUnsavedChanges = true
        if let documentURL {
            PDFEditingCoordinator.shared.update(url: documentURL, dirty: true)
        }
    }
}

#if os(iOS)
struct PDFKitContainer: UIViewRepresentable {
    let url: URL
    @ObservedObject var bridge: PDFReaderBridge

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        configure(pdfView, coordinator: context.coordinator)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        context.coordinator.loadDocumentIfNeeded(into: uiView, url: url)
    }

    private func configure(_ pdfView: PDFView, coordinator: Coordinator) {
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = false
        pdfView.pageShadowsEnabled = false
        pdfView.backgroundColor = .clear
        pdfView.usePageViewController(false, withViewOptions: nil)

        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )

        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        bridge.bind(pdfView: pdfView)
        coordinator.loadDocumentIfNeeded(into: pdfView, url: url)
    }

    final class Coordinator: NSObject {
        let bridge: PDFReaderBridge
        private weak var activePDFView: PDFView?
        private var loadedURL: URL?
        private var loadID = UUID()

        init(bridge: PDFReaderBridge) {
            self.bridge = bridge
        }

        func loadDocumentIfNeeded(into pdfView: PDFView, url: URL) {
            activePDFView = pdfView
            if loadedURL == url { return }
            loadedURL = url
            let expectedID = UUID()
            loadID = expectedID
            bridge.setDocumentURL(url)

            Task { @MainActor in
                let loaded = await Task.detached(priority: .userInitiated) {
                    PDFTextExtractor.loadDocument(at: url)
                }.value
                guard self.loadID == expectedID else { return }
                guard let document = loaded.document else { return }
                self.activePDFView?.document = document
                self.bridge.syncFromPDFView()
            }
        }

        @objc func selectionChanged(_ notification: Notification) {
            bridge.refreshSelection()
        }

        @objc func pageChanged(_ notification: Notification) {
            bridge.refreshDocumentInfo()
            bridge.refreshZoomPercent()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
#elseif os(macOS)
struct PDFKitContainer: NSViewRepresentable {
    let url: URL
    @ObservedObject var bridge: PDFReaderBridge

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        configure(pdfView, coordinator: context.coordinator)
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        context.coordinator.loadDocumentIfNeeded(into: nsView, url: url)
    }

    private func configure(_ pdfView: PDFView, coordinator: Coordinator) {
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true

        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )

        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        bridge.bind(pdfView: pdfView)
        coordinator.loadDocumentIfNeeded(into: pdfView, url: url)
    }

    final class Coordinator: NSObject {
        let bridge: PDFReaderBridge
        private weak var activePDFView: PDFView?
        private var loadedURL: URL?
        private var loadID = UUID()

        init(bridge: PDFReaderBridge) {
            self.bridge = bridge
        }

        func loadDocumentIfNeeded(into pdfView: PDFView, url: URL) {
            activePDFView = pdfView
            if loadedURL == url { return }
            loadedURL = url
            let expectedID = UUID()
            loadID = expectedID
            bridge.setDocumentURL(url)

            Task { @MainActor in
                let loaded = await Task.detached(priority: .userInitiated) {
                    PDFTextExtractor.loadDocument(at: url)
                }.value
                guard self.loadID == expectedID else { return }
                guard let document = loaded.document else { return }
                self.activePDFView?.document = document
                self.bridge.syncFromPDFView()
            }
        }

        @objc func selectionChanged(_ notification: Notification) {
            bridge.refreshSelection()
        }

        @objc func pageChanged(_ notification: Notification) {
            bridge.refreshDocumentInfo()
            bridge.refreshZoomPercent()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
#endif
