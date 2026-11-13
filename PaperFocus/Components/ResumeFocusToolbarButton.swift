//
//  ResumeFocusToolbarButton.swift
//  PaperFocus
//
//  Created by PaperFocus on 27/3/2026.
//

import SwiftUI

struct ResumeFocusToolbarButton: View {
    let title: String
    let action: () -> Void

    private var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func truncatedTitle(limit: Int) -> String {
        guard !normalizedTitle.isEmpty else { return "" }
        if normalizedTitle.count <= limit { return normalizedTitle }
        return String(normalizedTitle.prefix(limit)) + "..."
    }

    @ViewBuilder
    private func compactLabel(limit: Int) -> some View {
        Label {
            Text(normalizedTitle.isEmpty ? "继续阅读" : "继续阅读：\(truncatedTitle(limit: limit))")
                .lineLimit(1)
                .truncationMode(.tail)
        } icon: {
            Image(systemName: "play.fill")
        }
        .labelStyle(.titleAndIcon)
    }

    var body: some View {
        Button(action: action) {
            #if os(macOS)
            ViewThatFits(in: .horizontal) {
                compactLabel(limit: 30)
                compactLabel(limit: 20)
                compactLabel(limit: 10)
                Image(systemName: "play.fill")
            }
            .font(.system(size: 12, weight: .semibold))
            .frame(maxWidth: 320, alignment: .leading)
            .contentShape(Rectangle())
            #endif
        }
        #if os(macOS)
        .modifier(Mac26GlassStyleModifier())
        #else
        .buttonStyle(.borderedProminent)
        #endif
    }
}

#if os(macOS)
private struct Mac26GlassStyleModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}
#endif
