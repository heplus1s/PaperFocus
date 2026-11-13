//
//  TimerViewModel.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

//
//  TimerViewModel.swift
//  PaperFocus
//

import Foundation
import Combine

final class TimerViewModel: ObservableObject {
    @Published var remainingSeconds: Int = 25 * 60
    @Published var isRunning: Bool = false

    private var totalSeconds: Int = 25 * 60
    private var timer: AnyCancellable?

    var hasStarted: Bool {
        remainingSeconds < totalSeconds || isRunning
    }

    var timeText: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start(minutes: Int) {
        if remainingSeconds <= 0 || remainingSeconds > minutes * 60 {
            totalSeconds = minutes * 60
            remainingSeconds = totalSeconds
        }

        guard !isRunning else { return }

        if remainingSeconds == totalSeconds {
            totalSeconds = minutes * 60
            remainingSeconds = totalSeconds
        }

        isRunning = true

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }

                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                } else {
                    self.pause()
                }
            }
    }

    func pause() {
        isRunning = false
        timer?.cancel()
        timer = nil
    }

    func reset(minutes: Int) {
        pause()
        totalSeconds = minutes * 60
        remainingSeconds = totalSeconds
    }

    func completedMinutes(defaultMinutes: Int) -> Int {
        let usedSeconds = (defaultMinutes * 60) - remainingSeconds
        return max(0, usedSeconds / 60)
    }
}
