//
//  PaperFocusApp.swift
//  PaperFocus
//
//  Created by PaperFocus on 24/3/2026.
//

import SwiftUI
import SwiftData
import Foundation

@MainActor
private enum PaperFocusModelStore {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: Paper.self,
                ReadingSession.self,
                FocusTask.self
            )
        } catch {
            fatalError("PaperFocus could not open its library store: \(error)")
        }
    }()
}

@main
struct PaperFocusApp: App {
    @AppStorage(AppSettings.appLanguageKey)
    private var appLanguage: String = AppSettings.defaultAppLanguage

    private var appLocale: Locale {
        AppSettings.interfaceLocale(for: appLanguage)
    }

    private var aboutWindowTitle: String {
        AppSettings.localizedString(
            "window.aboutPaperFocus",
            defaultValue: "About PaperFocus",
            appLanguage: appLanguage
        )
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .id(appLanguage)
                .environment(\.locale, appLocale)
                .onOpenURL { url in
                    FocusLiveActivityActionRouter.handle(url)
                }
        }
        .modelContainer(PaperFocusModelStore.container)
        #if os(macOS)
        .defaultSize(width: 1360, height: 760)
        .commands {
            PaperFocusMenuCommands(appLanguage: appLanguage)
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .id(appLanguage)
                .environment(\.locale, appLocale)
                .frame(width: 520, height: 460)
        }
        .modelContainer(PaperFocusModelStore.container)

        Window(aboutWindowTitle, id: AppWindowID.about) {
            NavigationStack {
                AboutPaperFocusView()
                    .id(appLanguage)
                    .environment(\.locale, appLocale)
            }
            .frame(minWidth: 480, idealWidth: 520, minHeight: 360, idealHeight: 420)
        }
        #endif
    }
}

#if os(macOS)
private enum AppWindowID {
    static let about = "about-paperfocus"
}

enum AppMenuLibraryCommand: String {
    case linkZotero
    case refreshZotero
    case unlinkZotero
    case linkEndNote
    case refreshEndNote
    case unlinkEndNote
    case importZoteroJSON
    case importEndNoteXML
    case importPDFFolder
}

extension Notification.Name {
    static let appMenuLibraryCommand = Notification.Name("appMenuLibraryCommand")
}

private struct PaperFocusMenuCommands: Commands {
    let appLanguage: String
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @AppStorage(AppSettings.showPaperInspectorHeaderKey)
    private var showPaperInspectorHeader: Bool = AppSettings.defaultShowPaperInspectorHeader
    @AppStorage(AppSettings.showRecentFocusSummaryKey)
    private var showRecentFocusSummary: Bool = AppSettings.defaultShowRecentFocusSummary
    @AppStorage(AppSettings.macShowMainInterfaceSettingsKey)
    private var macShowMainInterfaceSettings: Bool = AppSettings.defaultMacShowMainInterfaceSettings
    @AppStorage(AppSettings.macAllowMainFocusSidebarCollapseKey)
    private var macAllowMainFocusSidebarCollapse: Bool = AppSettings.defaultMacAllowMainFocusSidebarCollapse
    @AppStorage(AppSettings.autoStartOnOpenPDFKey)
    private var autoStartOnOpenPDF: Bool = AppSettings.defaultAutoStartOnOpenPDF
    @AppStorage(AppSettings.openPaperInFreeTimingKey)
    private var openPaperInFreeTiming: Bool = AppSettings.defaultOpenPaperInFreeTiming
    @AppStorage(AppSettings.minimumEffectiveMinutesKey)
    private var minimumEffectiveMinutes: Int = AppSettings.defaultMinimumEffectiveMinutes
    @AppStorage(AppSettings.translationAutoTranslateEnabledKey)
    private var translationAutoTranslateEnabled: Bool = AppSettings.defaultTranslationAutoTranslateEnabled
    @AppStorage(AppSettings.translationSourceLanguageKey)
    private var translationSourceLanguage: String = AppSettings.defaultTranslationSourceLanguage
    @AppStorage(AppSettings.translationTargetLanguageKey)
    private var translationTargetLanguage: String = AppSettings.defaultTranslationTargetLanguage
    @AppStorage(AppSettings.translationModeKey)
    private var translationMode: String = AppSettings.defaultTranslationMode
    @AppStorage(AppSettings.paperSummaryProviderKey)
    private var paperSummaryProvider: String = AppSettings.defaultPaperSummaryProvider
    @AppStorage(AppSettings.zoteroLinkedDisplayPathKey)
    private var zoteroLinkedDisplayPath: String = AppSettings.defaultLinkedLibraryDisplayPath
    @AppStorage(AppSettings.endNoteLinkedDisplayPathKey)
    private var endNoteLinkedDisplayPath: String = AppSettings.defaultLinkedLibraryDisplayPath

    private var aboutMenuTitle: String {
        AppSettings.localizedString("menu.aboutPaperFocus", defaultValue: "About PaperFocus", appLanguage: appLanguage)
    }

    private var importSettingsTitle: String {
        AppSettings.localizedString("menu.openSettings", defaultValue: "打开设置…", appLanguage: appLanguage)
    }

    private var systemTranslationAvailability: SystemTranslationAvailabilityInfo {
        TextTranslationService.systemTranslationAvailabilityInfo()
    }

    private var appleModelAvailability: AppleOnDeviceAvailabilityInfo {
        PaperSummaryService.appleOnDeviceAvailabilityInfo()
    }

    private func localized(_ key: String, defaultValue: String? = nil) -> String {
        AppSettings.localizedString(key, defaultValue: defaultValue ?? key, appLanguage: appLanguage)
    }

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(aboutMenuTitle) {
                openWindow(id: AppWindowID.about)
            }
        }

        CommandGroup(after: .importExport) {
            Divider()

            Button(zoteroLinkedDisplayPath.isEmpty ? localized("关联 Zotero 数据目录…") : localized("重新关联 Zotero 数据目录…")) {
                postLibraryCommand(.linkZotero)
            }

            Button(localized("刷新 Zotero 关联库")) {
                postLibraryCommand(.refreshZotero)
            }
            .disabled(zoteroLinkedDisplayPath.isEmpty)

            Button(localized("断开 Zotero"), role: .destructive) {
                postLibraryCommand(.unlinkZotero)
            }
            .disabled(zoteroLinkedDisplayPath.isEmpty)

            Divider()

            Button(endNoteLinkedDisplayPath.isEmpty ? localized("关联 EndNote XML…") : localized("重新关联 EndNote XML…")) {
                postLibraryCommand(.linkEndNote)
            }

            Button(localized("刷新 EndNote 关联库")) {
                postLibraryCommand(.refreshEndNote)
            }
            .disabled(endNoteLinkedDisplayPath.isEmpty)

            Button(localized("断开 EndNote"), role: .destructive) {
                postLibraryCommand(.unlinkEndNote)
            }
            .disabled(endNoteLinkedDisplayPath.isEmpty)

            Divider()

            Button(localized("导入 Zotero JSON…")) {
                postLibraryCommand(.importZoteroJSON)
            }

            Button(localized("导入 EndNote XML…")) {
                postLibraryCommand(.importEndNoteXML)
            }

            Button(localized("导入 PDF 文件夹…")) {
                postLibraryCommand(.importPDFFolder)
            }

            Divider()

            Button(importSettingsTitle) {
                openSettings()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        CommandGroup(after: .toolbar) {
            Toggle(isOn: $showPaperInspectorHeader) {
                Text(localized("右侧栏显示顶部标题卡片"))
            }
            Toggle(isOn: $showRecentFocusSummary) {
                Text(localized("右侧栏显示最近专注摘要"))
            }
            Toggle(isOn: $macShowMainInterfaceSettings) {
                Text(localized("在主界面显示设置入口"))
            }
            Toggle(isOn: $macAllowMainFocusSidebarCollapse) {
                Text(localized("允许主界面折叠专注栏"))
            }

            Divider()

            Toggle(isOn: $autoStartOnOpenPDF) {
                Text(localized("打开 PDF 时自动开始计时"))
            }
            Toggle(isOn: $openPaperInFreeTiming) {
                Text(localized("打开论文时使用自由计时"))
            }
                .disabled(!autoStartOnOpenPDF)

            Picker(localized("有效记录阈值"), selection: $minimumEffectiveMinutes) {
                ForEach([5, 10, 15, 20, 30, 45, 60], id: \.self) { minutes in
                    Text("\(minutes) 分钟").tag(minutes)
                }
            }

            Divider()

            Toggle(isOn: $translationAutoTranslateEnabled) {
                Text(localized("选中后自动翻译"))
            }

            Picker(localized("翻译模式"), selection: $translationMode) {
                ForEach(AppSettings.translationModes, id: \.id) { item in
                    Text(localized(item.name))
                        .tag(item.id)
                        .disabled(item.id == TranslationModeID.system.rawValue && !systemTranslationAvailability.isSupported)
                }
            }

            Picker(localized("原文语言"), selection: $translationSourceLanguage) {
                ForEach(AppSettings.translationLanguages, id: \.code) { item in
                    Text(AppSettings.localizedLanguageName(for: item.code, appLanguage: appLanguage)).tag(item.code)
                }
            }

            Picker(localized("译文语言"), selection: $translationTargetLanguage) {
                ForEach(AppSettings.translationLanguages, id: \.code) { item in
                    Text(AppSettings.localizedLanguageName(for: item.code, appLanguage: appLanguage)).tag(item.code)
                }
            }

            Button(localized("打开翻译高级设置…")) {
                openSettings()
            }

            Divider()

            Picker(localized("AI 提供方"), selection: $paperSummaryProvider) {
                ForEach(AppSettings.paperSummaryProviders, id: \.id) { item in
                    Text(localized(item.name))
                        .tag(item.id)
                        .disabled(item.id == PaperSummaryProviderID.appleOnDevice.rawValue && !appleModelAvailability.isHardwareSupported)
                }
            }

            Button(localized("打开 AI 高级设置…")) {
                openSettings()
            }
        }
    }

    private func postLibraryCommand(_ command: AppMenuLibraryCommand) {
        NotificationCenter.default.post(name: .appMenuLibraryCommand, object: command)
    }
}
#endif
