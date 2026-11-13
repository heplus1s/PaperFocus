//
//  FocusLiveActivityAttributes.swift
//  PaperFocus
//
//  Created by PaperFocus on 29/3/2026.
//

import Foundation
import ActivityKit

struct FocusLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var paperTitle: String
        var modeTitle: String
        var goalTitle: String
        var elapsedSeconds: Int
        var plannedMinutes: Int
        var isPaused: Bool
    }

    var sessionName: String
}
