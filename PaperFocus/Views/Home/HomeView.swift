//
//  HomeView.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

//
//  HomeView.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Paper.createdAt, order: .reverse) private var papers: [Paper]
    @Query(sort: \FocusTask.createdAt, order: .reverse) private var focusTasks: [FocusTask]
    @EnvironmentObject private var navigationState: AppNavigationState

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @State private var isRecentFocusExpanded = true
    @State private var isRecentPapersExpanded = true

    private var effectiveCompletedTasks: [FocusTask] {
        focusTasks
            .filter { $0.state == .completed && $0.isEffectiveRecord }
            .sorted { ($0.finishedAt ?? $0.createdAt) > ($1.finishedAt ?? $1.createdAt) }
    }

    private var todayEffectiveCount: Int {
        let calendar = Calendar.current
        return effectiveCompletedTasks.filter {
            guard let finishedAt = $0.finishedAt else { return false }
            return calendar.isDateInToday(finishedAt)
        }.count
    }

    private var todayMinutes: Int {
        let calendar = Calendar.current
        return effectiveCompletedTasks.reduce(0) { partial, task in
            guard let finishedAt = task.finishedAt, calendar.isDateInToday(finishedAt) else {
                return partial
            }
            return partial + task.elapsedMinutes
        }
    }

    private var totalPaperCount: Int {
        papers.count
    }

    private var shouldShowResumeToolbarButton: Bool {
        !navigationState.isReadingModeActive && navigationState.isResumeAvailable
    }

    private var isCompactHomeLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private var shouldShowInlineOverviewCard: Bool {
        #if os(macOS)
        false
        #else
        true
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if shouldShowInlineOverviewCard {
                    overviewCard
                }

                if isCompactHomeLayout {
                    VStack(alignment: .leading, spacing: 16) {
                        collapsibleFocusRecordsCard
                        collapsibleRecentPapersCard
                    }
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        focusRecordsCard
                        recentPapersCard
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding()
        }
        .toolbar {
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

            #if !os(macOS)
            ToolbarItem(placement: .principal) {
                if shouldShowResumeToolbarButton {
                    ResumeFocusToolbarButton(title: navigationState.resumablePaperTitle) {
                        navigationState.resumeLastReading()
                    }
                }
            }
            #endif

            #if os(macOS)
            if #available(macOS 26.0, *) {
                ToolbarItemGroup(placement: .automatic) {
                    if shouldShowResumeToolbarButton {
                        ResumeFocusToolbarButton(title: navigationState.resumablePaperTitle) {
                            navigationState.resumeLastReading()
                        }
                    }
                    toolbarTrailingPlaceholder
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItemGroup(placement: .automatic) {
                    if shouldShowResumeToolbarButton {
                        ResumeFocusToolbarButton(title: navigationState.resumablePaperTitle) {
                            navigationState.resumeLastReading()
                        }
                    }
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

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("总览")
                .font(.title2.bold())

            if isCompactHomeLayout {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        statItem(title: "总文献", value: "\(totalPaperCount)")
                        statItem(title: "有效专注", value: "\(effectiveCompletedTasks.count)")
                    }

                    HStack(spacing: 10) {
                        statItem(title: "今日完成", value: "\(todayEffectiveCount)")
                        statItem(title: "今日分钟", value: "\(todayMinutes)")
                    }
                }
            } else {
                HStack(spacing: 14) {
                    statItem(title: "总文献", value: "\(totalPaperCount)")
                    statItem(title: "有效专注", value: "\(effectiveCompletedTasks.count)")
                    statItem(title: "今日完成", value: "\(todayEffectiveCount)")
                    statItem(title: "今日分钟", value: "\(todayMinutes)")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var collapsibleFocusRecordsCard: some View {
        DisclosureGroup(isExpanded: $isRecentFocusExpanded) {
            focusRecordsContent
                .padding(.top, 8)
        } label: {
            Text("最近专注记录")
                .font(.title3.bold())
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var collapsibleRecentPapersCard: some View {
        DisclosureGroup(isExpanded: $isRecentPapersExpanded) {
            recentPapersContent
                .padding(.top, 8)
        } label: {
            Text("最近文献")
                .font(.title3.bold())
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var focusRecordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近专注记录")
                .font(.title3.bold())

            focusRecordsContent
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var recentPapersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近文献")
                .font(.title3.bold())

            recentPapersContent
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var focusRecordsContent: some View {
        if effectiveCompletedTasks.isEmpty {
            Text("还没有有效专注记录。")
                .foregroundStyle(.secondary)
        } else {
            ForEach(Array(effectiveCompletedTasks.prefix(5))) { task in
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.paperTitleSnapshot.isEmpty ? AppSettings.localizedString("未命名文献") : task.paperTitleSnapshot)
                        .font(.headline)

                    Text(
                        AppSettings.localizedFormat(
                            "%@ · %@ · %@",
                            defaultValue: "%@ · %@ · %@",
                            task.mode.displayName,
                            AppSettings.localizedMinutes(task.elapsedMinutes),
                            task.displayGoal
                        )
                    )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !task.summaryNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(task.summaryNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if task.persistentModelID != Array(effectiveCompletedTasks.prefix(5)).last?.persistentModelID {
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private var recentPapersContent: some View {
        if papers.isEmpty {
            Text("还没有文献，请先导入 PDF。")
                .foregroundStyle(.secondary)
        } else {
            ForEach(Array(papers.prefix(5))) { paper in
                VStack(alignment: .leading, spacing: 4) {
                    Text(paper.title.isEmpty ? AppSettings.localizedString("未命名文献") : paper.title)
                        .font(.headline)

                    Text(
                        AppSettings.localizedFormat(
                            "%@ · %@",
                            defaultValue: "%@ · %@",
                            paper.authors.isEmpty ? AppSettings.localizedString("未知作者") : paper.authors,
                            paper.displayYear
                        )
                    )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(
                        AppSettings.localizedFormat(
                            "状态：%@",
                            defaultValue: "Status: %@",
                            paper.status.displayName
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if paper.persistentModelID != Array(papers.prefix(5)).last?.persistentModelID {
                    Divider()
                }
            }
        }
    }

    private func statItem(title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
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
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
