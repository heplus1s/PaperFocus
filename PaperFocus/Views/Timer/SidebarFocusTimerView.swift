//
//  SidebarFocusTimerView.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

//
//  SidebarFocusTimerView.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import SwiftUI
import SwiftData

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum StudyProgressOption: String, CaseIterable, Identifiable {
    case completedPlan
    case partialRead
    case previewOnly
    case belowExpectation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .completedPlan: return AppSettings.localizedString("完成当前计划")
        case .partialRead: return AppSettings.localizedString("读完部分内容")
        case .previewOnly: return AppSettings.localizedString("只完成预览")
        case .belowExpectation: return AppSettings.localizedString("未达到预期")
        }
    }
}

enum StudyUnderstandingOption: String, CaseIterable, Identifiable {
    case understoodCore
    case basicUnderstanding
    case needReview
    case notUnderstoodYet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .understoodCore: return AppSettings.localizedString("已理解核心内容")
        case .basicUnderstanding: return AppSettings.localizedString("基本理解")
        case .needReview: return AppSettings.localizedString("仍需回看")
        case .notUnderstoodYet: return AppSettings.localizedString("暂未理解")
        }
    }
}

enum StudyNextActionOption: String, CaseIterable, Identifiable {
    case continueReading
    case organizeNotes
    case reproduceMethod
    case archiveTemporarily

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .continueReading: return AppSettings.localizedString("下次继续阅读")
        case .organizeNotes: return AppSettings.localizedString("需要整理笔记")
        case .reproduceMethod: return AppSettings.localizedString("需要复现方法")
        case .archiveTemporarily: return AppSettings.localizedString("可暂时归档")
        }
    }
}

enum StudyImportanceOption: String, CaseIterable, Identifiable {
    case veryImportant
    case normal
    case temporarilyNormal
    case lowPriority

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .veryImportant: return AppSettings.localizedString("非常重要")
        case .normal: return AppSettings.localizedString("一般重要")
        case .temporarilyNormal: return AppSettings.localizedString("暂时一般")
        case .lowPriority: return AppSettings.localizedString("可低优先级处理")
        }
    }
}

enum SidebarFocusTimerDisplayMode {
    case full
    case compact
}

struct SidebarFocusTimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var navigationState: AppNavigationState
    #if os(macOS)
    @Environment(\.appearsActive) private var appearsActive
    #endif

    let displayMode: SidebarFocusTimerDisplayMode
    let showsAssistantToggle: Bool
    let fillsAvailableHeight: Bool
    let onOpenAssistant: (() -> Void)?
    let onExpandSidebar: (() -> Void)?

    @Query(sort: \Paper.createdAt, order: .reverse) private var papers: [Paper]
    @Query(sort: \FocusTask.createdAt, order: .reverse) private var focusTasks: [FocusTask]

    @AppStorage(AppSettings.autoStartOnOpenPDFKey)
    private var autoStartOnOpenPDF: Bool = AppSettings.defaultAutoStartOnOpenPDF

    @AppStorage(AppSettings.openPaperInFreeTimingKey)
    private var openPaperInFreeTiming: Bool = AppSettings.defaultOpenPaperInFreeTiming

    @AppStorage(AppSettings.useDefaultFocusPresetKey)
    private var useDefaultFocusPreset: Bool = AppSettings.defaultUseDefaultFocusPreset

    @AppStorage(AppSettings.minimumEffectiveMinutesKey)
    private var minimumEffectiveMinutes: Int = AppSettings.defaultMinimumEffectiveMinutes

    @AppStorage(AppSettings.focusMinutesKey)
    private var defaultFocusMinutes: Int = AppSettings.defaultFocusMinutes

    @AppStorage(AppSettings.defaultReadingModeKey)
    private var defaultReadingModeText: String = AppSettings.defaultReadingMode

    @AppStorage(AppSettings.defaultReadingGoalKey)
    private var defaultReadingGoalText: String = AppSettings.defaultReadingGoal

    @AppStorage(AppSettings.currentFocusMinutesKey)
    private var currentFocusMinutes: Int = AppSettings.defaultFocusMinutes

    @AppStorage(AppSettings.currentFocusModeKey)
    private var currentFocusModeRaw: String = AppSettings.defaultCurrentFocusMode

    @AppStorage(AppSettings.currentFocusGoalKey)
    private var currentFocusGoalRaw: String = AppSettings.defaultCurrentFocusGoal

    @AppStorage(AppSettings.currentFocusCustomGoalTextKey)
    private var currentFocusCustomGoalText: String = AppSettings.defaultCurrentFocusCustomGoalText

    @AppStorage(AppSettings.allowManualPaperTitleInputKey)
    private var allowManualPaperTitleInput: Bool = AppSettings.defaultAllowManualPaperTitleInput

    @State private var paperTitle: String = ""
    @State private var selectedGoal: ReadingGoalPreset = .finishIntroduction
    @State private var customGoalText: String = ""
    @State private var selectedMinutes: Int = 25
    @State private var selectedMode: FocusMode = .deepReading

    @State private var now: Date = .now
    @State private var timer: Timer?

    @State private var showCompletionSheet = false
    @ObservedObject private var pdfEditingCoordinator = PDFEditingCoordinator.shared
    @State private var showPDFSavePromptBeforeCompletion = false
    @State private var summaryNote: String = ""
    @State private var selectedProgress: StudyProgressOption = .completedPlan
    @State private var selectedUnderstanding: StudyUnderstandingOption = .basicUnderstanding
    @State private var selectedNextAction: StudyNextActionOption = .continueReading
    @State private var selectedImportance: StudyImportanceOption = .normal
    #if os(macOS)
    @State private var showStartHintPopover = false
    @State private var startHintHoverTask: DispatchWorkItem?
    #endif

    private var platformTextBackgroundColor: Color {
        #if os(iOS)
        return Color(uiColor: .secondarySystemBackground)
        #else
        return Color(nsColor: .textBackgroundColor)
        #endif
    }
    
    private var selectedPaper: Paper? {
        guard let id = navigationState.selectedPaperID else { return nil }
        return papers.first { $0.persistentModelID == id }
    }

    private var activeTask: FocusTask? {
        guard let id = navigationState.activeFocusTaskID else { return nil }
        return focusTasks.first { $0.persistentModelID == id }
    }

    private var displayedTitle: String {
        if let activeTask, !activeTask.paperTitleSnapshot.isEmpty {
            return activeTask.paperTitleSnapshot
        }
        if !paperTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return paperTitle
        }
        return AppSettings.localizedString("未选择文献")
    }

    private var currentState: FocusTaskState {
        guard let activeTask else { return .ready }
        return activeTask.state
    }

    private var liveElapsedSeconds: Int {
        guard let activeTask else { return 0 }

        switch activeTask.state {
        case .running:
            if let startedAt = activeTask.startedAt {
                return activeTask.elapsedSeconds + max(0, Int(now.timeIntervalSince(startedAt)))
            } else {
                return activeTask.elapsedSeconds
            }
        default:
            return activeTask.elapsedSeconds
        }
    }

    private var timeText: String {
        let total = liveElapsedSeconds
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private var statusText: String {
        switch currentState {
        case .ready: return AppSettings.localizedString("尚未开始")
        case .running: return AppSettings.localizedString("专注进行中")
        case .paused: return AppSettings.localizedString("已暂停")
        case .completed: return AppSettings.localizedString("已完成")
        case .cancelled: return AppSettings.localizedString("已取消")
        }
    }

    private var canStartFromCurrentContext: Bool {
        if navigationState.isReadingModeActive { return true }
        if navigationState.selectedSection == .library { return true }
        return false
    }

    private var shouldShowStartHint: Bool {
        !canStartFromCurrentContext && currentState == .ready
    }

    init(
        displayMode: SidebarFocusTimerDisplayMode = .full,
        showsAssistantToggle: Bool = false,
        fillsAvailableHeight: Bool = false,
        onOpenAssistant: (() -> Void)? = nil,
        onExpandSidebar: (() -> Void)? = nil
    ) {
        self.displayMode = displayMode
        self.showsAssistantToggle = showsAssistantToggle
        self.fillsAvailableHeight = fillsAvailableHeight
        self.onOpenAssistant = onOpenAssistant
        self.onExpandSidebar = onExpandSidebar
    }

    private var timerRootContent: AnyView {
        switch displayMode {
        case .compact:
            return AnyView(compactLayout)
        case .full:
            return AnyView(fullLayout)
        }
    }

    var body: some View {
        return timerRootContent
            .sheet(isPresented: $showCompletionSheet) {
                completionSheet
            }
            .confirmationDialog("当前 PDF 标注尚未保存", isPresented: $showPDFSavePromptBeforeCompletion, titleVisibility: .visible) {
                Button("保存并继续") {
                    _ = pdfEditingCoordinator.saveActiveDocument()
                    actuallyPrepareCompletion()
                }

                Button("不保存继续", role: .destructive) {
                    pdfEditingCoordinator.discardUnsavedState()
                    actuallyPrepareCompletion()
                }

                Button("取消", role: .cancel) { }
            } message: {
                Text("你当前正在阅读的 PDF 有未保存修改。是否先保存后再结束本轮学习？")
            }
            .onAppear(perform: handleAppear)
            .onDisappear(perform: handleDisappear)
            .onChange(of: navigationState.timerDraftTitle) { _, _ in handleTimerDraftTitleChanged() }
            .onChange(of: navigationState.selectedPaperID) { _, _ in handleSelectedPaperChanged() }
            .onChange(of: navigationState.activeFocusTaskID) { _, _ in handleActiveTaskChanged() }
            .onChange(of: now) { _, _ in handleClockTicked() }
            .onChange(of: navigationState.isReadingModeActive) { _, newValue in handleReadingModeChanged(newValue) }
            .onChange(of: navigationState.selectedSection) { _, newValue in handleSelectedSectionChanged(newValue) }
            .onChange(of: defaultFocusMinutes) { _, _ in handleDefaultFocusPresetChanged() }
            .onChange(of: defaultReadingModeText) { _, _ in handleDefaultFocusPresetChanged() }
            .onChange(of: defaultReadingGoalText) { _, _ in handleDefaultFocusPresetChanged() }
            .onChange(of: useDefaultFocusPreset) { _, _ in handleDefaultFocusPresetChanged() }
            .onChange(of: allowManualPaperTitleInput) { _, newValue in handleManualPaperTitleInputChanged(newValue) }
            .onChange(of: selectedMinutes) { _, _ in handleCurrentDraftSettingsChanged() }
            .onChange(of: selectedMode) { _, _ in handleCurrentDraftSettingsChanged() }
            .onChange(of: selectedGoal) { _, _ in handleCurrentDraftSettingsChanged() }
            .onChange(of: customGoalText) { _, _ in handleCurrentDraftSettingsChanged() }
            .onReceive(NotificationCenter.default.publisher(for: .focusLiveActivityCommand)) { notification in
                guard let command = notification.object as? FocusLiveActivityCommand else { return }
                handleLiveActivityCommand(command)
            }
    }

    private var fullLayout: some View {
        Group {
            if fillsAvailableHeight {
                ScrollView {
                    fullLayoutContent
                }
                .scrollIndicators(.automatic)
                .frame(maxWidth: 300, maxHeight: .infinity, alignment: .top)
            } else {
                fullLayoutContent
                    .frame(maxWidth: 300, alignment: .top)
            }
        }
        .background(timerPanelBackground(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .background(timerPanelOuterShadow(cornerRadius: 16))
    }

    private var fullLayoutContent: some View {
        VStack(spacing: 14) {
            HStack {
                Text("专注阅读")
                    .font(.headline)

                Spacer()

                if showsAssistantToggle, let onOpenAssistant {
                    Button {
                        onOpenAssistant()
                    } label: {
                        Image(systemName: fillsAvailableHeight ? "chevron.down" : "chevron.up")
                    }
                    .buttonStyle(.bordered)
                    .help(fillsAvailableHeight ? "收起专注阅读" : "展开专注阅读")
                }
            }

            fullTimerDetails
            taskInfoCard
            actionButtons
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var compactLayout: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .trailing) {
                Text(timeText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .center)

                if showsAssistantToggle, let onOpenAssistant {
                    Button {
                        onOpenAssistant()
                    } label: {
                        Image(systemName: fillsAvailableHeight ? "chevron.down" : "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    .help(fillsAvailableHeight ? "收起专注阅读" : "展开专注阅读")
                }
            }

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
                .frame(maxWidth: .infinity, alignment: .center)

            compactActionButtons
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(timerPanelBackground(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .background(timerPanelOuterShadow(cornerRadius: 16))
    }

    @ViewBuilder
    private func timerPanelBackground(cornerRadius: CGFloat) -> some View {
        #if os(macOS)
        if #available(macOS 26.0, *) {
            MacNativeTimerGlassBackground(
                cornerRadius: cornerRadius,
                colorScheme: colorScheme,
                isWindowActive: appearsActive
            )
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thinMaterial)
        }
        #else
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.thinMaterial)
        #endif
    }

    @ViewBuilder
    private func timerPanelOuterShadow(cornerRadius: CGFloat) -> some View {
        #if os(macOS)
        if #available(macOS 26.0, *), appearsActive {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.001))
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.18) : Color.black.opacity(0.075),
                    radius: colorScheme == .dark ? 18 : 14,
                    y: colorScheme == .dark ? 10 : 8
                )
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.10) : Color.black.opacity(0.035),
                    radius: colorScheme == .dark ? 8 : 6,
                    y: 1
                )
        }
        #endif
    }

    private var fullTimerDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("当前文献")
                .font(.caption)
                .foregroundStyle(.secondary)

            if allowManualPaperTitleInput {
                TextField("请输入当前文献标题", text: $paperTitle)
                    .textFieldStyle(.roundedBorder)
            } else {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(platformTextBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                        )

                    if paperTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("请输入当前文献标题")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                    } else {
                        Text(paperTitle)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, 10)
                            .help(paperTitle)
                    }
                }
                .frame(height: 32)
            }

            if !allowManualPaperTitleInput {
                Text("当前文献标题由文献库自动导入。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Toggle("进入 PDF 自动开始记录", isOn: $autoStartOnOpenPDF)

            HStack(spacing: 10) {
                Text("有效记录阈值")
                    .font(.caption)

                Spacer()

                Text(AppSettings.localizedMinutes(minimumEffectiveMinutes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                focusSettingsHeader
                focusModePicker
                focusGoalPicker
                customGoalField
                focusMinutesPicker
            }
            .disabled(useDefaultFocusPreset)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("当前状态")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                }

                Text(timeText)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.top, 6)
    }

    private var focusSettingsHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("专注设置")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            freeTimingToggle
        }
    }

    @ViewBuilder
    private var freeTimingToggle: some View {
        #if os(macOS)
        Toggle(isOn: $openPaperInFreeTiming) {
            Text("自由计时")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .toggleStyle(.checkbox)
        .font(.caption)
        .disabled(!autoStartOnOpenPDF)
        #endif
    }

    private var focusModePicker: some View {
        Picker("阅读模式", selection: $selectedMode) {
            ForEach(FocusMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
    }

    private var focusGoalPicker: some View {
        Picker("阅读目标", selection: $selectedGoal) {
            ForEach(ReadingGoalPreset.allCases) { goal in
                Text(goal.displayName).tag(goal)
            }
        }
    }

    @ViewBuilder
    private var customGoalField: some View {
        if selectedGoal == .custom {
            TextField("请输入自定义目标", text: $customGoalText)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var focusMinutesPicker: some View {
        Picker("专注时长", selection: $selectedMinutes) {
            Text("15 分钟").tag(15)
            Text("25 分钟").tag(25)
            Text("45 分钟").tag(45)
            Text("60 分钟").tag(60)
            Text("90 分钟").tag(90)
        }
    }

    @ViewBuilder
    private var compactActionButtons: some View {
        switch currentState {
        case .ready, .completed, .cancelled:
            Button("开始") {
                startTask(autoStarted: false)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canStartFromCurrentContext)

        case .running:
            HStack(spacing: 10) {
                Button("完成") {
                    prepareCompletion()
                }
                .buttonStyle(.borderedProminent)

                Button("暂停") {
                    pauseTask()
                }
                .buttonStyle(.bordered)

                Button("终止") {
                    cancelTask()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

        case .paused:
            HStack(spacing: 10) {
                Button("继续") {
                    resumeTask()
                }
                .buttonStyle(.borderedProminent)

                Button("完成") {
                    prepareCompletion()
                }
                .buttonStyle(.bordered)

                Button("终止") {
                    cancelTask()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    @ViewBuilder
    private var taskInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow("文献", displayedTitle)
            infoRow("目标", activeTask?.displayGoal ?? previewGoalText)
            infoRow("模式", activeTask?.mode.displayName ?? selectedMode.displayName)
            infoRow("计划", taskPlanText)
            infoRow(
                "阈值",
                AppSettings.localizedFormat(
                    "%@以上记为有效",
                    defaultValue: "Counts as effective above %@",
                    AppSettings.localizedMinutes(minimumEffectiveMinutes)
                )
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch currentState {
        case .ready, .completed, .cancelled:
            VStack(spacing: 10) {
                Button("开始") {
                    startTask(autoStarted: false)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(!canStartFromCurrentContext)
                #if os(macOS)
                .onHover { isHovering in
                    guard shouldShowStartHint else {
                        cancelStartHintHover()
                        return
                    }

                    if isHovering {
                        scheduleStartHintHover()
                    } else {
                        cancelStartHintHover()
                    }
                }
                .popover(isPresented: $showStartHintPopover, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                    Text("请进入文献库并打开论文，系统将自动开始专注记录。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(width: 220, alignment: .leading)
                        .padding(12)
                }
                #endif
            }

        case .running:
            VStack(spacing: 10) {
                Button("学习完毕并记录") {
                    prepareCompletion()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    Button("暂停") {
                        pauseTask()
                    }
                    .buttonStyle(.bordered)

                    Button("终止") {
                        cancelTask()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }

        case .paused:
            VStack(spacing: 10) {
                Button("继续") {
                    resumeTask()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    Button("学习完毕并记录") {
                        prepareCompletion()
                    }
                    .buttonStyle(.bordered)

                    Button("终止") {
                        cancelTask()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
    }

    private var completionSheet: some View {
        NavigationStack {
            Form {
                Section("本轮结果") {
                    Picker("阅读进度", selection: $selectedProgress) {
                        ForEach(StudyProgressOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    Picker("理解程度", selection: $selectedUnderstanding) {
                        ForEach(StudyUnderstandingOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    Picker("后续动作", selection: $selectedNextAction) {
                        ForEach(StudyNextActionOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    Picker("重要程度", selection: $selectedImportance) {
                        ForEach(StudyImportanceOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }

                Section("备注") {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(platformTextBackgroundColor)

                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)

                            TextEditor(text: $summaryNote)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 6)
                                .frame(minHeight: 120, maxHeight: 160)

                            if summaryNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("记录本次阅读中的补充想法、疑问、下一步安排……")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 14)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Section("记录规则") {
                    Text("本轮累计 \(liveElapsedSeconds / 60) 分钟，达到 \(minimumEffectiveMinutes) 分钟才记为有效专注。")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 560, idealWidth: 620)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showCompletionSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        finishTaskWithSummary()
                    }
                }
            }
        }
    }

    private var previewGoalText: String {
        if selectedGoal == .custom {
            let trimmed = customGoalText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? AppSettings.localizedString("自定义目标") : trimmed
        }
        return selectedGoal.displayName
    }

    private var taskPlanText: String {
        if let activeTask {
            return activeTask.plannedMinutes > 0
                ? AppSettings.localizedMinutes(activeTask.plannedMinutes)
                : AppSettings.localizedString("自由计时")
        }
        return AppSettings.localizedMinutes(selectedMinutes)
    }

    private var statusColor: Color {
        switch currentState {
        case .ready: return .secondary
        case .running: return .green
        case .paused: return .orange
        case .completed: return .blue
        case .cancelled: return .red
        }
    }

    private func handleAppear() {
        syncDraftFromNavigation()
        applyDefaultDraftsIfNeeded(force: true)
        startUITimerIfNeeded()
        refreshLiveActivity()

        DispatchQueue.main.async {
            autoStartIfNeeded()
            refreshLiveActivity()
        }
    }

    private func handleDisappear() {
        stopUITimer()
        refreshLiveActivity()
    }

    private func handleTimerDraftTitleChanged() {
        syncDraftFromNavigation()
    }

    private func handleSelectedPaperChanged() {
        syncDraftFromNavigation()
        if navigationState.isReadingModeActive {
            autoStartIfNeeded()
        }
    }

    private func handleActiveTaskChanged() {
        if activeTask == nil {
            applyDefaultDraftsIfNeeded(force: true)
        }
        startUITimerIfNeeded()
        refreshLiveActivity()
    }

    private func handleClockTicked() {
        refreshLiveActivity()
    }

    private func handleReadingModeChanged(_ newValue: Bool) {
        if newValue {
            syncDraftFromNavigation()
            autoStartIfNeeded()
        }
    }

    private func handleSelectedSectionChanged(_ newValue: AppSidebarSection?) {
        guard newValue != .library else { return }

        if let activeTask, activeTask.state == .running {
            pauseTask()
        }

        if navigationState.isReadingModeActive {
            navigationState.isReadingModeActive = false
        }
    }

    private func handleDefaultFocusPresetChanged() {
        applyDefaultDraftsIfNeeded(force: true)
    }

    private func handleManualPaperTitleInputChanged(_ newValue: Bool) {
        if newValue {
            paperTitle = ""
        } else {
            syncDraftFromNavigation()
        }
    }

    private func handleCurrentDraftSettingsChanged() {
        persistCurrentDraftSettingsIfNeeded()
    }

    private func infoRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)

            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
        }
        .font(.caption)
    }

    private func focusModeFromSetting(_ text: String) -> FocusMode {
        switch text {
        case "摘要速读":
            return .skimReading
        case "实验精读":
            return .summaryWriting
        case "做摘录":
            return .noteTaking
        case "方法精读":
            return .deepReading
        default:
            return .deepReading
        }
    }

    private func goalPresetFromSetting(_ text: String) -> ReadingGoalPreset {
        switch text {
        case "只读摘要":
            return .finishAbstract
        case "通读全文":
            return .finishIntroduction
        case "方法与公式":
            return .understandMethod
        case "实验结果":
            return .extractFigures
        case "写阅读总结":
            return .writeNotes
        default:
            return .custom
        }
    }

    private func restoreCurrentDraftSettings() {
        selectedMinutes = currentFocusMinutes
        selectedMode = FocusMode(rawValue: currentFocusModeRaw) ?? .deepReading
        selectedGoal = ReadingGoalPreset(rawValue: currentFocusGoalRaw) ?? .finishIntroduction
        customGoalText = selectedGoal == .custom ? currentFocusCustomGoalText : ""
    }

    private func persistCurrentDraftSettingsIfNeeded() {
        guard !useDefaultFocusPreset else { return }

        currentFocusMinutes = selectedMinutes
        currentFocusModeRaw = selectedMode.rawValue
        currentFocusGoalRaw = selectedGoal.rawValue
        currentFocusCustomGoalText = selectedGoal == .custom ? customGoalText : ""
    }

    private func applyDefaultDraftsIfNeeded(force: Bool = false) {
        guard force || activeTask == nil else { return }

        if useDefaultFocusPreset {
            selectedMinutes = defaultFocusMinutes
            selectedMode = focusModeFromSetting(defaultReadingModeText)

            let preset = goalPresetFromSetting(defaultReadingGoalText)
            selectedGoal = preset

            if preset == .custom {
                customGoalText = defaultReadingGoalText
            } else {
                customGoalText = ""
            }
        } else {
            restoreCurrentDraftSettings()
        }

        if !allowManualPaperTitleInput {
            syncDraftFromNavigation()
        }
    }

    private func syncDraftFromNavigation() {
        if let paper = selectedPaper {
            paperTitle = paper.displayTitle
        } else if !navigationState.timerDraftTitle.isEmpty {
            paperTitle = navigationState.timerDraftTitle
        }
    }

    private func startUITimerIfNeeded() {
        stopUITimer()

        guard let activeTask, activeTask.state == .running else { return }

        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            now = .now
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopUITimer() {
        timer?.invalidate()
        timer = nil
    }

    #if os(macOS)
    private func scheduleStartHintHover() {
        cancelStartHintHover()

        let task = DispatchWorkItem {
            if shouldShowStartHint {
                showStartHintPopover = true
            }
        }

        startHintHoverTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: task)
    }

    private func cancelStartHintHover() {
        startHintHoverTask?.cancel()
        startHintHoverTask = nil
        showStartHintPopover = false
    }
    #endif

    private func activeTaskMatchesSelectedPaper(_ task: FocusTask) -> Bool {
        guard let selectedPaper else { return false }

        if let taskPaper = task.paper {
            return taskPaper.persistentModelID == selectedPaper.persistentModelID
        }

        return task.paperTitleSnapshot == selectedPaper.displayTitle
    }

    private func autoStartIfNeeded() {
        guard autoStartOnOpenPDF else { return }
        guard navigationState.isReadingModeActive else { return }
        guard let selectedPaper else { return }

        if let activeTask {
            switch activeTask.state {
            case .running:
                return

            case .paused:
                if activeTaskMatchesSelectedPaper(activeTask) {
                    resumeTask()
                    return
                } else {
                    return
                }

            case .completed, .cancelled, .ready:
                break
            }
        }

        let trimmedTitle = selectedPaper.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        paperTitle = trimmedTitle
        startTask(autoStarted: true, openEnded: openPaperInFreeTiming)
    }

    private func startTask(autoStarted: Bool, openEnded: Bool = false) {
        let trimmedTitle = paperTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let task = FocusTask(
            paper: selectedPaper,
            paperTitleSnapshot: trimmedTitle,
            goalRaw: selectedGoal.rawValue,
            customGoalText: selectedGoal == .custom ? customGoalText : "",
            modeRaw: selectedMode.rawValue,
            stateRaw: FocusTaskState.running.rawValue,
            plannedMinutes: openEnded ? 0 : selectedMinutes,
            elapsedSeconds: 0,
            isAutoStarted: autoStarted,
            isEffectiveRecord: false,
            startedAt: .now,
            pausedAt: nil,
            finishedAt: nil,
            summaryNote: "",
            progressNote: "",
            questionNote: "",
            nextStepNote: "",
            createdAt: .now,
            updatedAt: .now
        )

        modelContext.insert(task)

        do {
            try modelContext.save()

            navigationState.activeFocusTaskID = task.persistentModelID
            navigationState.clearResumable()
            navigationState.isReadingModeActive = true

            now = .now
            startUITimerIfNeeded()
            refreshLiveActivity()
        } catch {
            print("创建专注任务失败：\(error)")
        }
    }

    private func pauseTask() {
        guard let activeTask, activeTask.state == .running else { return }

        activeTask.elapsedSeconds += runningSegmentSeconds(for: activeTask)
        activeTask.startedAt = nil
        activeTask.pausedAt = .now
        activeTask.state = .paused

        do {
            try modelContext.save()

            if let selectedPaper {
                navigationState.markResumable(
                    paperID: selectedPaper.persistentModelID,
                    title: selectedPaper.displayTitle
                )
            }

            stopUITimer()
            refreshLiveActivity()
        } catch {
            print("暂停专注任务失败：\(error.localizedDescription)")
        }
    }

    private func resumeTask() {
        guard let activeTask, activeTask.state == .paused else { return }

        activeTask.startedAt = .now
        activeTask.pausedAt = nil
        activeTask.state = .running

        do {
            try modelContext.save()

            navigationState.clearResumable()
            navigationState.isReadingModeActive = true
            now = .now
            startUITimerIfNeeded()
            refreshLiveActivity()
        } catch {
            print("继续专注任务失败：\(error.localizedDescription)")
        }
    }

    private func prepareCompletion() {
        if pdfEditingCoordinator.hasUnsavedChanges {
            showPDFSavePromptBeforeCompletion = true
            return
        }

        actuallyPrepareCompletion()
    }

    private func actuallyPrepareCompletion() {
        if let activeTask, activeTask.state == .running {
            activeTask.elapsedSeconds += runningSegmentSeconds(for: activeTask)
            activeTask.startedAt = nil
            activeTask.pausedAt = .now
            activeTask.state = .paused

            do {
                try modelContext.save()
            } catch {
                print("预完成保存失败：\(error.localizedDescription)")
            }
        }

        summaryNote = ""
        selectedProgress = .completedPlan
        selectedUnderstanding = .basicUnderstanding
        selectedNextAction = .continueReading
        selectedImportance = .normal
        showCompletionSheet = true
        stopUITimer()
        refreshLiveActivity()
    }

    private func finishTaskWithSummary() {
        guard let activeTask else { return }

        activeTask.summaryNote = summaryNote
        activeTask.progressNote = selectedProgress.displayName
        activeTask.questionNote = AppSettings.localizedFormat(
            "理解程度：%@；重要程度：%@",
            defaultValue: "Understanding: %@; Importance: %@",
            selectedUnderstanding.displayName,
            selectedImportance.displayName
        )
        activeTask.nextStepNote = selectedNextAction.displayName
        activeTask.finishedAt = .now
        activeTask.isEffectiveRecord = activeTask.elapsedMinutes >= minimumEffectiveMinutes
        activeTask.state = .completed
        activeTask.pausedAt = nil
        activeTask.startedAt = nil

        do {
            try modelContext.save()

            navigationState.isReadingModeActive = false
            navigationState.activeFocusTaskID = nil
            navigationState.clearResumable()

            summaryNote = ""
            selectedProgress = .completedPlan
            selectedUnderstanding = .basicUnderstanding
            selectedNextAction = .continueReading
            selectedImportance = .normal

            showCompletionSheet = false
            stopUITimer()
            now = .now
            applyDefaultDraftsIfNeeded(force: true)
            refreshLiveActivity()
        } catch {
            print("完成专注任务失败：\(error.localizedDescription)")
        }
    }

    private func cancelTask() {
        guard let activeTask else { return }

        if activeTask.state == .running {
            activeTask.elapsedSeconds += runningSegmentSeconds(for: activeTask)
        }

        activeTask.startedAt = nil
        activeTask.pausedAt = nil
        activeTask.finishedAt = .now
        activeTask.isEffectiveRecord = false
        activeTask.state = .cancelled

        do {
            try modelContext.save()

            navigationState.isReadingModeActive = false
            navigationState.activeFocusTaskID = nil
            navigationState.clearResumable()

            stopUITimer()
            now = .now
            applyDefaultDraftsIfNeeded(force: true)
            refreshLiveActivity()
        } catch {
            print("终止专注任务失败：\(error.localizedDescription)")
        }
    }

    private func refreshLiveActivity() {
        #if os(iOS)
        guard let activeTask else {
            FocusLiveActivityManager.shared.end()
            return
        }

        switch activeTask.state {
        case .running, .paused:
            FocusLiveActivityManager.shared.startOrUpdate(
                paperTitle: activeTask.paperTitleSnapshot,
                modeTitle: activeTask.mode.displayName,
                goalTitle: activeTask.displayGoal,
                elapsedSeconds: liveElapsedSeconds,
                plannedMinutes: activeTask.plannedMinutes,
                isPaused: activeTask.state == .paused
            )
        case .ready, .completed, .cancelled:
            FocusLiveActivityManager.shared.end()
        }
        #endif
    }

    private func handleLiveActivityCommand(_ command: FocusLiveActivityCommand) {
        switch command {
        case .open:
            navigationState.selectedSection = .library
            if activeTask != nil {
                navigationState.isReadingModeActive = true
            }

        case .pause:
            if let activeTask, activeTask.state == .running {
                pauseTask()
            }

        case .resume:
            if let activeTask, activeTask.state == .paused {
                resumeTask()
            }

        case .finish:
            quickFinishTaskFromLiveActivity()

        case .cancel:
            if activeTask != nil {
                cancelTask()
            }
        }
    }

    private func quickFinishTaskFromLiveActivity() {
        guard let activeTask else { return }

        if activeTask.state == .running {
            activeTask.elapsedSeconds += runningSegmentSeconds(for: activeTask)
        }

        activeTask.summaryNote = ""
        activeTask.progressNote = ""
        activeTask.questionNote = ""
        activeTask.nextStepNote = ""
        activeTask.finishedAt = .now
        activeTask.isEffectiveRecord = activeTask.elapsedMinutes >= minimumEffectiveMinutes
        activeTask.state = .completed
        activeTask.pausedAt = nil
        activeTask.startedAt = nil

        do {
            try modelContext.save()

            navigationState.isReadingModeActive = false
            navigationState.activeFocusTaskID = nil
            navigationState.clearResumable()

            showCompletionSheet = false
            stopUITimer()
            now = .now
            applyDefaultDraftsIfNeeded(force: true)
            refreshLiveActivity()
        } catch {
            print("灵动岛快速完成失败：\(error.localizedDescription)")
        }
    }
    
    
    private func runningSegmentSeconds(for task: FocusTask) -> Int {
        guard let startedAt = task.startedAt else { return 0 }
        return max(0, Int(Date().timeIntervalSince(startedAt)))
    }
}

#if os(macOS)
@available(macOS 26.0, *)
private struct MacNativeTimerGlassBackground: NSViewRepresentable {
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
            return NSColor(calibratedWhite: 0.02, alpha: isWindowActive ? 0.12 : 0.06)
        }
        return NSColor(calibratedWhite: 1.0, alpha: isWindowActive ? 0.12 : 0.05)
    }

    final class Coordinator {
        var glassView: NSGlassEffectView?
    }
}
#endif

#Preview {
    SidebarFocusTimerView()
        .padding()
        .environmentObject(AppNavigationState())
}
