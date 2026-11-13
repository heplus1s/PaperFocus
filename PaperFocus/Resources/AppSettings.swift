//
//  AppSettings.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import Foundation

struct TranslationModePreset {
    let id: String
    let name: String
    let helperText: String
}

struct TraditionalTranslationProviderPreset {
    let id: String
    let name: String
    let defaultEndpoint: String
    let endpointLabel: String
    let primaryCredentialLabel: String
    let secondaryCredentialLabel: String
    let helperText: String
}

struct PaperSummaryProviderPreset {
    let id: String
    let name: String
    let defaultEndpoint: String
    let defaultModel: String
    let endpointLabel: String
    let keyLabel: String
    let helperText: String
}

enum AppSettings {
    static let appLanguageKey = "app.language"
    static let focusMinutesKey = "focusMinutes"
    static let breakMinutesKey = "breakMinutes"
    static let defaultReadingModeKey = "defaultReadingMode"
    static let defaultReadingGoalKey = "defaultReadingGoal"
    static let allowManualPaperTitleInputKey = "focus.allowManualPaperTitleInput"

    static let autoStartOnOpenPDFKey = "focus.autoStartOnOpenPDF"
    static let openPaperInFreeTimingKey = "focus.openPaperInFreeTiming"
    static let useDefaultFocusPresetKey = "focus.useDefaultFocusPreset"
    static let minimumEffectiveMinutesKey = "focus.minimumEffectiveMinutes"
    static let currentFocusMinutesKey = "focus.current.minutes"
    static let currentFocusModeKey = "focus.current.mode"
    static let currentFocusGoalKey = "focus.current.goal"
    static let currentFocusCustomGoalTextKey = "focus.current.customGoalText"

    static let showPaperInspectorHeaderKey = "ui.showPaperInspectorHeader"
    static let showRecentFocusSummaryKey = "ui.showRecentFocusSummary"

    static let pdfToolbarDisplayModeKey = "pdf.toolbarDisplayMode"
    static let pdfDefaultAnnotationColorKey = "pdf.defaultAnnotationColor"

    static let translationAutoTranslateEnabledKey = "translation.autoTranslateEnabled"
    static let translationSourceLanguageKey = "translation.sourceLanguage"
    static let translationTargetLanguageKey = "translation.targetLanguage"
    static let translationModeKey = "translation.mode"
    static let translationTraditionalProviderKey = "translation.traditional.provider"
    static let translationTraditionalEndpointKey = "translation.traditional.endpoint"
    static let translationTraditionalPrimaryCredentialKey = "translation.traditional.primaryCredential"
    static let translationTraditionalSecondaryCredentialKey = "translation.traditional.secondaryCredential"

    static let paperSummaryProviderKey = "ai.paperSummary.provider"
    static let paperSummaryExternalEndpointKey = "ai.paperSummary.external.endpoint"
    static let paperSummaryExternalAPIKey = "ai.paperSummary.external.apiKey"
    static let paperSummaryExternalModelKey = "ai.paperSummary.external.model"
    static let macReadingAIDialogEnabledKey = "mac.reading.aiDialogEnabled"
    static let macShowMainInterfaceSettingsKey = "mac.ui.showMainInterfaceSettings"
    static let macAllowMainFocusSidebarCollapseKey = "mac.ui.allowMainFocusSidebarCollapse"
    static let zoteroLinkedDisplayPathKey = "library.link.zotero.displayPath"
    static let zoteroLinkedDisplayNameKey = "library.link.zotero.displayName"
    static let endNoteLinkedDisplayPathKey = "library.link.endnote.displayPath"
    static let endNoteLinkedDisplayNameKey = "library.link.endnote.displayName"
    static let libraryAutoSyncOnLaunchKey = "library.autoSyncOnLaunch"
    static let libraryAutoRefreshIntervalMinutesKey = "library.autoRefreshIntervalMinutes"

    static let defaultFocusMinutes = 25
    static let defaultBreakMinutes = 5
    static let defaultReadingMode = "方法精读"
    static let defaultReadingGoal = "方法与公式"
    static let defaultAllowManualPaperTitleInput = false

    static let defaultAutoStartOnOpenPDF = true
    static let defaultOpenPaperInFreeTiming = false
    static let defaultUseDefaultFocusPreset = true
    static let defaultMinimumEffectiveMinutes = 10
    static let defaultCurrentFocusMode = FocusMode.deepReading.rawValue
    static let defaultCurrentFocusGoal = ReadingGoalPreset.finishIntroduction.rawValue
    static let defaultCurrentFocusCustomGoalText = ""

    static let defaultShowPaperInspectorHeader = false
    static let defaultShowRecentFocusSummary = true

    static let defaultPDFToolbarDisplayMode = "iconAndText"
    static let defaultPDFAnnotationColor = "yellow"

    static let defaultTranslationAutoTranslateEnabled = true
    static let defaultTranslationSourceLanguage = "en"
    static let defaultTranslationTargetLanguage = "zh-Hans"
    static let defaultTranslationMode = "system"
    static let defaultTranslationTraditionalProvider = "deepL"
    static let defaultTranslationTraditionalEndpoint = "https://api-free.deepl.com/v2/translate"
    static let defaultTranslationTraditionalPrimaryCredential = ""
    static let defaultTranslationTraditionalSecondaryCredential = ""
    static let defaultPaperSummaryProvider = "appleOnDevice"
    static let defaultPaperSummaryExternalEndpoint = "https://api.deepseek.com/v1/chat/completions"
    static let defaultPaperSummaryExternalAPIKey = ""
    static let defaultPaperSummaryExternalModel = "deepseek-chat"
    static let defaultMacReadingAIDialogEnabled = true
    static let defaultMacShowMainInterfaceSettings = false
    static let defaultMacAllowMainFocusSidebarCollapse = false
    static let defaultLinkedLibraryDisplayPath = ""
    static let defaultLinkedLibraryDisplayName = ""
    static let defaultLibraryAutoSyncOnLaunch = true
    static let defaultLibraryAutoRefreshIntervalMinutes = 0
    static let defaultAppLanguage = "system"

    static let readingModes = [
        "摘要速读",
        "方法精读",
        "实验精读",
        "做摘录"
    ]

    static let readingGoals = [
        "通读全文",
        "只读摘要",
        "方法与公式",
        "实验结果",
        "写阅读总结",
        "自定义"
    ]

    static let libraryAutoRefreshOptions: [(minutes: Int, name: String)] = [
        (0, "关闭自动刷新"),
        (5, "每 5 分钟"),
        (15, "每 15 分钟"),
        (30, "每 30 分钟"),
        (60, "每 60 分钟")
    ]

    static let translationLanguages: [(code: String, name: String)] = [
        ("en", "英文"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁体中文"),
        ("ja", "日语"),
        ("ko", "韩语"),
        ("fr", "法语"),
        ("de", "德语"),
        ("es", "西班牙语"),
        ("it", "意大利语"),
        ("pt", "葡萄牙语"),
        ("ru", "俄语")
    ]

    static var interfaceLanguageOptions: [(code: String, name: String)] {
        [(defaultAppLanguage, localizedString("跟随系统", defaultValue: "跟随系统", appLanguage: currentAppLanguage))]
            + translationLanguages.map { item in
                (item.code, localizedLanguageName(for: item.code, appLanguage: currentAppLanguage))
            }
    }

    static let translationModes: [TranslationModePreset] = [
        TranslationModePreset(
            id: "system",
            name: "Apple 本地翻译",
            helperText: "使用系统内置翻译能力，通常延迟更低，但依赖系统版本与本地语言包。"
        ),
        TranslationModePreset(
            id: "ai",
            name: "AI 翻译",
            helperText: "复用 AI 设置中的提供方、接口地址、模型与密钥配置。"
        ),
        TranslationModePreset(
            id: "traditional",
            name: "专业翻译 API",
            helperText: "使用专业翻译引擎接口，更适合术语翻译和大批量稳定调用。"
        )
    ]

    static let traditionalTranslationProviders: [TraditionalTranslationProviderPreset] = [
        TraditionalTranslationProviderPreset(
            id: "deepL",
            name: "DeepL API",
            defaultEndpoint: "https://api-free.deepl.com/v2/translate",
            endpointLabel: "DeepL API 地址",
            primaryCredentialLabel: "DeepL API Key",
            secondaryCredentialLabel: "",
            helperText: "默认使用 DeepL Free 地址；如使用 Pro 可改成 `https://api.deepl.com/v2/translate`。"
        ),
        TraditionalTranslationProviderPreset(
            id: "baidu",
            name: "百度翻译开放平台",
            defaultEndpoint: "https://fanyi-api.baidu.com/api/trans/vip/translate",
            endpointLabel: "百度翻译 API 地址",
            primaryCredentialLabel: "App ID",
            secondaryCredentialLabel: "密钥",
            helperText: "使用百度翻译开放平台的签名接口。"
        ),
        TraditionalTranslationProviderPreset(
            id: "youdao",
            name: "有道智云翻译",
            defaultEndpoint: "https://openapi.youdao.com/api",
            endpointLabel: "有道翻译 API 地址",
            primaryCredentialLabel: "应用 ID",
            secondaryCredentialLabel: "应用密钥",
            helperText: "使用有道智云文本翻译接口。"
        )
    ]

    static let paperSummaryProviders: [PaperSummaryProviderPreset] = [
        PaperSummaryProviderPreset(
            id: "appleOnDevice",
            name: "Apple 本地模型",
            defaultEndpoint: "",
            defaultModel: "",
            endpointLabel: "",
            keyLabel: "",
            helperText: "使用 Apple Intelligence 本地模型处理 AI 能力。"
        ),
        PaperSummaryProviderPreset(
            id: "deepseek",
            name: "DeepSeek API",
            defaultEndpoint: "https://api.deepseek.com/v1/chat/completions",
            defaultModel: "deepseek-chat",
            endpointLabel: "DeepSeek API 地址",
            keyLabel: "DeepSeek API Key",
            helperText: "兼容 OpenAI Chat Completions 协议，默认使用 DeepSeek 官方接口。"
        ),
        PaperSummaryProviderPreset(
            id: "openAI",
            name: "GPT / OpenAI API",
            defaultEndpoint: "https://api.openai.com/v1/chat/completions",
            defaultModel: "gpt-4.1-mini",
            endpointLabel: "OpenAI API 地址",
            keyLabel: "OpenAI API Key",
            helperText: "默认使用 OpenAI Chat Completions 接口，可切换为其他兼容 OpenAI 的服务地址。"
        ),
        PaperSummaryProviderPreset(
            id: "gemini",
            name: "Gemini API",
            defaultEndpoint: "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
            defaultModel: "gemini-2.5-flash",
            endpointLabel: "Gemini API 地址模板",
            keyLabel: "Gemini API Key",
            helperText: "默认使用 Gemini generateContent 接口，地址中的 {model} 会自动替换为下方模型名。"
        ),
        PaperSummaryProviderPreset(
            id: "qwen",
            name: "千问 / Qwen API",
            defaultEndpoint: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
            defaultModel: "qwen-plus",
            endpointLabel: "千问 API 地址",
            keyLabel: "千问 API Key",
            helperText: "默认使用阿里云百炼的 OpenAI 兼容 Chat Completions 接口。"
        )
    ]

    static func languageName(for code: String) -> String {
        localizedLanguageName(for: code)
    }

    static func translationModePreset(for id: String) -> TranslationModePreset {
        translationModes.first(where: { $0.id == id })
            ?? translationModes.first(where: { $0.id == defaultTranslationMode })!
    }

    static func traditionalTranslationProviderPreset(for id: String) -> TraditionalTranslationProviderPreset {
        traditionalTranslationProviders.first(where: { $0.id == id })
            ?? traditionalTranslationProviders.first(where: { $0.id == defaultTranslationTraditionalProvider })!
    }

    static func paperSummaryProviderPreset(for id: String) -> PaperSummaryProviderPreset {
        let normalizedID = id == "externalAPI" ? "deepseek" : id
        return paperSummaryProviders.first(where: { $0.id == normalizedID })
            ?? paperSummaryProviders.first(where: { $0.id == defaultPaperSummaryProvider })!
    }

    static func libraryAutoRefreshName(for minutes: Int) -> String {
        libraryAutoRefreshOptions.first(where: { $0.minutes == minutes }).map {
            localizedString($0.name)
        } ?? localizedMinutes(minutes)
    }

    static func interfaceLocale(for appLanguage: String) -> Locale {
        guard let code = resolvedAppLanguageCode(for: appLanguage) else {
            return .autoupdatingCurrent
        }
        return Locale(identifier: code)
    }

    static func localizedString(_ key: String, defaultValue: String? = nil, appLanguage: String? = nil) -> String {
        let fallback = defaultValue ?? key
        let code = resolvedBundleLanguageCode(for: appLanguage)
        let simplifiedChinese = localizedValue(forKey: key, languageCode: "zh-Hans")
        let english = localizedValue(forKey: key, languageCode: "en")

        if let localized = localizedValue(forKey: key, languageCode: code) {
            if code != "en",
               let english,
               localized == english,
               let simplifiedChinese,
               simplifiedChinese != english {
                return simplifiedChinese
            }

            return localized
        }

        if let simplifiedChinese {
            return simplifiedChinese
        }

        if let english {
            return english
        }

        return fallback
    }

    static func localizedFormat(
        _ key: String,
        defaultValue: String? = nil,
        appLanguage: String? = nil,
        _ arguments: CVarArg...
    ) -> String {
        let format = localizedString(key, defaultValue: defaultValue, appLanguage: appLanguage)
        let locale = interfaceLocale(for: appLanguage ?? currentAppLanguage)
        return String(format: format, locale: locale, arguments: arguments)
    }

    static func localizedBool(_ value: Bool, appLanguage: String? = nil) -> String {
        localizedString(value ? "是" : "否", appLanguage: appLanguage)
    }

    static func localizedMinutes(_ minutes: Int, appLanguage: String? = nil) -> String {
        localizedFormat("%d 分钟", defaultValue: "%d 分钟", appLanguage: appLanguage, minutes)
    }

    static func localizedLanguageName(for code: String, appLanguage: String? = nil) -> String {
        let displayLocale = interfaceLocale(for: appLanguage ?? currentAppLanguage)

        if let localized = displayLocale.localizedString(forIdentifier: code) {
            return localized
        }

        if let localized = displayLocale.localizedString(forLanguageCode: code) {
            return localized
        }

        return translationLanguages.first(where: { $0.code == code })?.name ?? code
    }

    private static var currentAppLanguage: String {
        UserDefaults.standard.string(forKey: appLanguageKey) ?? defaultAppLanguage
    }

    private static func resolvedAppLanguageCode(for appLanguage: String) -> String? {
        let trimmed = appLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != defaultAppLanguage else { return nil }
        return translationLanguages.contains(where: { $0.code == trimmed }) ? trimmed : nil
    }

    private static func resolvedBundleLanguageCode(for appLanguage: String?) -> String {
        let selectedLanguage = appLanguage ?? currentAppLanguage

        if let code = resolvedAppLanguageCode(for: selectedLanguage) {
            return code
        }

        for preferred in Locale.preferredLanguages {
            if let matched = matchingBundleLanguageCode(for: preferred) {
                return matched
            }
        }

        return "zh-Hans"
    }

    private static func matchingBundleLanguageCode(for identifier: String) -> String? {
        let supportedCodes = translationLanguages.map(\.code) + ["zh-Hans", "en"]

        if supportedCodes.contains(identifier) {
            return identifier
        }

        if identifier.hasPrefix("zh-Hant") {
            return "zh-Hant"
        }

        if identifier.hasPrefix("zh-Hans") || identifier.hasPrefix("zh") {
            return "zh-Hans"
        }

        if let languageCode = Locale(identifier: identifier).language.languageCode?.identifier,
           supportedCodes.contains(languageCode) {
            return languageCode
        }

        return nil
    }

    private static func localizedValue(forKey key: String, languageCode: String) -> String? {
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return nil
        }

        let marker = "__paperfocus_missing__\(key)__"
        let localized = bundle.localizedString(forKey: key, value: marker, table: nil)
        return localized == marker ? nil : localized
    }
}
