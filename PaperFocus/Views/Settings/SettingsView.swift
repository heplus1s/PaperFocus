//
//  SettingsView.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

//
//  SettingsView.swift
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

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    private var appleModelAvailability: AppleOnDeviceAvailabilityInfo {
        PaperSummaryService.appleOnDeviceAvailabilityInfo()
    }

    private var systemTranslationAvailability: SystemTranslationAvailabilityInfo {
        TextTranslationService.systemTranslationAvailabilityInfo()
    }

    private var selectedTranslationModePreset: TranslationModePreset {
        AppSettings.translationModePreset(for: translationMode)
    }

    private var selectedTraditionalTranslationProviderPreset: TraditionalTranslationProviderPreset {
        AppSettings.traditionalTranslationProviderPreset(for: translationTraditionalProvider)
    }

    private var usesTraditionalTranslationProvider: Bool {
        TranslationModeID.normalized(from: translationMode) == .traditional
    }

    private var selectedPaperSummaryProviderPreset: PaperSummaryProviderPreset {
        AppSettings.paperSummaryProviderPreset(for: paperSummaryProvider)
    }

    private var supportsExternalPaperSummaryProvider: Bool {
        PaperSummaryProviderID.normalized(from: paperSummaryProvider) != .appleOnDevice
    }

    @AppStorage(AppSettings.focusMinutesKey)
    private var focusMinutes: Int = AppSettings.defaultFocusMinutes

    @AppStorage(AppSettings.breakMinutesKey)
    private var breakMinutes: Int = AppSettings.defaultBreakMinutes

    @AppStorage(AppSettings.defaultReadingModeKey)
    private var defaultReadingMode: String = AppSettings.defaultReadingMode

    @AppStorage(AppSettings.defaultReadingGoalKey)
    private var defaultReadingGoal: String = AppSettings.defaultReadingGoal

    @AppStorage(AppSettings.allowManualPaperTitleInputKey)
    private var allowManualPaperTitleInput: Bool = AppSettings.defaultAllowManualPaperTitleInput

    @AppStorage(AppSettings.useDefaultFocusPresetKey)
    private var useDefaultFocusPreset: Bool = AppSettings.defaultUseDefaultFocusPreset

    @AppStorage(AppSettings.autoStartOnOpenPDFKey)
    private var autoStartOnOpenPDF: Bool = AppSettings.defaultAutoStartOnOpenPDF

    @AppStorage(AppSettings.openPaperInFreeTimingKey)
    private var openPaperInFreeTiming: Bool = AppSettings.defaultOpenPaperInFreeTiming

    @AppStorage(AppSettings.minimumEffectiveMinutesKey)
    private var minimumEffectiveMinutes: Int = AppSettings.defaultMinimumEffectiveMinutes

    @AppStorage(AppSettings.showPaperInspectorHeaderKey)
    private var showPaperInspectorHeader: Bool = AppSettings.defaultShowPaperInspectorHeader

    @AppStorage(AppSettings.showRecentFocusSummaryKey)
    private var showRecentFocusSummary: Bool = AppSettings.defaultShowRecentFocusSummary

    @AppStorage(AppSettings.appLanguageKey)
    private var appLanguage: String = AppSettings.defaultAppLanguage

    @AppStorage(AppSettings.pdfToolbarDisplayModeKey)
    private var pdfToolbarDisplayMode: String = AppSettings.defaultPDFToolbarDisplayMode

    @AppStorage(AppSettings.pdfDefaultAnnotationColorKey)
    private var pdfDefaultAnnotationColor: String = AppSettings.defaultPDFAnnotationColor

    @AppStorage(AppSettings.translationAutoTranslateEnabledKey)
    private var translationAutoTranslateEnabled: Bool = AppSettings.defaultTranslationAutoTranslateEnabled

    @AppStorage(AppSettings.translationSourceLanguageKey)
    private var translationSourceLanguage: String = AppSettings.defaultTranslationSourceLanguage

    @AppStorage(AppSettings.translationTargetLanguageKey)
    private var translationTargetLanguage: String = AppSettings.defaultTranslationTargetLanguage

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
    @State private var lastTraditionalTranslationProvider: String = AppSettings.defaultTranslationTraditionalProvider

    @AppStorage(AppSettings.paperSummaryProviderKey)
    private var paperSummaryProvider: String = AppSettings.defaultPaperSummaryProvider

    @AppStorage(AppSettings.paperSummaryExternalEndpointKey)
    private var paperSummaryExternalEndpoint: String = AppSettings.defaultPaperSummaryExternalEndpoint

    @AppStorage(AppSettings.paperSummaryExternalAPIKey)
    private var paperSummaryExternalAPIKey: String = AppSettings.defaultPaperSummaryExternalAPIKey

    @AppStorage(AppSettings.paperSummaryExternalModelKey)
    private var paperSummaryExternalModel: String = AppSettings.defaultPaperSummaryExternalModel
    @State private var lastPaperSummaryProvider: String = AppSettings.defaultPaperSummaryProvider
    @State private var isImportingLibrary = false
    @State private var libraryImportMessage = ""
    @State private var showLibraryImportAlert = false
    @State private var showClearDatabaseConfirmation = false
    @State private var databaseResetMessage = ""
    @State private var showDatabaseResetAlert = false
    @AppStorage(AppSettings.zoteroLinkedDisplayPathKey)
    private var zoteroLinkedDisplayPath: String = AppSettings.defaultLinkedLibraryDisplayPath
    @AppStorage(AppSettings.zoteroLinkedDisplayNameKey)
    private var zoteroLinkedDisplayName: String = AppSettings.defaultLinkedLibraryDisplayName
    @AppStorage(AppSettings.endNoteLinkedDisplayPathKey)
    private var endNoteLinkedDisplayPath: String = AppSettings.defaultLinkedLibraryDisplayPath
    @AppStorage(AppSettings.endNoteLinkedDisplayNameKey)
    private var endNoteLinkedDisplayName: String = AppSettings.defaultLinkedLibraryDisplayName
    @AppStorage(AppSettings.libraryAutoSyncOnLaunchKey)
    private var libraryAutoSyncOnLaunch: Bool = AppSettings.defaultLibraryAutoSyncOnLaunch
    @AppStorage(AppSettings.libraryAutoRefreshIntervalMinutesKey)
    private var libraryAutoRefreshIntervalMinutes: Int = AppSettings.defaultLibraryAutoRefreshIntervalMinutes
    @AppStorage(AppSettings.preferLocalZoteroLibraryKey)
    private var preferLocalZoteroLibrary = AppSettings.defaultPreferLocalZoteroLibrary
    @AppStorage(AppSettings.zoteroSoleLibraryKey)
    private var zoteroSoleLibrary = AppSettings.defaultZoteroSoleLibrary
    @AppStorage(AppSettings.importCopiesAttachmentsKey)
    private var importCopiesAttachments = AppSettings.defaultImportCopiesAttachments
    @AppStorage(AppSettings.zoteroAccountAPIKey)
    private var zoteroAccountAPIKey = ""
    @State private var showImportModes = false
    @State private var importMode: LibraryImportMode = .zotero

    #if os(macOS)
    @AppStorage(AppSettings.macReadingAIDialogEnabledKey)
    private var macReadingAIDialogEnabled: Bool = AppSettings.defaultMacReadingAIDialogEnabled
    @AppStorage(AppSettings.macShowMainInterfaceSettingsKey)
    private var macShowMainInterfaceSettings: Bool = AppSettings.defaultMacShowMainInterfaceSettings
    @AppStorage(AppSettings.macAllowMainFocusSidebarCollapseKey)
    private var macAllowMainFocusSidebarCollapse: Bool = AppSettings.defaultMacAllowMainFocusSidebarCollapse
    #endif

    private let libraryImportService = LibraryImportService()
    private let showsToolbarPlaceholders: Bool

    init(showsToolbarPlaceholders: Bool = false) {
        self.showsToolbarPlaceholders = showsToolbarPlaceholders
    }

    var body: some View {
        Form {
            Section("界面显示") {
                Toggle("右侧栏显示顶部标题卡片", isOn: $showPaperInspectorHeader)
                Toggle("右侧栏显示最近专注摘要", isOn: $showRecentFocusSummary)

                #if os(macOS)
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("在主界面显示设置入口", isOn: $macShowMainInterfaceSettings)
                    settingsHint("开启后，左上主菜单会显示“设置”按钮，并可在主窗口内直接打开设置；关闭后，只能从 macOS 顶部菜单栏打开独立设置页。")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Toggle("允许主界面折叠专注栏", isOn: $macAllowMainFocusSidebarCollapse)
                    settingsHint("开启后，首页和文献库页左侧的专注阅读栏会显示折叠按钮；关闭时保持固定展开。")
                }
                #endif
            }

            Section("语言") {
                Picker("界面语言", selection: $appLanguage) {
                    ForEach(AppSettings.interfaceLanguageOptions, id: \.code) { option in
                        Text(option.name).tag(option.code)
                    }
                }

                settingsHint("默认跟随系统。仅影响应用界面语言，不改变翻译源语言和译文语言。")
            }

            Section("本地文献库关联") {
                Toggle("优先使用本机 Zotero 文献库", isOn: $preferLocalZoteroLibrary)
                #if os(iOS)
                settingsHint("在 iPhone 和 iPad 上，请使用系统文件选择器选择 Zotero 数据目录，或填写 API 密钥。此选项不会自动搜索 Mac 上的默认数据目录。关闭后，继续使用 PaperFocus 自己的文献库。")
                #else
                settingsHint("开启后，若发现唯一的本机 Zotero 文献库且尚未关联，启动时会自动关联该文献库，而不另行建立独立文献库。关闭后，继续使用 PaperFocus 自己的文献库。")
                #endif

                Toggle("仅使用 Zotero 文献库", isOn: $zoteroSoleLibrary)
                settingsHint("开启后，文献列表只显示已关联的 Zotero 文献，并暂停使用应用内文献库。已保存的应用内条目不会被删除，关闭此选项后会重新显示。")

                #if os(iOS)
                settingsHint("在 iPhone 和 iPad 上，PaperFocus 直接打开“文件”中授权的原始 PDF，不会把文件复制到应用内。")
                #else
                Toggle("导入时复制附件", isOn: $importCopiesAttachments)
                settingsHint("关闭时，直接打开 Zotero 文献库中的原始附件，不在 PaperFocus 中生成副本。开启时，导入过程可以将附件复制到应用目录。")
                #endif

                SecureField("Zotero API 密钥", text: $zoteroAccountAPIKey)
                settingsHint("账户关联使用 Zotero 网站生成的 API 密钥。密钥仅保存在本机设置中。")

                settingsActionRow(
                    zoteroLinkedDisplayPath.isEmpty ? "关联 Zotero 数据目录" : "重新关联 Zotero 数据目录",
                    systemImage: "externaldrive.badge.person.crop"
                ) {
                    linkZoteroLibrary()
                }
                .disabled(isImportingLibrary)

                if !zoteroLinkedDisplayPath.isEmpty {
                    LabeledContent("Zotero 路径") {
                        Text(zoteroLinkedDisplayPath)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    settingsActionRow("刷新 Zotero 关联库", systemImage: "arrow.clockwise") {
                        refreshLinkedZoteroLibrary()
                    }
                    .disabled(isImportingLibrary)

                    settingsActionRow("断开 Zotero", systemImage: "trash", role: .destructive) {
                        unlinkZoteroLibrary()
                    }
                    .disabled(isImportingLibrary)
                }

                settingsActionRow(
                    endNoteLinkedDisplayPath.isEmpty ? "关联 EndNote XML" : "重新关联 EndNote XML",
                    systemImage: "doc.text.magnifyingglass"
                ) {
                    linkEndNoteLibrary()
                }
                .disabled(isImportingLibrary)

                if !endNoteLinkedDisplayPath.isEmpty {
                    LabeledContent("EndNote 路径") {
                        Text(endNoteLinkedDisplayPath)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    settingsActionRow("刷新 EndNote 关联库", systemImage: "arrow.clockwise") {
                        refreshLinkedEndNoteLibrary()
                    }
                    .disabled(isImportingLibrary)

                    settingsActionRow("断开 EndNote", systemImage: "trash", role: .destructive) {
                        unlinkEndNoteLibrary()
                    }
                    .disabled(isImportingLibrary)
                }

                if isImportingLibrary {
                    ProgressView("正在同步本地文献库…")
                }

                Toggle("每次启动时自动同步文库", isOn: $libraryAutoSyncOnLaunch)

                Picker("软件运行时自动刷新", selection: $libraryAutoRefreshIntervalMinutes) {
                    ForEach(AppSettings.libraryAutoRefreshOptions, id: \.minutes) { option in
                        Text(LocalizedStringKey(option.name)).tag(option.minutes)
                    }
                }

                #if os(iOS)
                settingsHint("在 iPhone 和 iPad 上，通过系统文件选择器关联 Zotero 或 EndNote。关闭“导入时复制附件”后，将直接打开原始文件。PaperFocus 保存阅读状态与摘要，不改写外部文献库。")
                #else
                settingsHint("Zotero 可关联本机数据目录，EndNote 使用 XML。关闭“导入时复制附件”后，将直接打开原始文件。PaperFocus 保存阅读状态与摘要，不改写外部文献库。")
                #endif
            }

            Section("专注默认") {
                Toggle("使用默认专注预设", isOn: $useDefaultFocusPreset)

                Picker("默认专注时长", selection: $focusMinutes) {
                    Text("15 分钟").tag(15)
                    Text("25 分钟").tag(25)
                    Text("45 分钟").tag(45)
                    Text("60 分钟").tag(60)
                    Text("90 分钟").tag(90)
                }
                .disabled(!useDefaultFocusPreset)

                Picker("默认休息时长", selection: $breakMinutes) {
                    Text("5 分钟").tag(5)
                    Text("10 分钟").tag(10)
                    Text("15 分钟").tag(15)
                    Text("20 分钟").tag(20)
                }
                .disabled(!useDefaultFocusPreset)

                Picker("默认阅读模式", selection: $defaultReadingMode) {
                    ForEach(AppSettings.readingModes, id: \.self) { mode in
                        Text(LocalizedStringKey(mode)).tag(mode)
                    }
                }
                .disabled(!useDefaultFocusPreset)

                Picker("默认阅读目标", selection: $defaultReadingGoal) {
                    ForEach(AppSettings.readingGoals, id: \.self) { goal in
                        Text(LocalizedStringKey(goal)).tag(goal)
                    }
                }
                .disabled(!useDefaultFocusPreset)

                Toggle("允许手动输入当前文献标题", isOn: $allowManualPaperTitleInput)
                settingsHint("默认关闭。当前文献标题会自动从文献库已选论文带入；开启后才允许在计时器中手动修改。")
            }

            Section("阅读联动") {
                Toggle("打开 PDF 时自动开始计时", isOn: $autoStartOnOpenPDF)

                VStack(alignment: .leading, spacing: 6) {
                    Toggle("打开论文时使用自由计时", isOn: $openPaperInFreeTiming)
                        .disabled(!autoStartOnOpenPDF)
                    settingsHint("开启后，直接从论文进入的自动计时会从 00:00 向上累计，不套用计划时长；达到有效记录阈值后仍记为有效。")
                }

                Stepper(value: $minimumEffectiveMinutes, in: 1...60) {
                    HStack {
                        Text("有效记录阈值")
                        Spacer()
                        Text("\(minimumEffectiveMinutes) 分钟")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("PDF 阅读器") {
                Picker("工具栏样式", selection: $pdfToolbarDisplayMode) {
                    Text("仅图标").tag("iconOnly")
                    Text("图标 + 文字").tag("iconAndText")
                }

                Picker("默认标注颜色", selection: $pdfDefaultAnnotationColor) {
                    Text("黄色").tag("yellow")
                    Text("绿色").tag("green")
                    Text("蓝色").tag("blue")
                    Text("粉色").tag("pink")
                }
            }

            Section("翻译") {
                Toggle("选中后自动翻译", isOn: $translationAutoTranslateEnabled)

                Picker("翻译模式", selection: $translationMode) {
                    ForEach(AppSettings.translationModes, id: \.id) { item in
                        Text(LocalizedStringKey(item.name)).tag(item.id)
                            .disabled(item.id == TranslationModeID.system.rawValue && !systemTranslationAvailability.isSupported)
                    }
                }

                Picker("原文语言", selection: $translationSourceLanguage) {
                    ForEach(AppSettings.translationLanguages, id: \.code) { item in
                        Text(AppSettings.localizedLanguageName(for: item.code, appLanguage: appLanguage)).tag(item.code)
                    }
                }

                Picker("译文语言", selection: $translationTargetLanguage) {
                    ForEach(AppSettings.translationLanguages, id: \.code) { item in
                        Text(AppSettings.localizedLanguageName(for: item.code, appLanguage: appLanguage)).tag(item.code)
                    }
                }

                if !systemTranslationAvailability.isSupported {
                    settingsHint(systemTranslationAvailability.message ?? "系统翻译当前不可用。")
                }

                if usesTraditionalTranslationProvider {
                    Picker("专业翻译提供方", selection: $translationTraditionalProvider) {
                        ForEach(AppSettings.traditionalTranslationProviders, id: \.id) { item in
                            Text(LocalizedStringKey(item.name)).tag(item.id)
                        }
                    }

                    TextField(LocalizedStringKey(selectedTraditionalTranslationProviderPreset.endpointLabel), text: $translationTraditionalEndpoint)

                    if translationTraditionalProvider == TraditionalTranslationProviderID.deepL.rawValue {
                        SecureField(LocalizedStringKey(selectedTraditionalTranslationProviderPreset.primaryCredentialLabel), text: $translationTraditionalPrimaryCredential)
                    } else {
                        TextField(LocalizedStringKey(selectedTraditionalTranslationProviderPreset.primaryCredentialLabel), text: $translationTraditionalPrimaryCredential)
                    }

                    if !selectedTraditionalTranslationProviderPreset.secondaryCredentialLabel.isEmpty {
                        SecureField(LocalizedStringKey(selectedTraditionalTranslationProviderPreset.secondaryCredentialLabel), text: $translationTraditionalSecondaryCredential)
                    }

                    settingsHint(selectedTraditionalTranslationProviderPreset.helperText)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        settingsHint(selectedTranslationModePreset.helperText)
                        if TranslationModeID.normalized(from: translationMode) == .ai {
                            settingsHint("当前 AI 提供方：\(selectedPaperSummaryProviderPreset.name)")
                        }
                    }
                }
            }

            Section("AI 设置") {
                #if os(macOS)
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("启用专注阅读 AI 提问", isOn: $macReadingAIDialogEnabled)
                    settingsHint("仅在 macOS 的 PDF 专注阅读中生效。开启后，中栏会显示 AI 提问，并与下方专注阅读栏联动；关闭后，中栏保持空白，专注阅读栏仍可正常计时。")
                }
                #endif

                Picker("AI 提供方", selection: $paperSummaryProvider) {
                    ForEach(AppSettings.paperSummaryProviders, id: \.id) { item in
                        Text(LocalizedStringKey(item.name)).tag(item.id)
                            .disabled(item.id == PaperSummaryProviderID.appleOnDevice.rawValue && !appleModelAvailability.isHardwareSupported)
                    }
                }

                if !appleModelAvailability.isHardwareSupported {
                    settingsHint(appleModelAvailability.message ?? "Apple 本地模型不可用。")
                }

                if supportsExternalPaperSummaryProvider {
                    TextField(LocalizedStringKey(selectedPaperSummaryProviderPreset.endpointLabel), text: $paperSummaryExternalEndpoint)
                    TextField("模型名称", text: $paperSummaryExternalModel)
                    SecureField(LocalizedStringKey(selectedPaperSummaryProviderPreset.keyLabel), text: $paperSummaryExternalAPIKey)
                    settingsHint(selectedPaperSummaryProviderPreset.helperText)
                } else {
                    settingsHint("使用 Apple Intelligence 本地模型处理 AI 能力。")
                }

            }

            Section("一次性导入") {
                settingsActionRow("导入 Zotero JSON", systemImage: "tray.and.arrow.down") {
                    importMode = .zotero
                    showImportModes = true
                }
                .disabled(isImportingLibrary)

                settingsActionRow("导入 EndNote XML", systemImage: "doc.badge.plus") {
                    importMode = .endNote
                    showImportModes = true
                }
                .disabled(isImportingLibrary)

                settingsActionRow("导入 PDF 文件夹", systemImage: "folder.badge.plus") {
                    importMode = .pdfFolder
                    showImportModes = true
                }
                .disabled(isImportingLibrary)

                settingsHint("如果只是临时迁移文献或导入历史 PDF，可以继续使用一次性导入。")
            }

            Section("关于软件") {
                #if os(macOS)
                settingsActionRow("关于 PaperFocus", systemImage: "info.circle") {
                    openWindow(id: "about-paperfocus")
                }
                #else
                NavigationLink {
                    AboutPaperFocusView()
                } label: {
                    Label("关于 PaperFocus", systemImage: "info.circle")
                }
                #endif

                settingsActionRow("清空应用数据库", systemImage: "trash", role: .destructive) {
                    showClearDatabaseConfirmation = true
                }

                settingsHint("会删除 PaperFocus 当前保存的文献条目、阅读记录和专注任务，并断开本地文献库关联。不会删除 Zotero / EndNote 原始数据库，也不会删除原始 PDF 文件。")
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .alert("文献导入", isPresented: $showLibraryImportAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(libraryImportMessage)
        }
        .sheet(isPresented: $showImportModes) {
            LibraryImportModeSheet(initialMode: importMode) { urls in
                _ = try await libraryImportService.importStandalonePDFs(from: urls, into: modelContext)
            } onFinished: { message in
                libraryImportMessage = message
                showLibraryImportAlert = true
            }
        }
        .confirmationDialog("确认清空应用数据库？", isPresented: $showClearDatabaseConfirmation, titleVisibility: .visible) {
            Button("清空应用数据库", role: .destructive) {
                clearApplicationDatabase()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("此操作会删除 PaperFocus 当前保存的文献、阅读记录与专注任务，并断开 Zotero / EndNote 关联；不会删除外部文献库和原始 PDF。")
        }
        .alert("数据维护", isPresented: $showDatabaseResetAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(databaseResetMessage)
        }
        .onAppear {
            if !systemTranslationAvailability.isSupported,
               translationMode == TranslationModeID.system.rawValue {
                translationMode = TranslationModeID.ai.rawValue
            }
            syncTraditionalTranslationFields(from: translationTraditionalProvider, to: translationTraditionalProvider, force: true)
            lastTraditionalTranslationProvider = translationTraditionalProvider
            if !appleModelAvailability.isHardwareSupported,
               paperSummaryProvider == PaperSummaryProviderID.appleOnDevice.rawValue {
                paperSummaryProvider = PaperSummaryProviderID.deepseek.rawValue
            }
            syncPaperSummaryFields(from: paperSummaryProvider, to: paperSummaryProvider, force: true)
            lastPaperSummaryProvider = paperSummaryProvider
        }
        .onChange(of: translationTraditionalProvider) { newValue in
            syncTraditionalTranslationFields(from: lastTraditionalTranslationProvider, to: newValue)
            lastTraditionalTranslationProvider = newValue
        }
        .onChange(of: paperSummaryProvider) { newValue in
            syncPaperSummaryFields(from: lastPaperSummaryProvider, to: newValue)
            lastPaperSummaryProvider = newValue
        }
        .toolbar {
            if showsToolbarPlaceholders {
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

                #if os(macOS)
                if #available(macOS 26.0, *) {
                    ToolbarItemGroup(placement: .automatic) {
                        toolbarTrailingPlaceholder
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItemGroup(placement: .automatic) {
                        toolbarTrailingPlaceholder
                    }
                }
                #else
                ToolbarItemGroup(placement: .automatic) {
                    toolbarTrailingPlaceholder
                }
                #endif
            }
        }
    }

    @ViewBuilder
    private var toolbarLeadingPlaceholder: some View {
        #if os(macOS)
        Color.clear
            .frame(width: 60, height: 1)
            .accessibilityHidden(true)
        #else
        EmptyView()
        #endif
    }

    @ViewBuilder
    private var toolbarTrailingPlaceholder: some View {
        #if os(macOS)
        Color.clear
            .frame(width: 220, height: 1)
            .accessibilityHidden(true)
        #else
        EmptyView()
        #endif
    }

    private func settingsHint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func settingsActionRow(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                Text(title)
                Spacer()
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .foregroundStyle(role == .destructive ? Color.red : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func syncPaperSummaryFields(from oldProviderID: String, to newProviderID: String, force: Bool = false) {
        let oldPreset = AppSettings.paperSummaryProviderPreset(for: oldProviderID)
        let newPreset = AppSettings.paperSummaryProviderPreset(for: newProviderID)

        guard newPreset.id != PaperSummaryProviderID.appleOnDevice.rawValue else { return }

        if force || paperSummaryExternalEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || paperSummaryExternalEndpoint == oldPreset.defaultEndpoint {
            paperSummaryExternalEndpoint = newPreset.defaultEndpoint
        }

        if force || paperSummaryExternalModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || paperSummaryExternalModel == oldPreset.defaultModel {
            paperSummaryExternalModel = newPreset.defaultModel
        }
    }

    private func syncTraditionalTranslationFields(from oldProviderID: String, to newProviderID: String, force: Bool = false) {
        let oldPreset = AppSettings.traditionalTranslationProviderPreset(for: oldProviderID)
        let newPreset = AppSettings.traditionalTranslationProviderPreset(for: newProviderID)

        if force || translationTraditionalEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || translationTraditionalEndpoint == oldPreset.defaultEndpoint {
            translationTraditionalEndpoint = newPreset.defaultEndpoint
        }
    }

    private func linkZoteroLibrary() {
        importMode = .zotero
        showImportModes = true
    }

    private func refreshLinkedZoteroLibrary() {
        performLibraryImport {
            let summary = try await libraryImportService.refreshLinkedZoteroLibrary(into: modelContext)
            libraryImportMessage = summary.syncMessage
            return summary
        }
    }

    private func unlinkZoteroLibrary() {
        SecurityScopedBookmarkStore.shared.clearBookmark(for: .zoteroLocal)
        AppSettings.clearZoteroLinkKind()
        zoteroLinkedDisplayPath = ""
        zoteroLinkedDisplayName = ""
        libraryImportMessage = "已断开 Zotero 文献库关联。已导入的文献记录会保留，但不再继续同步。"
        showLibraryImportAlert = true
    }

    private func linkEndNoteLibrary() {
        importMode = .endNote
        showImportModes = true
    }

    private func refreshLinkedEndNoteLibrary() {
        guard !endNoteLinkedDisplayPath.isEmpty else { return }
        performLibraryImport {
            let summary = try await libraryImportService.refreshLinkedEndNoteXML(from: endNoteLinkedDisplayPath, into: modelContext)
            libraryImportMessage = summary.syncMessage
            return summary
        }
    }

    private func unlinkEndNoteLibrary() {
        SecurityScopedBookmarkStore.shared.clearBookmark(for: .endNoteXML)
        endNoteLinkedDisplayPath = ""
        endNoteLinkedDisplayName = ""
        libraryImportMessage = "已断开 EndNote 本地库关联。已导入的文献记录会保留，但不再继续同步。"
        showLibraryImportAlert = true
    }

    #if os(macOS)
    private func importZoteroLibrary() {
        guard let url = chooseFile(
            title: "选择 Zotero JSON 导出文件",
            prompt: "导入",
            contentTypes: [.json]
        ) else { return }

        performLibraryImport {
            try await libraryImportService.importZotero(from: url, into: modelContext)
        }
    }

    private func importEndNoteLibrary() {
        guard let url = chooseFile(
            title: "选择 EndNote XML 导出文件",
            prompt: "导入",
            contentTypes: [.xml]
        ) else { return }

        performLibraryImport {
            try await libraryImportService.importEndNoteXML(from: url, into: modelContext)
        }
    }

    private func importPDFFolder() {
        guard let url = chooseDirectory(
            title: "选择 PDF 文件夹",
            prompt: "导入文件夹"
        ) else { return }

        performLibraryImport {
            try await libraryImportService.importPDFFolder(from: url, into: modelContext)
        }
    }

    #endif

    private func performLibraryImport(_ operation: @escaping @MainActor () async throws -> LibraryImportSummary) {
        isImportingLibrary = true
        libraryImportMessage = ""

        Task {
            do {
                let summary = try await operation()
                if libraryImportMessage.isEmpty {
                    libraryImportMessage = summary.importMessage
                }
                showLibraryImportAlert = true
            } catch {
                libraryImportMessage = error.localizedDescription
                showLibraryImportAlert = true
            }
            isImportingLibrary = false
        }
    }

    private func clearApplicationDatabase() {
        do {
            let readingSessions = try modelContext.fetch(FetchDescriptor<ReadingSession>())
            let focusTasks = try modelContext.fetch(FetchDescriptor<FocusTask>())
            let papers = try modelContext.fetch(FetchDescriptor<Paper>())

            for session in readingSessions {
                modelContext.delete(session)
            }

            for task in focusTasks {
                modelContext.delete(task)
            }

            for paper in papers {
                modelContext.delete(paper)
            }

            try modelContext.save()

            SecurityScopedBookmarkStore.shared.clearBookmark(for: .zoteroLocal)
            AppSettings.clearZoteroLinkKind()
            SecurityScopedBookmarkStore.shared.clearBookmark(for: .endNoteXML)
            zoteroLinkedDisplayPath = ""
            zoteroLinkedDisplayName = ""
            endNoteLinkedDisplayPath = ""
            endNoteLinkedDisplayName = ""

            databaseResetMessage = "已清空 PaperFocus 应用数据库，并断开本地文献库关联。外部 Zotero / EndNote 原库和原始 PDF 没有被删除。"
            showDatabaseResetAlert = true
        } catch {
            databaseResetMessage = "清空应用数据库失败：\(error.localizedDescription)"
            showDatabaseResetAlert = true
        }
    }

    #if os(macOS)
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
    #endif
}
