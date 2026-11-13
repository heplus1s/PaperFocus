//
//  PaperFocusWidgetsLiveActivity.swift
//  PaperFocusWidgets
//
//  Created by PaperFocus on 29/3/2026.
//

import SwiftUI
import WidgetKit
import ActivityKit

struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text(context.state.paperTitle)
                    .font(.headline)
                    .lineLimit(1)

                Text(context.state.isPaused ? "已暂停" : "阅读中")
                    .font(.caption)
                    .foregroundStyle(context.state.isPaused ? .orange : .green)

                Text(timeText(from: context.state.elapsedSeconds))
                    .font(.system(.title2, design: .rounded).monospacedDigit())
                    .fontWeight(.semibold)
            }
            .padding()
            .activityBackgroundTint(Color.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PaperFocus")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(context.state.paperTitle)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.isPaused ? "已暂停" : "进行中")
                        .font(.caption)
                        .foregroundStyle(context.state.isPaused ? .orange : .green)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(timeText(from: context.state.elapsedSeconds))
                        .font(.system(.title3, design: .rounded).monospacedDigit())
                        .fontWeight(.semibold)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        if context.state.isPaused {
                            Link(destination: liveActivityURL("resume")) {
                                islandActionLabel("继续", systemImage: "play.fill")
                            }
                        } else {
                            Link(destination: liveActivityURL("pause")) {
                                islandActionLabel("暂停", systemImage: "pause.fill")
                            }
                        }

                        Link(destination: liveActivityURL("finish")) {
                            islandActionLabel("完成", systemImage: "checkmark.circle.fill")
                        }

                        Link(destination: liveActivityURL("cancel")) {
                            islandActionLabel("终止", systemImage: "xmark.circle.fill")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
            } compactTrailing: {
                Text(shortTimeText(from: context.state.elapsedSeconds))
                    .font(.system(.caption2, design: .rounded).monospacedDigit())
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
            }
        }
    }

    @ViewBuilder
    private func islandActionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color.white.opacity(0.16))
            )
    }

    private func liveActivityURL(_ action: String) -> URL {
        URL(string: "paperfocus://focus?action=\(action)")!
    }

    private func timeText(from total: Int) -> String {
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60

        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private func shortTimeText(from total: Int) -> String {
        let h = total / 3600
        let m = (total % 3600) / 60

        if h > 0 {
            return String(format: "%d:%02d", h, m)
        } else {
            return String(format: "%02d", m)
        }
    }
}
