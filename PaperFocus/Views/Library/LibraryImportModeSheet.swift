//
//  LibraryImportModeSheet.swift
//  PaperFocus
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum LibraryImportMode: String, CaseIterable, Identifiable {
    case zotero
    case endNote
    case paperFocus
    case pdfFiles
    case pdfFolder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .zotero:
            return "Zotero 文献库"
        case .endNote:
            return "EndNote XML"
        case .paperFocus:
            return "PaperFocus 文献库"
        case .pdfFiles:
            return "PDF 文件"
        case .pdfFolder:
            return "PDF 文件夹"
        }
    }
}

struct LibraryImportModeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let initialMode: LibraryImportMode
    var stagedURL: URL?
    var importPDFs: ([URL]) async throws -> Void
    var onFinished: (String) -> Void

    @AppStorage(AppSettings.zoteroLinkedDisplayPathKey)
    private var zoteroLinkedDisplayPath = AppSettings.defaultLinkedLibraryDisplayPath
    @AppStorage(AppSettings.zoteroLinkedDisplayNameKey)
    private var zoteroLinkedDisplayName = AppSettings.defaultLinkedLibraryDisplayName
    @AppStorage(AppSettings.endNoteLinkedDisplayPathKey)
    private var endNoteLinkedDisplayPath = AppSettings.defaultLinkedLibraryDisplayPath
    @AppStorage(AppSettings.endNoteLinkedDisplayNameKey)
    private var endNoteLinkedDisplayName = AppSettings.defaultLinkedLibraryDisplayName
    @AppStorage(AppSettings.zoteroSoleLibraryKey)
    private var zoteroSoleLibrary = AppSettings.defaultZoteroSoleLibrary
    @AppStorage(AppSettings.importCopiesAttachmentsKey)
    private var importCopiesAttachments = AppSettings.defaultImportCopiesAttachments
    @AppStorage(AppSettings.zoteroAccountAPIKey)
    private var zoteroAccountAPIKey = ""

    @State private var mode: LibraryImportMode
    @State private var candidates: [ZoteroLibraryCandidate] = []
    @State private var selectedRootPath = ""
    @State private var customURL: URL?
    @State private var useAsSoleLibrary: Bool
    @State private var isWorking = false
    @State private var statusMessage = ""
    @State private var showImporter = false
    @State private var importerAllowsMultiple = false
    @State private var importerCommitImmediately = true
    @State private var importerTypes: [UTType] = [.pdf]

    private let libraryImportService = LibraryImportService()

    init(
        initialMode: LibraryImportMode,
        stagedURL: URL? = nil,
        importPDFs: @escaping ([URL]) async throws -> Void,
        onFinished: @escaping (String) -> Void
    ) {
        self.initialMode = initialMode
        self.stagedURL = stagedURL
        self.importPDFs = importPDFs
        self.onFinished = onFinished
        _mode = State(initialValue: initialMode)
        _useAsSoleLibrary = State(initialValue: AppSettings.zoteroSoleLibrary)
        if let stagedURL {
            _customURL = State(initialValue: stagedURL)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("导入方式") {
                    Picker("导入方式", selection: $mode) {
                        ForEach(LibraryImportMode.allCases) { item in
                            Text(LocalizedStringKey(item.title)).tag(item)
                        }
                    }
                    #if os(macOS)
                    .pickerStyle(.inline)
                    #else
                    .pickerStyle(.menu)
                    #endif
                    .labelsHidden()
                }

                if mode == .zotero {
                    zoteroSection
                } else {
                    otherModeSection
                }
            }
            .formStyle(.grouped)
            .navigationTitle("导入文献")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(isWorking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(primaryButtonTitle) {
                        performPrimaryAction()
                    }
                    .disabled(isWorking)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 520)
        #endif
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: importerTypes,
            allowsMultipleSelection: importerAllowsMultiple
        ) { result in
            handleImporterResult(result)
        }
        .onAppear(perform: loadCandidates)
        .overlay {
            if isWorking {
                ProgressView("正在导入…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var zoteroSection: some View {
        Section {
            Text(zoteroDiscoveryText)
                .font(.callout)
                .foregroundStyle(.secondary)

            if candidates.isEmpty && customURL == nil {
                Text(noLocalZoteroText)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(candidates) { candidate in
                    Button {
                        selectedRootPath = candidate.rootPath
                        customURL = nil
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: selectedRootPath == candidate.rootPath && customURL == nil ? "largecircle.fill.circle" : "circle")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey(candidate.sourceDescription))
                                Text(candidate.rootPath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if let customURL {
                LabeledContent("所选位置") {
                    Text(customURL.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Button("选择其他位置…") {
                presentImporter(for: .zotero, commitImmediately: false)
            }
            .frame(minHeight: 44)
            .disabled(isWorking)

            Toggle("将 Zotero 设为唯一关联文献库，并停用应用内文献库", isOn: $useAsSoleLibrary)
            Text("开启后，文献列表只显示 Zotero 文献，并暂停使用应用内文献库。已保存的应用内条目不会被删除。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(copyPolicyText)
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField("Zotero API 密钥", text: $zoteroAccountAPIKey)
            Text("在 Zotero 网站创建 API 密钥后填入。密钥仅保存在本机。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("关联 Zotero 账户") {
                linkAccount()
            }
            .frame(minHeight: 44)
            .disabled(isWorking || zoteroAccountAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Zotero 文献库")
        }
    }

    private var otherModeSection: some View {
        Section {
            Text(otherModeText)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(copyPolicyText)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let customURL, mode != .pdfFiles {
                LabeledContent("所选位置") {
                    Text(customURL.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        } header: {
            Text(LocalizedStringKey(mode.title))
        }
    }

    private var primaryButtonTitle: String {
        switch mode {
        case .zotero:
            return resolvedZoteroURL == nil ? "选择 Zotero 文献库" : "关联所选文献库"
        case .endNote:
            return "选择 EndNote XML"
        case .paperFocus:
            return "选择 PaperFocus 文献库"
        case .pdfFiles:
            return "选择 PDF 文件"
        case .pdfFolder:
            return "选择 PDF 文件夹"
        }
    }

    private var zoteroDiscoveryText: String {
        if candidates.count > 1 {
            return AppSettings.localizedString("找到多个 Zotero 文献库。请选择其一，或指定其他位置。")
        }
        if candidates.count == 1 {
            return AppSettings.localizedString("已在本机找到 Zotero 文献库。请确认要关联的位置。")
        }
        #if os(iOS)
        return AppSettings.localizedString("在 iPhone 和 iPad 上，请使用系统文件选择器选择 Zotero 数据目录，或填写 API 密钥。不会自动搜索 Mac 上的默认数据目录。")
        #else
        return AppSettings.localizedString("将在默认数据目录和 Zotero 配置目录中查找文献库。")
        #endif
    }

    private var noLocalZoteroText: String {
        #if os(iOS)
        AppSettings.localizedString("未在此设备上找到可直接读取的 Zotero 文献库。请选择数据目录或 zotero.sqlite，或填写 API 密钥。")
        #else
        AppSettings.localizedString("未在默认位置找到 Zotero 文献库。请选择数据目录或 zotero.sqlite。")
        #endif
    }

    private var otherModeText: String {
        switch mode {
        case .endNote:
            return AppSettings.localizedString("请选择 EndNote 导出的 XML 文件。其他 XML 或 EndNote 程序库文件不会被导入。")
        case .paperFocus:
            return AppSettings.localizedString("请选择 PaperFocus 文献库数据库或 paperfocus.library 文件。格式不符时不会替换当前文献库。")
        case .pdfFiles:
            return AppSettings.localizedString("可以选择一个或多个 PDF 文件。")
        case .pdfFolder:
            return AppSettings.localizedString("请选择包含 PDF 的文件夹。")
        case .zotero:
            return ""
        }
    }

    private var copyPolicyText: String {
        #if os(iOS)
        AppSettings.localizedString("在 iPhone 和 iPad 上，将直接打开“文件”中的原始文件，不会复制到应用内。")
        #else
        importCopiesAttachments
            ? AppSettings.localizedString("当前设置为在导入时复制附件。")
            : AppSettings.localizedString("当前设置为直接使用原始文件，不会生成副本。可在设置中更改。")
        #endif
    }

    private var resolvedZoteroURL: URL? {
        if let customURL { return customURL }
        return candidates.first { $0.rootPath == selectedRootPath }?.rootURL
    }

    private func loadCandidates() {
        Task {
            let found = await Task.detached(priority: .userInitiated) {
                ZoteroLibraryLocator.candidates()
            }.value
            candidates = found
            if selectedRootPath.isEmpty, found.count == 1 {
                selectedRootPath = found[0].rootPath
            }
            if let stagedURL {
                let kind = await Task.detached(priority: .userInitiated) {
                    LiteratureLibraryKind.detect(at: stagedURL)
                }.value
                switch kind {
                case .zoteroDataDirectory, .zoteroJSON:
                    mode = .zotero
                    customURL = stagedURL
                case .endNoteXML, .endNotePackage:
                    mode = .endNote
                    customURL = stagedURL
                case .paperFocusExport, .paperFocusStore:
                    mode = .paperFocus
                    customURL = stagedURL
                case .pdfFolder:
                    mode = .pdfFolder
                    customURL = stagedURL
                case .pdf:
                    mode = .pdfFiles
                case .unrecognized:
                    statusMessage = AppSettings.localizedString("无法识别该文献库格式。请选择 Zotero 数据目录、Zotero JSON、EndNote XML 或 PaperFocus 文献库。")
                }
            }
        }
    }

    private func performPrimaryAction() {
        switch mode {
        case .zotero:
            if let url = resolvedZoteroURL {
                run {
                    try await commitLibrary(at: url, linking: true)
                }
            } else {
                presentImporter(for: .zotero, commitImmediately: true)
            }
        case .endNote, .paperFocus, .pdfFolder:
            if let customURL {
                run {
                    try await commitLibrary(at: customURL, linking: mode != .pdfFolder)
                }
            } else {
                presentImporter(for: mode, commitImmediately: true)
            }
        case .pdfFiles:
            presentImporter(for: .pdfFiles, commitImmediately: true)
        }
    }

    private func presentImporter(for mode: LibraryImportMode, commitImmediately: Bool) {
        importerCommitImmediately = commitImmediately
        switch mode {
        case .zotero:
            importerTypes = [sqliteType, .folder, .json]
            importerAllowsMultiple = false
        case .endNote:
            importerTypes = [.xml]
            importerAllowsMultiple = false
        case .paperFocus:
            importerTypes = [sqliteType, .json, .folder, storeType]
            importerAllowsMultiple = false
        case .pdfFiles:
            importerTypes = [.pdf]
            importerAllowsMultiple = true
        case .pdfFolder:
            importerTypes = [.folder]
            importerAllowsMultiple = false
        }
        Task { @MainActor in
            showImporter = true
        }
    }

    private var sqliteType: UTType {
        UTType(filenameExtension: "sqlite") ?? .data
    }

    private var storeType: UTType {
        UTType(filenameExtension: "store") ?? .data
    }

    private func handleImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            statusMessage = AppSettings.localizedString(error.localizedDescription)
        case .success(let urls):
            guard !urls.isEmpty else { return }
            for url in urls {
                SecurityScopedBookmarkStore.shared.saveGrantedResource(at: url)
            }
            if mode == .pdfFiles {
                run {
                    try await importPDFs(urls)
                    await MainActor.run {
                        onFinished(AppSettings.localizedString("已导入所选 PDF。"))
                        dismiss()
                    }
                }
                return
            }

            customURL = urls[0]
            if mode == .zotero {
                selectedRootPath = ""
            }
            if importerCommitImmediately {
                run {
                    try await commitLibrary(at: urls[0], linking: mode != .pdfFolder)
                }
            }
        }
    }

    private func linkAccount() {
        run {
            let summary = try await libraryImportService.linkZoteroAccount(
                apiKey: zoteroAccountAPIKey,
                into: modelContext
            )
            let userID = UserDefaults.standard.string(forKey: AppSettings.zoteroAccountUserIDKey) ?? ""
            let username = UserDefaults.standard.string(forKey: AppSettings.zoteroAccountUsernameKey) ?? "Zotero"
            zoteroLinkedDisplayPath = userID.isEmpty
                ? "https://api.zotero.org"
                : "https://www.zotero.org/users/\(userID)"
            zoteroLinkedDisplayName = username
            zoteroSoleLibrary = useAsSoleLibrary
            await MainActor.run {
                onFinished(summary.syncMessage)
                dismiss()
            }
        }
    }

    private func commitLibrary(at url: URL, linking: Bool) async throws {
        let outcome = try await libraryImportService.intakeLibrary(from: url, linking: linking, into: modelContext)
        if let root = outcome.zoteroRoot {
            zoteroLinkedDisplayPath = root.path
            zoteroLinkedDisplayName = root.lastPathComponent
        }
        if let endNoteURL = outcome.endNoteURL {
            endNoteLinkedDisplayPath = endNoteURL.path
            endNoteLinkedDisplayName = endNoteURL.lastPathComponent
        }
        if outcome.adoptsZoteroCatalog {
            zoteroSoleLibrary = useAsSoleLibrary
        }
        await MainActor.run {
            onFinished(outcome.notice)
            dismiss()
        }
    }

    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        isWorking = true
        statusMessage = ""
        Task {
            do {
                try await operation()
            } catch {
                statusMessage = AppSettings.localizedString(error.localizedDescription)
            }
            isWorking = false
        }
    }
}
