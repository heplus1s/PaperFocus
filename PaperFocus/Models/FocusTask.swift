//
//  FocusTask.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import Foundation
import SwiftData

enum FocusTaskState: String, CaseIterable, Codable, Identifiable {
    case ready
    case running
    case paused
    case completed
    case cancelled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ready: return AppSettings.localizedString("未开始")
        case .running: return AppSettings.localizedString("进行中")
        case .paused: return AppSettings.localizedString("已暂停")
        case .completed: return AppSettings.localizedString("已完成")
        case .cancelled: return AppSettings.localizedString("已取消")
        }
    }
}

enum FocusMode: String, CaseIterable, Codable, Identifiable {
    case deepReading
    case skimReading
    case noteTaking
    case summaryWriting

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepReading: return AppSettings.localizedString("精读")
        case .skimReading: return AppSettings.localizedString("粗读")
        case .noteTaking: return AppSettings.localizedString("做笔记")
        case .summaryWriting: return AppSettings.localizedString("总结整理")
        }
    }
}

enum ReadingGoalPreset: String, CaseIterable, Codable, Identifiable {
    case finishAbstract
    case finishIntroduction
    case understandMethod
    case extractFigures
    case writeNotes
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .finishAbstract: return AppSettings.localizedString("读完摘要")
        case .finishIntroduction: return AppSettings.localizedString("读完引言")
        case .understandMethod: return AppSettings.localizedString("理解方法部分")
        case .extractFigures: return AppSettings.localizedString("提取图表信息")
        case .writeNotes: return AppSettings.localizedString("整理阅读笔记")
        case .custom: return AppSettings.localizedString("自定义目标")
        }
    }
}

@Model
final class FocusTask {
    var uuid: String
    var paperTitleSnapshot: String

    var goalRaw: String
    var customGoalText: String
    var modeRaw: String
    var stateRaw: String

    var plannedMinutes: Int
    var elapsedSeconds: Int

    var isAutoStarted: Bool
    var isEffectiveRecord: Bool

    var startedAt: Date?
    var pausedAt: Date?
    var finishedAt: Date?

    // 学习总结 / 备注
    var summaryNote: String
    var progressNote: String
    var questionNote: String
    var nextStepNote: String

    var createdAt: Date
    var updatedAt: Date

    @Relationship
    var paper: Paper?

    init(
        paper: Paper? = nil,
        paperTitleSnapshot: String = "",
        goalRaw: String = ReadingGoalPreset.finishIntroduction.rawValue,
        customGoalText: String = "",
        modeRaw: String = FocusMode.deepReading.rawValue,
        stateRaw: String = FocusTaskState.ready.rawValue,
        plannedMinutes: Int = 25,
        elapsedSeconds: Int = 0,
        isAutoStarted: Bool = false,
        isEffectiveRecord: Bool = false,
        startedAt: Date? = nil,
        pausedAt: Date? = nil,
        finishedAt: Date? = nil,
        summaryNote: String = "",
        progressNote: String = "",
        questionNote: String = "",
        nextStepNote: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.uuid = UUID().uuidString
        self.paper = paper
        self.paperTitleSnapshot = paperTitleSnapshot
        self.goalRaw = goalRaw
        self.customGoalText = customGoalText
        self.modeRaw = modeRaw
        self.stateRaw = stateRaw
        self.plannedMinutes = plannedMinutes
        self.elapsedSeconds = elapsedSeconds
        self.isAutoStarted = isAutoStarted
        self.isEffectiveRecord = isEffectiveRecord
        self.startedAt = startedAt
        self.pausedAt = pausedAt
        self.finishedAt = finishedAt
        self.summaryNote = summaryNote
        self.progressNote = progressNote
        self.questionNote = questionNote
        self.nextStepNote = nextStepNote
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension FocusTask {
    var state: FocusTaskState {
        get { FocusTaskState(rawValue: stateRaw) ?? .ready }
        set {
            stateRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    var mode: FocusMode {
        get { FocusMode(rawValue: modeRaw) ?? .deepReading }
        set {
            modeRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    var goalPreset: ReadingGoalPreset {
        get { ReadingGoalPreset(rawValue: goalRaw) ?? .finishIntroduction }
        set {
            goalRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    var displayGoal: String {
        if goalPreset == .custom {
            let trimmed = customGoalText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? AppSettings.localizedString("自定义目标") : trimmed
        }
        return goalPreset.displayName
    }

    var elapsedMinutes: Int {
        elapsedSeconds / 60
    }

    var elapsedText: String {
        let total = elapsedSeconds
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}
