import Foundation
import CryptoKit

#if canImport(Translation)
import Translation
#endif

#if canImport(FoundationModels)
import FoundationModels
#endif

struct TextTranslationRequest {
    let text: String
    let sourceLanguage: String
    let targetLanguage: String
}

struct PaperChatConversationTurn: Codable, Equatable, Identifiable {
    let id: UUID
    let role: String
    let content: String

    init(id: UUID = UUID(), role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

struct PaperChatRequest {
    let title: String
    let content: String
    let selectedExcerpt: String?
    let history: [PaperChatConversationTurn]
    let question: String
}

enum TranslationModeID: String, CaseIterable {
    case system
    case ai
    case traditional

    var displayName: String {
        switch self {
        case .system:
            return "Apple 本地翻译"
        case .ai:
            return "AI 翻译"
        case .traditional:
            return "专业翻译 API"
        }
    }

    static func normalized(from rawValue: String) -> TranslationModeID {
        TranslationModeID(rawValue: rawValue) ?? .system
    }
}

enum TraditionalTranslationProviderID: String, CaseIterable {
    case deepL
    case baidu
    case youdao

    var displayName: String {
        switch self {
        case .deepL:
            return "DeepL API"
        case .baidu:
            return "百度翻译开放平台"
        case .youdao:
            return "有道智云翻译"
        }
    }

    static func normalized(from rawValue: String) -> TraditionalTranslationProviderID {
        TraditionalTranslationProviderID(rawValue: rawValue) ?? .deepL
    }
}

struct PaperSummaryRequest {
    let title: String
    let content: String
}

enum PaperSummaryProviderID: String, CaseIterable {
    case appleOnDevice
    case deepseek
    case openAI
    case gemini
    case qwen

    var displayName: String {
        switch self {
        case .appleOnDevice:
            return "Apple 本地模型"
        case .deepseek:
            return "DeepSeek API"
        case .openAI:
            return "GPT / OpenAI API"
        case .gemini:
            return "Gemini API"
        case .qwen:
            return "千问 / Qwen API"
        }
    }

    static func normalized(from rawValue: String) -> PaperSummaryProviderID {
        let normalizedValue = rawValue == "externalAPI" ? "deepseek" : rawValue
        return PaperSummaryProviderID(rawValue: normalizedValue) ?? .appleOnDevice
    }
}

struct AppleOnDeviceAvailabilityInfo {
    let isHardwareSupported: Bool
    let isAvailableNow: Bool
    let message: String?
}

struct SystemTranslationAvailabilityInfo {
    let isSupported: Bool
    let message: String?
}

enum TextTranslationError: LocalizedError {
    case emptyContent
    case providerUnavailable(String)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "未读取到可用于翻译的文本。"
        case .providerUnavailable(let message):
            return message
        case .generationFailed(let message):
            return "翻译失败：\(message)"
        }
    }
}

enum PaperSummaryError: LocalizedError {
    case emptyContent
    case providerUnavailable(String)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "未读取到可用于汇总的 PDF 文本。"
        case .providerUnavailable(let message):
            return message
        case .generationFailed(let message):
            return "AI 汇总失败：\(message)"
        }
    }
}

enum PaperChatError: LocalizedError {
    case emptyContent
    case emptyQuestion
    case providerUnavailable(String)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "未读取到可用于问答的 PDF 文本。"
        case .emptyQuestion:
            return "请输入你想问的问题。"
        case .providerUnavailable(let message):
            return message
        case .generationFailed(let message):
            return "AI 对话失败：\(message)"
        }
    }
}

struct TextTranslationService {
    static func systemTranslationAvailabilityInfo() -> SystemTranslationAvailabilityInfo {
        #if canImport(Translation)
        if #available(macOS 15.0, iOS 18.0, *) {
            return SystemTranslationAvailabilityInfo(
                isSupported: true,
                message: nil
            )
        }

        return SystemTranslationAvailabilityInfo(
            isSupported: false,
            message: "当前系统版本不支持系统内置翻译。"
        )
        #else
        return SystemTranslationAvailabilityInfo(
            isSupported: false,
            message: "当前构建环境未启用系统翻译框架。"
        )
        #endif
    }

    static func translate(
        request: TextTranslationRequest,
        modeID: String,
        traditionalProviderID: String,
        traditionalEndpoint: String,
        traditionalPrimaryCredential: String,
        traditionalSecondaryCredential: String,
        aiProviderID: String,
        aiEndpoint: String,
        aiAPIKey: String,
        aiModel: String
    ) async throws -> String {
        let trimmedText = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw TextTranslationError.emptyContent
        }

        let mode = TranslationModeID.normalized(from: modeID)

        switch mode {
        case .system:
            let info = systemTranslationAvailabilityInfo()
            throw TextTranslationError.providerUnavailable(info.message ?? "当前环境不支持系统翻译。")
        case .ai:
            let provider = PaperSummaryProviderID.normalized(from: aiProviderID)
            switch provider {
            case .appleOnDevice:
                return try await AppleOnDeviceAITranslationProvider().translate(request: request)
            case .deepseek, .openAI, .qwen:
                return try await OpenAICompatibleAITranslationProvider(
                    provider: provider,
                    endpoint: aiEndpoint,
                    apiKey: aiAPIKey,
                    model: aiModel
                ).translate(request: request)
            case .gemini:
                return try await GeminiAITranslationProvider(
                    endpoint: aiEndpoint,
                    apiKey: aiAPIKey,
                    model: aiModel
                ).translate(request: request)
            }
        case .traditional:
            let provider = TraditionalTranslationProviderID.normalized(from: traditionalProviderID)
            switch provider {
            case .deepL:
                return try await DeepLTranslationProvider(
                    endpoint: traditionalEndpoint,
                    apiKey: traditionalPrimaryCredential
                ).translate(request: request)
            case .baidu:
                return try await BaiduTranslationProvider(
                    endpoint: traditionalEndpoint,
                    appID: traditionalPrimaryCredential,
                    secret: traditionalSecondaryCredential
                ).translate(request: request)
            case .youdao:
                return try await YoudaoTranslationProvider(
                    endpoint: traditionalEndpoint,
                    appID: traditionalPrimaryCredential,
                    secret: traditionalSecondaryCredential
                ).translate(request: request)
            }
        }
    }

    static func translationPrompt(for request: TextTranslationRequest) -> String {
        let sourceLanguageName = AppSettings.languageName(for: request.sourceLanguage)
        let targetLanguageName = AppSettings.languageName(for: request.targetLanguage)

        return """
        请将下面的文本从\(sourceLanguageName)翻译为\(targetLanguageName)。
        要求：
        1. 只输出译文，不要添加说明、标题或引号。
        2. 保留原有段落、项目符号、编号、公式和引用标记。
        3. 论文术语优先采用自然、准确的学术表达。
        4. 人名、文献名、缩写在需要时保留原文。

        原文：
        \(request.text)
        """
    }
}

struct PaperSummaryService {
    static func appleOnDeviceAvailabilityInfo() -> AppleOnDeviceAvailabilityInfo {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return AppleOnDeviceAvailabilityInfo(
                    isHardwareSupported: true,
                    isAvailableNow: true,
                    message: nil
                )
            case .unavailable(.deviceNotEligible):
                return AppleOnDeviceAvailabilityInfo(
                    isHardwareSupported: false,
                    isAvailableNow: false,
                    message: "当前设备硬件不支持 Apple Intelligence。"
                )
            case .unavailable(let reason):
                return AppleOnDeviceAvailabilityInfo(
                    isHardwareSupported: true,
                    isAvailableNow: false,
                    message: "Apple 本地模型当前不可用：\(String(describing: reason))"
                )
            }
        }

        return AppleOnDeviceAvailabilityInfo(
            isHardwareSupported: false,
            isAvailableNow: false,
            message: "当前系统版本不支持 Apple 本地模型。"
        )
        #else
        return AppleOnDeviceAvailabilityInfo(
            isHardwareSupported: false,
            isAvailableNow: false,
            message: "当前构建环境不支持 FoundationModels。"
        )
        #endif
    }

    static func summarize(
        request: PaperSummaryRequest,
        providerID: String,
        externalEndpoint: String,
        externalAPIKey: String,
        externalModel: String
    ) async throws -> String {
        guard !request.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PaperSummaryError.emptyContent
        }

        let provider = PaperSummaryProviderID.normalized(from: providerID)

        switch provider {
        case .appleOnDevice:
            return try await AppleOnDeviceSummaryProvider().summarize(request: request)
        case .deepseek, .openAI, .qwen:
            return try await OpenAICompatibleSummaryProvider(
                provider: provider,
                endpoint: externalEndpoint,
                apiKey: externalAPIKey,
                model: externalModel
            ).summarize(request: request)
        case .gemini:
            return try await GeminiSummaryProvider(
                endpoint: externalEndpoint,
                apiKey: externalAPIKey,
                model: externalModel
            ).summarize(request: request)
        }
    }

    static func clippedSummarySource(_ content: String) -> String {
        String(content.prefix(14_000))
    }

    static func summaryPrompt(for request: PaperSummaryRequest) -> String {
        """
        请基于以下论文内容生成中文摘要，控制在 4 到 6 句，并包含：
        1. 研究问题
        2. 核心方法
        3. 主要结果
        4. 局限性或后续方向

        论文标题：\(request.title)

        论文内容：
        \(clippedSummarySource(request.content))
        """
    }
}

struct PaperChatService {
    static func ask(
        request: PaperChatRequest,
        providerID: String,
        externalEndpoint: String,
        externalAPIKey: String,
        externalModel: String
    ) async throws -> String {
        guard !request.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PaperChatError.emptyContent
        }

        let trimmedQuestion = request.question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            throw PaperChatError.emptyQuestion
        }

        let provider = PaperSummaryProviderID.normalized(from: providerID)

        switch provider {
        case .appleOnDevice:
            return try await AppleOnDevicePaperChatProvider().answer(request: request)
        case .deepseek, .openAI, .qwen:
            return try await OpenAICompatiblePaperChatProvider(
                provider: provider,
                endpoint: externalEndpoint,
                apiKey: externalAPIKey,
                model: externalModel
            ).answer(request: request)
        case .gemini:
            return try await GeminiPaperChatProvider(
                endpoint: externalEndpoint,
                apiKey: externalAPIKey,
                model: externalModel
            ).answer(request: request)
        }
    }

    static func clippedChatSource(_ content: String) -> String {
        String(content.prefix(20_000))
    }

    static func clippedSelectedExcerpt(_ content: String) -> String {
        String(content.prefix(4_000))
    }

    static func systemPrompt(for request: PaperChatRequest) -> String {
        let selectedExcerptBlock: String
        if let selectedExcerpt = request.selectedExcerpt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !selectedExcerpt.isEmpty {
            selectedExcerptBlock = """

            当前划词内容：
            \(clippedSelectedExcerpt(selectedExcerpt))

            本轮提问优先围绕这段划词回答；如有必要，可以结合整篇 PDF 内容补充上下文。
            """
        } else {
            selectedExcerptBlock = ""
        }

        return """
        你是一个基于当前 PDF 内容回答问题的阅读助手。请只依据给定的标题、内容摘录和历史对话来回答；如果材料不足，请明确说明“无法从当前 PDF 内容判断”。
        回答要求：
        1. 使用中文。
        2. 优先简洁、准确、结构化，必要时可分点说明。
        3. 引用文中的方法、结果、定义时，尽量贴近原意，不要编造。
        4. 如果用户的问题超出当前 PDF 内容范围，要直接说明。

        当前论文标题：\(request.title)
        \(selectedExcerptBlock)

        当前 PDF 内容摘录：
        \(clippedChatSource(request.content))
        """
    }

    fileprivate static func messages(for request: PaperChatRequest) -> [OpenAICompatibleMessage] {
        var messages: [OpenAICompatibleMessage] = [
            .init(role: "system", content: systemPrompt(for: request))
        ]

        messages.append(contentsOf: request.history.map {
            OpenAICompatibleMessage(role: $0.role, content: $0.content)
        })
        messages.append(.init(role: "user", content: request.question))
        return messages
    }

    static func applePrompt(for request: PaperChatRequest) -> String {
        let historyText = request.history.map { turn in
            let role = turn.role == "assistant" ? "助手" : "用户"
            return "\(role)：\(turn.content)"
        }
        .joined(separator: "\n\n")

        let historyBlock = historyText.isEmpty ? "无历史对话。" : historyText

        return """
        \(systemPrompt(for: request))

        历史对话：
        \(historyBlock)

        用户最新问题：
        \(request.question)
        """
    }
}

private struct OpenAICompatibleSummaryProvider {
    let provider: PaperSummaryProviderID
    let endpoint: String
    let apiKey: String
    let model: String

    func summarize(request: PaperSummaryRequest) async throws -> String {
        let preset = AppSettings.paperSummaryProviderPreset(for: provider.rawValue)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw PaperSummaryError.providerUnavailable("请先在设置中填写\(provider.displayName) API Key。")
        }

        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultEndpoint
            : endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultModel
            : model.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmedEndpoint) else {
            throw PaperSummaryError.providerUnavailable("\(provider.displayName) API 地址无效。")
        }

        let payload = OpenAICompatibleChatRequest(
            model: trimmedModel,
            messages: [
                .init(role: "system", content: "你是科研论文助手，输出中文、客观、简洁的摘要。"),
                .init(role: "user", content: PaperSummaryService.summaryPrompt(for: request))
            ],
            temperature: 0.3,
            maxTokens: 800
        )

        var requestObject = URLRequest(url: url)
        requestObject.httpMethod = "POST"
        requestObject.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requestObject.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        requestObject.httpBody = try JSONEncoder().encode(payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: requestObject)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PaperSummaryError.generationFailed("网络响应无效")
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw PaperSummaryError.generationFailed("\(provider.displayName) 请求失败（\(httpResponse.statusCode)）：\(body)")
            }

            let decoded = try JSONDecoder().decode(OpenAICompatibleChatResponse.self, from: data)
            let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !content.isEmpty else {
                throw PaperSummaryError.generationFailed("\(provider.displayName) 返回内容为空")
            }

            return content
        } catch let error as PaperSummaryError {
            throw error
        } catch {
            throw PaperSummaryError.generationFailed(error.localizedDescription)
        }
    }
}

private struct GeminiSummaryProvider {
    let endpoint: String
    let apiKey: String
    let model: String

    func summarize(request: PaperSummaryRequest) async throws -> String {
        let preset = AppSettings.paperSummaryProviderPreset(for: PaperSummaryProviderID.gemini.rawValue)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw PaperSummaryError.providerUnavailable("请先在设置中填写 Gemini API Key。")
        }

        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultEndpoint
            : endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultModel
            : model.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedEndpoint = trimmedEndpoint.replacingOccurrences(of: "{model}", with: trimmedModel)

        guard let url = URL(string: resolvedEndpoint) else {
            throw PaperSummaryError.providerUnavailable("Gemini API 地址无效。")
        }

        let payload = GeminiGenerateContentRequest(
            contents: [
                .init(parts: [
                    .init(text: """
                    你是科研论文助手，输出中文、客观、简洁的摘要。

                    \(PaperSummaryService.summaryPrompt(for: request))
                    """)
                ])
            ],
            generationConfig: .init(
                temperature: 0.3,
                maxOutputTokens: 800
            )
        )

        var requestObject = URLRequest(url: url)
        requestObject.httpMethod = "POST"
        requestObject.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requestObject.setValue(trimmedKey, forHTTPHeaderField: "x-goog-api-key")
        requestObject.httpBody = try JSONEncoder().encode(payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: requestObject)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PaperSummaryError.generationFailed("网络响应无效")
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw PaperSummaryError.generationFailed("Gemini 请求失败（\(httpResponse.statusCode)）：\(body)")
            }

            let decoded = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
            let texts = decoded.candidates
                .flatMap(\.content.parts)
                .compactMap(\.text)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !texts.isEmpty else {
                throw PaperSummaryError.generationFailed("Gemini 返回内容为空")
            }

            return texts.joined(separator: "\n")
        } catch let error as PaperSummaryError {
            throw error
        } catch {
            throw PaperSummaryError.generationFailed(error.localizedDescription)
        }
    }
}

private struct OpenAICompatibleAITranslationProvider {
    let provider: PaperSummaryProviderID
    let endpoint: String
    let apiKey: String
    let model: String

    func translate(request: TextTranslationRequest) async throws -> String {
        let preset = AppSettings.paperSummaryProviderPreset(for: provider.rawValue)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw TextTranslationError.providerUnavailable("请先在设置中填写\(provider.displayName) API Key。")
        }

        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultEndpoint
            : endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultModel
            : model.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmedEndpoint) else {
            throw TextTranslationError.providerUnavailable("\(provider.displayName) API 地址无效。")
        }

        let payload = OpenAICompatibleChatRequest(
            model: trimmedModel,
            messages: [
                .init(role: "system", content: "你是科研阅读助手，负责进行准确、自然的学术翻译，只返回译文本身。"),
                .init(role: "user", content: TextTranslationService.translationPrompt(for: request))
            ],
            temperature: 0.1,
            maxTokens: 1500
        )

        var requestObject = URLRequest(url: url)
        requestObject.httpMethod = "POST"
        requestObject.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requestObject.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        requestObject.httpBody = try JSONEncoder().encode(payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: requestObject)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TextTranslationError.generationFailed("网络响应无效")
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw TextTranslationError.generationFailed("\(provider.displayName) 请求失败（\(httpResponse.statusCode)）：\(body)")
            }

            let decoded = try JSONDecoder().decode(OpenAICompatibleChatResponse.self, from: data)
            let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !content.isEmpty else {
                throw TextTranslationError.generationFailed("\(provider.displayName) 返回内容为空")
            }

            return content
        } catch let error as TextTranslationError {
            throw error
        } catch {
            throw TextTranslationError.generationFailed(error.localizedDescription)
        }
    }
}

private struct GeminiAITranslationProvider {
    let endpoint: String
    let apiKey: String
    let model: String

    func translate(request: TextTranslationRequest) async throws -> String {
        let preset = AppSettings.paperSummaryProviderPreset(for: PaperSummaryProviderID.gemini.rawValue)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw TextTranslationError.providerUnavailable("请先在设置中填写 Gemini API Key。")
        }

        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultEndpoint
            : endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultModel
            : model.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedEndpoint = trimmedEndpoint.replacingOccurrences(of: "{model}", with: trimmedModel)

        guard let url = URL(string: resolvedEndpoint) else {
            throw TextTranslationError.providerUnavailable("Gemini API 地址无效。")
        }

        let payload = GeminiGenerateContentRequest(
            contents: [
                .init(parts: [
                    .init(text: """
                    你是科研阅读助手，负责进行准确、自然的学术翻译，只返回译文本身。

                    \(TextTranslationService.translationPrompt(for: request))
                    """)
                ])
            ],
            generationConfig: .init(
                temperature: 0.1,
                maxOutputTokens: 1500
            )
        )

        var requestObject = URLRequest(url: url)
        requestObject.httpMethod = "POST"
        requestObject.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requestObject.setValue(trimmedKey, forHTTPHeaderField: "x-goog-api-key")
        requestObject.httpBody = try JSONEncoder().encode(payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: requestObject)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TextTranslationError.generationFailed("网络响应无效")
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw TextTranslationError.generationFailed("Gemini 请求失败（\(httpResponse.statusCode)）：\(body)")
            }

            let decoded = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
            let texts = decoded.candidates
                .flatMap(\.content.parts)
                .compactMap(\.text)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !texts.isEmpty else {
                throw TextTranslationError.generationFailed("Gemini 返回内容为空")
            }

            return texts.joined(separator: "\n")
        } catch let error as TextTranslationError {
            throw error
        } catch {
            throw TextTranslationError.generationFailed(error.localizedDescription)
        }
    }
}

private struct DeepLTranslationProvider {
    let endpoint: String
    let apiKey: String

    func translate(request: TextTranslationRequest) async throws -> String {
        let preset = AppSettings.traditionalTranslationProviderPreset(for: TraditionalTranslationProviderID.deepL.rawValue)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw TextTranslationError.providerUnavailable("请先在设置中填写 DeepL API Key。")
        }

        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultEndpoint
            : endpoint.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmedEndpoint) else {
            throw TextTranslationError.providerUnavailable("DeepL API 地址无效。")
        }

        let payload = DeepLTranslateRequest(
            text: [request.text],
            sourceLang: deepLCode(for: request.sourceLanguage),
            targetLang: deepLCode(for: request.targetLanguage)
        )

        var requestObject = URLRequest(url: url)
        requestObject.httpMethod = "POST"
        requestObject.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requestObject.setValue("DeepL-Auth-Key \(trimmedKey)", forHTTPHeaderField: "Authorization")
        requestObject.httpBody = try JSONEncoder().encode(payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: requestObject)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TextTranslationError.generationFailed("网络响应无效")
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw TextTranslationError.generationFailed("DeepL 请求失败（\(httpResponse.statusCode)）：\(body)")
            }

            let decoded = try JSONDecoder().decode(DeepLTranslateResponse.self, from: data)
            let content = decoded.translations
                .map(\.text)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !content.isEmpty else {
                throw TextTranslationError.generationFailed("DeepL 返回内容为空")
            }

            return content
        } catch let error as TextTranslationError {
            throw error
        } catch {
            throw TextTranslationError.generationFailed(error.localizedDescription)
        }
    }
}

private struct BaiduTranslationProvider {
    let endpoint: String
    let appID: String
    let secret: String

    func translate(request: TextTranslationRequest) async throws -> String {
        let preset = AppSettings.traditionalTranslationProviderPreset(for: TraditionalTranslationProviderID.baidu.rawValue)
        let trimmedAppID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAppID.isEmpty else {
            throw TextTranslationError.providerUnavailable("请先在设置中填写百度翻译 App ID。")
        }
        guard !trimmedSecret.isEmpty else {
            throw TextTranslationError.providerUnavailable("请先在设置中填写百度翻译密钥。")
        }

        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultEndpoint
            : endpoint.trimmingCharacters(in: .whitespacesAndNewlines)

        guard var components = URLComponents(string: trimmedEndpoint) else {
            throw TextTranslationError.providerUnavailable("百度翻译 API 地址无效。")
        }

        let salt = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let sign = md5Hex("\(trimmedAppID)\(request.text)\(salt)\(trimmedSecret)")
        components.queryItems = [
            .init(name: "q", value: request.text),
            .init(name: "from", value: baiduCode(for: request.sourceLanguage)),
            .init(name: "to", value: baiduCode(for: request.targetLanguage)),
            .init(name: "appid", value: trimmedAppID),
            .init(name: "salt", value: salt),
            .init(name: "sign", value: sign)
        ]

        guard let url = components.url else {
            throw TextTranslationError.providerUnavailable("百度翻译 API 地址无效。")
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TextTranslationError.generationFailed("网络响应无效")
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw TextTranslationError.generationFailed("百度翻译请求失败（\(httpResponse.statusCode)）：\(body)")
            }

            let decoded = try JSONDecoder().decode(BaiduTranslationResponse.self, from: data)
            if let errorCode = decoded.errorCode, errorCode != "52000" {
                throw TextTranslationError.generationFailed(decoded.errorMsg ?? "百度翻译返回错误 \(errorCode)")
            }

            let content = decoded.transResult?
                .map(\.dst)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !content.isEmpty else {
                throw TextTranslationError.generationFailed("百度翻译返回内容为空")
            }

            return content
        } catch let error as TextTranslationError {
            throw error
        } catch {
            throw TextTranslationError.generationFailed(error.localizedDescription)
        }
    }
}

private struct YoudaoTranslationProvider {
    let endpoint: String
    let appID: String
    let secret: String

    func translate(request: TextTranslationRequest) async throws -> String {
        let preset = AppSettings.traditionalTranslationProviderPreset(for: TraditionalTranslationProviderID.youdao.rawValue)
        let trimmedAppID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAppID.isEmpty else {
            throw TextTranslationError.providerUnavailable("请先在设置中填写有道应用 ID。")
        }
        guard !trimmedSecret.isEmpty else {
            throw TextTranslationError.providerUnavailable("请先在设置中填写有道应用密钥。")
        }

        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultEndpoint
            : endpoint.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmedEndpoint) else {
            throw TextTranslationError.providerUnavailable("有道翻译 API 地址无效。")
        }

        let salt = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let curtime = String(Int(Date().timeIntervalSince1970))
        let sign = sha256Hex("\(trimmedAppID)\(youdaoInput(for: request.text))\(salt)\(curtime)\(trimmedSecret)")
        let body = formURLEncoded([
            "q": request.text,
            "from": youdaoCode(for: request.sourceLanguage),
            "to": youdaoCode(for: request.targetLanguage),
            "appKey": trimmedAppID,
            "salt": salt,
            "sign": sign,
            "signType": "v3",
            "curtime": curtime
        ])

        var requestObject = URLRequest(url: url)
        requestObject.httpMethod = "POST"
        requestObject.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        requestObject.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: requestObject)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TextTranslationError.generationFailed("网络响应无效")
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw TextTranslationError.generationFailed("有道翻译请求失败（\(httpResponse.statusCode)）：\(body)")
            }

            let decoded = try JSONDecoder().decode(YoudaoTranslationResponse.self, from: data)
            if decoded.errorCode != "0" {
                throw TextTranslationError.generationFailed(decoded.errorMessage ?? "有道翻译返回错误 \(decoded.errorCode)")
            }

            let content = decoded.translation
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !content.isEmpty else {
                throw TextTranslationError.generationFailed("有道翻译返回内容为空")
            }

            return content
        } catch let error as TextTranslationError {
            throw error
        } catch {
            throw TextTranslationError.generationFailed(error.localizedDescription)
        }
    }
}

private struct AppleOnDeviceAITranslationProvider {
    func translate(request: TextTranslationRequest) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            let info = PaperSummaryService.appleOnDeviceAvailabilityInfo()
            if !info.isAvailableNow {
                throw TextTranslationError.providerUnavailable(info.message ?? "Apple 本地模型不可用。")
            }

            let session = LanguageModelSession(
                instructions: "你是科研阅读助手，负责进行准确、自然的学术翻译，只返回译文本身。"
            )

            let prompt = TextTranslationService.translationPrompt(for: request)

            do {
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    throw TextTranslationError.generationFailed("模型返回为空")
                }
                return text
            } catch let error as TextTranslationError {
                throw error
            } catch {
                throw TextTranslationError.generationFailed(error.localizedDescription)
            }
        }

        throw TextTranslationError.providerUnavailable("当前系统版本不支持 Apple 本地模型。")
        #else
        throw TextTranslationError.providerUnavailable("当前构建环境不支持 FoundationModels。")
        #endif
    }
}

private struct OpenAICompatiblePaperChatProvider {
    let provider: PaperSummaryProviderID
    let endpoint: String
    let apiKey: String
    let model: String

    func answer(request: PaperChatRequest) async throws -> String {
        let preset = AppSettings.paperSummaryProviderPreset(for: provider.rawValue)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw PaperChatError.providerUnavailable("请先在设置中填写\(provider.displayName) API Key。")
        }

        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultEndpoint
            : endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultModel
            : model.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmedEndpoint) else {
            throw PaperChatError.providerUnavailable("\(provider.displayName) API 地址无效。")
        }

        let payload = OpenAICompatibleChatRequest(
            model: trimmedModel,
            messages: PaperChatService.messages(for: request),
            temperature: 0.2,
            maxTokens: 1200
        )

        var requestObject = URLRequest(url: url)
        requestObject.httpMethod = "POST"
        requestObject.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requestObject.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        requestObject.httpBody = try JSONEncoder().encode(payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: requestObject)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PaperChatError.generationFailed("网络响应无效")
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw PaperChatError.generationFailed("\(provider.displayName) 请求失败（\(httpResponse.statusCode)）：\(body)")
            }

            let decoded = try JSONDecoder().decode(OpenAICompatibleChatResponse.self, from: data)
            let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !content.isEmpty else {
                throw PaperChatError.generationFailed("\(provider.displayName) 返回内容为空")
            }

            return content
        } catch let error as PaperChatError {
            throw error
        } catch {
            throw PaperChatError.generationFailed(error.localizedDescription)
        }
    }
}

private struct GeminiPaperChatProvider {
    let endpoint: String
    let apiKey: String
    let model: String

    func answer(request: PaperChatRequest) async throws -> String {
        let preset = AppSettings.paperSummaryProviderPreset(for: PaperSummaryProviderID.gemini.rawValue)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw PaperChatError.providerUnavailable("请先在设置中填写 Gemini API Key。")
        }

        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultEndpoint
            : endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preset.defaultModel
            : model.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedEndpoint = trimmedEndpoint.replacingOccurrences(of: "{model}", with: trimmedModel)

        guard let url = URL(string: resolvedEndpoint) else {
            throw PaperChatError.providerUnavailable("Gemini API 地址无效。")
        }

        let historyText = request.history.map { turn in
            let role = turn.role == "assistant" ? "助手" : "用户"
            return "\(role)：\(turn.content)"
        }
        .joined(separator: "\n\n")

        let payload = GeminiGenerateContentRequest(
            contents: [
                .init(parts: [
                    .init(text: """
                    \(PaperChatService.systemPrompt(for: request))

                    历史对话：
                    \(historyText.isEmpty ? "无历史对话。" : historyText)

                    用户最新问题：
                    \(request.question)
                    """)
                ])
            ],
            generationConfig: .init(
                temperature: 0.2,
                maxOutputTokens: 1200
            )
        )

        var requestObject = URLRequest(url: url)
        requestObject.httpMethod = "POST"
        requestObject.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requestObject.setValue(trimmedKey, forHTTPHeaderField: "x-goog-api-key")
        requestObject.httpBody = try JSONEncoder().encode(payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: requestObject)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PaperChatError.generationFailed("网络响应无效")
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw PaperChatError.generationFailed("Gemini 请求失败（\(httpResponse.statusCode)）：\(body)")
            }

            let decoded = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
            let texts = decoded.candidates
                .flatMap(\.content.parts)
                .compactMap(\.text)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !texts.isEmpty else {
                throw PaperChatError.generationFailed("Gemini 返回内容为空")
            }

            return texts.joined(separator: "\n")
        } catch let error as PaperChatError {
            throw error
        } catch {
            throw PaperChatError.generationFailed(error.localizedDescription)
        }
    }
}

private struct AppleOnDevicePaperChatProvider {
    func answer(request: PaperChatRequest) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            let info = PaperSummaryService.appleOnDeviceAvailabilityInfo()
            if !info.isAvailableNow {
                throw PaperChatError.providerUnavailable(info.message ?? "Apple 本地模型不可用。")
            }

            let session = LanguageModelSession(
                instructions: "你是论文阅读助手，请只基于当前 PDF 内容回答问题，使用中文、准确、克制的表达。"
            )

            do {
                let response = try await session.respond(to: PaperChatService.applePrompt(for: request))
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    throw PaperChatError.generationFailed("模型返回为空")
                }
                return text
            } catch let error as PaperChatError {
                throw error
            } catch {
                throw PaperChatError.generationFailed(error.localizedDescription)
            }
        }

        throw PaperChatError.providerUnavailable("当前系统版本不支持 Apple 本地模型。")
        #else
        throw PaperChatError.providerUnavailable("当前构建环境不支持 FoundationModels。")
        #endif
    }
}

private struct AppleOnDeviceSummaryProvider {
    func summarize(request: PaperSummaryRequest) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            let info = PaperSummaryService.appleOnDeviceAvailabilityInfo()
            if !info.isAvailableNow {
                throw PaperSummaryError.providerUnavailable(info.message ?? "Apple 本地模型不可用。")
            }

            let session = LanguageModelSession(
                instructions: "你是科研论文助手。请输出中文、客观、结构化、简洁的摘要。"
            )

            let prompt = """
            请基于以下论文内容生成摘要，使用中文，控制在 4 到 6 句：
            1. 研究问题
            2. 方法
            3. 主要结果
            4. 局限性或可延展方向

            论文标题：\(request.title)

            论文内容：
            \(PaperSummaryService.clippedSummarySource(request.content))
            """

            do {
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    throw PaperSummaryError.generationFailed("模型返回为空")
                }
                return text
            } catch let error as PaperSummaryError {
                throw error
            } catch {
                throw PaperSummaryError.generationFailed(error.localizedDescription)
            }
        }

        throw PaperSummaryError.providerUnavailable("当前系统版本不支持 Apple 本地模型。")
        #else
        throw PaperSummaryError.providerUnavailable("当前构建环境不支持 FoundationModels。")
        #endif
    }
}

private struct OpenAICompatibleChatRequest: Encodable {
    let model: String
    let messages: [OpenAICompatibleMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct OpenAICompatibleMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAICompatibleChatResponse: Decodable {
    let choices: [OpenAICompatibleChoice]
}

private struct OpenAICompatibleChoice: Decodable {
    let message: OpenAICompatibleMessage
}

private struct GeminiGenerateContentRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig

    enum CodingKeys: String, CodingKey {
        case contents
        case generationConfig = "generationConfig"
    }
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String?

    init(text: String) {
        self.text = text
    }
}

private struct GeminiGenerationConfig: Encodable {
    let temperature: Double
    let maxOutputTokens: Int

    enum CodingKeys: String, CodingKey {
        case temperature
        case maxOutputTokens = "maxOutputTokens"
    }
}

private struct GeminiGenerateContentResponse: Decodable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent
}

private struct DeepLTranslateRequest: Encodable {
    let text: [String]
    let sourceLang: String
    let targetLang: String

    enum CodingKeys: String, CodingKey {
        case text
        case sourceLang = "source_lang"
        case targetLang = "target_lang"
    }
}

private struct DeepLTranslateResponse: Decodable {
    let translations: [DeepLTranslationItem]
}

private struct DeepLTranslationItem: Decodable {
    let text: String
}

private struct BaiduTranslationResponse: Decodable {
    let errorCode: String?
    let errorMsg: String?
    let transResult: [BaiduTranslationItem]?

    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case errorMsg = "error_msg"
        case transResult = "trans_result"
    }
}

private struct BaiduTranslationItem: Decodable {
    let src: String
    let dst: String
}

private struct YoudaoTranslationResponse: Decodable {
    let errorCode: String
    let errorMessage: String?
    let translation: [String]

    enum CodingKeys: String, CodingKey {
        case errorCode
        case errorMessage = "msg"
        case translation
    }
}

private func deepLCode(for code: String) -> String {
    switch code {
    case "zh-Hans", "zh-Hant":
        return "ZH"
    case "en":
        return "EN"
    case "ja":
        return "JA"
    case "ko":
        return "KO"
    case "fr":
        return "FR"
    case "de":
        return "DE"
    case "es":
        return "ES"
    case "it":
        return "IT"
    case "pt":
        return "PT-BR"
    case "ru":
        return "RU"
    default:
        return code.uppercased()
    }
}

private func baiduCode(for code: String) -> String {
    switch code {
    case "zh-Hans":
        return "zh"
    case "zh-Hant":
        return "cht"
    default:
        return code
    }
}

private func youdaoCode(for code: String) -> String {
    switch code {
    case "zh-Hans":
        return "zh-CHS"
    case "zh-Hant":
        return "zh-CHT"
    case "en":
        return "en"
    case "ja":
        return "ja"
    case "ko":
        return "ko"
    case "fr":
        return "fr"
    case "de":
        return "de"
    case "es":
        return "es"
    case "it":
        return "it"
    case "pt":
        return "pt"
    case "ru":
        return "ru"
    default:
        return code
    }
}

private func youdaoInput(for text: String) -> String {
    if text.count <= 20 {
        return text
    }

    let prefix = String(text.prefix(10))
    let suffix = String(text.suffix(10))
    return "\(prefix)\(text.count)\(suffix)"
}

private func md5Hex(_ value: String) -> String {
    let digest = Insecure.MD5.hash(data: Data(value.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}

private func sha256Hex(_ value: String) -> String {
    let digest = SHA256.hash(data: Data(value.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}

private func formURLEncoded(_ fields: [String: String]) -> String {
    fields.map { key, value in
        "\(urlEncoded(key))=\(urlEncoded(value))"
    }
    .sorted()
    .joined(separator: "&")
}

private func urlEncoded(_ value: String) -> String {
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
}
