//
//  FocusLiveActivityActionRouter.swift
//  PaperFocus
//
//  Created by PaperFocus on 29/3/2026.
//

import Foundation

enum FocusLiveActivityCommand: String {
    case open
    case pause
    case resume
    case finish
    case cancel
}

extension Notification.Name {
    static let focusLiveActivityCommand = Notification.Name("focusLiveActivityCommand")
}

enum FocusLiveActivityActionRouter {
    static let scheme = "paperfocus"
    static let host = "focus"

    static func url(for command: FocusLiveActivityCommand) -> URL {
        URL(string: "\(scheme)://\(host)?action=\(command.rawValue)")!
    }

    static func handle(_ url: URL) {
        guard url.scheme == scheme, url.host == host else { return }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let action = components.queryItems?.first(where: { $0.name == "action" })?.value,
              let command = FocusLiveActivityCommand(rawValue: action) else {
            return
        }

        NotificationCenter.default.post(name: .focusLiveActivityCommand, object: command)
    }
}
