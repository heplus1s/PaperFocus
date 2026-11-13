//
//  FloatingFocusTimerHUD.swift
//  PaperFocus
//
//  Created by PaperFocus on 30/3/2026.
//
import SwiftUI
import SwiftData

struct FloatingFocusTimerHUD: View {
    @EnvironmentObject private var navigationState: AppNavigationState
    @Query(sort: \FocusTask.createdAt, order: .reverse) private var focusTasks: [FocusTask]

    @State private var now: Date = .now
    @State private var timer: Timer?
    @State private var isMiniMode = false

    private var activeTask: FocusTask? {
        guard let id = navigationState.activeFocusTaskID else { return nil }
        return focusTasks.first { $0.persistentModelID == id }
    }

    private var shouldShow: Bool {
        guard let activeTask else { return false }
        return navigationState.isReadingModeActive &&
               (activeTask.state == .running || activeTask.state == .paused)
    }

    private var liveElapsedSeconds: Int {
        guard let activeTask else { return 0 }

        switch activeTask.state {
        case .running:
            if let startedAt = activeTask.startedAt {
                return activeTask.elapsedSeconds + max(0, Int(now.timeIntervalSince(startedAt)))
            } else {
                return activeTask.elapsedSeconds
            }
        default:
            return activeTask.elapsedSeconds
        }
    }

    private var timeText: String {
        let total = liveElapsedSeconds
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60

        if h > 0 {
            return String(format: "%02d:%02d", h, m)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private var statusColor: Color {
        guard let activeTask else { return .secondary }
        switch activeTask.state {
        case .running:
            return .green
        case .paused:
            return .orange
        default:
            return .secondary
        }
    }

    private var circleSize: CGFloat {
        isMiniMode ? 26 : 58
    }

    var body: some View {
        Group {
            if shouldShow {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)

                    Circle()
                        .stroke(statusColor, lineWidth: isMiniMode ? 3 : 4)

                    if !isMiniMode {
                        Text(timeText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: circleSize, height: circleSize)
                .shadow(radius: 8, y: 2)
                .contentShape(Circle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isMiniMode.toggle()
                    }
                }
                .padding(.trailing, 12)
                .padding(.top, 56)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: shouldShow)
        .onAppear {
            startTimerIfNeeded()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: navigationState.activeFocusTaskID) { _, _ in
            startTimerIfNeeded()
        }
        .onChange(of: navigationState.isReadingModeActive) { _, _ in
            startTimerIfNeeded()
        }
    }

    private func startTimerIfNeeded() {
        stopTimer()

        guard shouldShow else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            now = .now
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
