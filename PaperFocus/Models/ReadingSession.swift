//
//  ReadingSession.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import Foundation
import SwiftData

@Model
final class ReadingSession {
    var paper: Paper?
    var paperTitle: String
    var mode: String
    var goal: String
    var durationMinutes: Int
    var completedMinutes: Int
    var isCompleted: Bool

    var summary: String
    var contribution: String
    var citationValue: String
    var question: String
    var nextStep: String

    var createdAt: Date

    init(
        paper: Paper? = nil,
        paperTitle: String,
        mode: String,
        goal: String,
        durationMinutes: Int,
        completedMinutes: Int = 0,
        isCompleted: Bool = false,
        summary: String = "",
        contribution: String = "",
        citationValue: String = "",
        question: String = "",
        nextStep: String = "",
        createdAt: Date = .now
    ) {
        self.paper = paper
        self.paperTitle = paperTitle
        self.mode = mode
        self.goal = goal
        self.durationMinutes = durationMinutes
        self.completedMinutes = completedMinutes
        self.isCompleted = isCompleted
        self.summary = summary
        self.contribution = contribution
        self.citationValue = citationValue
        self.question = question
        self.nextStep = nextStep
        self.createdAt = createdAt
    }
}
