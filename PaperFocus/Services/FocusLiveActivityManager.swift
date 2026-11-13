//
//  FocusLiveActivityManager.swift
//  PaperFocus
//
//  Created by PaperFocus on 29/3/2026.
//

import Foundation

#if os(iOS) && canImport(ActivityKit)
import ActivityKit

@MainActor
final class FocusLiveActivityManager {
    static let shared = FocusLiveActivityManager()

    private var currentActivity: Activity<FocusLiveActivityAttributes>?

    private init() { }

    func startOrUpdate(
        paperTitle: String,
        modeTitle: String,
        goalTitle: String,
        elapsedSeconds: Int,
        plannedMinutes: Int,
        isPaused: Bool
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let trimmedTitle = paperTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let state = FocusLiveActivityAttributes.ContentState(
            paperTitle: trimmedTitle,
            modeTitle: modeTitle,
            goalTitle: goalTitle,
            elapsedSeconds: max(0, elapsedSeconds),
            plannedMinutes: max(1, plannedMinutes),
            isPaused: isPaused
        )

        Task {
            if let currentActivity {
                await currentActivity.update(
                    ActivityContent(state: state, staleDate: nil)
                )
            } else {
                let attributes = FocusLiveActivityAttributes(sessionName: "PaperFocus 专注")
                currentActivity = try? Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
            }
        }
    }

    func end() {
        guard let currentActivity else { return }

        Task {
            await currentActivity.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
        }
    }
}
#else
@MainActor
final class FocusLiveActivityManager {
    static let shared = FocusLiveActivityManager()
    private init() { }

    func startOrUpdate(
        paperTitle: String,
        modeTitle: String,
        goalTitle: String,
        elapsedSeconds: Int,
        plannedMinutes: Int,
        isPaused: Bool
    ) { }

    func end() { }
}
#endif
