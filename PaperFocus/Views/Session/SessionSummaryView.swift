//
//  SessionSummaryView.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import SwiftUI
import SwiftData

struct SessionSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let paper: Paper?
    let paperTitle: String
    let mode: String
    let goal: String
    let durationMinutes: Int
    let completedMinutes: Int
    let isCompleted: Bool

    @State private var summary: String = ""
    @State private var contribution: String = ""
    @State private var citationValue: String = ""
    @State private var question: String = ""
    @State private var nextStep: String = ""

    private var localizedMode: String {
        AppSettings.localizedString(mode, defaultValue: mode)
    }

    var body: some View {
        Form {
            Section("本轮信息") {
                Text(AppSettings.localizedFormat("文献：%@", defaultValue: "Paper: %@", paperTitle))
                Text(AppSettings.localizedFormat("模式：%@", defaultValue: "Mode: %@", localizedMode))
                Text(AppSettings.localizedFormat("目标：%@", defaultValue: "Goal: %@", goal))
                Text(AppSettings.localizedFormat("计划时长：%@", defaultValue: "Planned: %@", AppSettings.localizedMinutes(durationMinutes)))
                Text(AppSettings.localizedFormat("实际完成：%@", defaultValue: "Completed: %@", AppSettings.localizedMinutes(completedMinutes)))
                Text(isCompleted ? "状态：已完成" : "状态：未完整完成")
                    .foregroundStyle(isCompleted ? .green : .orange)
            }

            Section("阅读总结") {
                TextField("一句话总结", text: $summary, axis: .vertical)
                    .lineLimit(2...4)

                TextField("这篇文章的主要贡献", text: $contribution, axis: .vertical)
                    .lineLimit(2...4)

                TextField("可引用点 / 可借鉴点", text: $citationValue, axis: .vertical)
                    .lineLimit(2...4)

                TextField("当前没看懂的问题", text: $question, axis: .vertical)
                    .lineLimit(2...4)

                TextField("下一轮准备做什么", text: $nextStep, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section {
                Button("保存本轮记录") {
                    saveSession()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("阅读总结")
    }

    private func saveSession() {
        let session = ReadingSession(
            paper: paper,
            paperTitle: paperTitle,
            mode: mode,
            goal: goal,
            durationMinutes: durationMinutes,
            completedMinutes: completedMinutes,
            isCompleted: isCompleted,
            summary: summary,
            contribution: contribution,
            citationValue: citationValue,
            question: question,
            nextStep: nextStep
        )

        if let paper {
            if completedMinutes > 0 {
                if completedMinutes >= durationMinutes {
                    paper.statusRaw = PaperStatus.finished.rawValue
                } else {
                    paper.statusRaw = PaperStatus.reading.rawValue
                }
            }
        }

        modelContext.insert(session)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SessionSummaryView(
            paper: nil,
            paperTitle: "Example Paper",
            mode: "方法精读",
            goal: "看懂方法框架",
            durationMinutes: 25,
            completedMinutes: 25,
            isCompleted: true
        )
    }
}
