//
//  FocusTimerView.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

//
//  FocusTimerView.swift
//  PaperFocus
//

import SwiftUI

struct FocusTimerView: View {
    @StateObject private var viewModel = TimerViewModel()

    let paper: Paper?
    let embeddedInSidebar: Bool

    @State private var paperTitle: String
    @State private var goal: String = "看懂摘要与方法框架"
    @State private var selectedMinutes: Int = 25
    @State private var selectedMode: String = "方法精读"

    @State private var showSummaryPage = false

    init(
        paper: Paper? = nil,
        defaultPaperTitle: String = "",
        embeddedInSidebar: Bool = false
    ) {
        self.paper = paper
        self.embeddedInSidebar = embeddedInSidebar
        _paperTitle = State(initialValue: paper?.title ?? defaultPaperTitle)
    }

    var body: some View {
        Form {
            Section("阅读任务") {
                TextField("文献标题", text: $paperTitle)
                TextField("本轮目标", text: $goal)

                Picker("阅读模式", selection: $selectedMode) {
                    Text("摘要速读").tag("摘要速读")
                    Text("方法精读").tag("方法精读")
                    Text("实验精读").tag("实验精读")
                    Text("做摘录").tag("做摘录")
                }

                Picker("时长", selection: $selectedMinutes) {
                    Text("15 分钟").tag(15)
                    Text("25 分钟").tag(25)
                    Text("45 分钟").tag(45)
                    Text("60 分钟").tag(60)
                }
            }

            Section("专注计时") {
                VStack(spacing: 16) {
                    Text(viewModel.timeText)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)

                    if viewModel.isRunning {
                        Text("专注进行中")
                            .foregroundStyle(.green)
                    } else {
                        Text("尚未开始")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Button("开始") {
                            viewModel.start(minutes: selectedMinutes)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isRunning)

                        Button("暂停") {
                            viewModel.pause()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!viewModel.isRunning)

                        Button("重置") {
                            viewModel.reset(minutes: selectedMinutes)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("完成") {
                Button("结束本轮并写总结") {
                    viewModel.pause()
                    showSummaryPage = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(paperTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle(embeddedInSidebar ? "" : "专注阅读")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(isPresented: $showSummaryPage) {
            SessionSummaryView(
                paper: paper,
                paperTitle: paperTitle.isEmpty ? AppSettings.localizedString("未命名文献") : paperTitle,
                mode: selectedMode,
                goal: goal,
                durationMinutes: selectedMinutes,
                completedMinutes: viewModel.completedMinutes(defaultMinutes: selectedMinutes),
                isCompleted: viewModel.completedMinutes(defaultMinutes: selectedMinutes) >= selectedMinutes
            )
        }
    }
}

#Preview {
    NavigationStack {
        FocusTimerView()
    }
}
