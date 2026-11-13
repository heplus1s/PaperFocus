//
//  PaperDropZoneView.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

//
//  PaperDropZoneView.swift
//  PaperFocus
//

import SwiftUI
import UniformTypeIdentifiers

struct PaperDropZoneView: View {
    let isImporting: Bool
    let onDropFiles: ([URL]) -> Void
    let onRequestImport: () -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 34, weight: .regular))

            Text("导入文献")
                .font(.title3.weight(.semibold))

            Text("可将 PDF、Zotero 文献库、EndNote XML 或 PaperFocus 文献库拖入此处。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("选择导入方式", action: onRequestImport)
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .disabled(isImporting)

            if isImporting {
                ProgressView("正在导入…")
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 160)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    style: StrokeStyle(
                        lineWidth: 2,
                        dash: [8]
                    )
                )
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.55))
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                )
        )
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let typeIdentifier = UTType.fileURL.identifier
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []

        for provider in providers where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                defer { group.leave() }
                if let url = Self.url(from: item) {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            guard !urls.isEmpty else { return }
            onDropFiles(urls)
        }
        return !providers.isEmpty
    }

    private static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url.isFileURL ? url : URL(fileURLWithPath: url.path)
        }
        if let nsurl = item as? NSURL, let url = nsurl as URL? {
            return url.isFileURL ? url : URL(fileURLWithPath: url.path)
        }
        if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
            return url.isFileURL ? url : URL(fileURLWithPath: url.path)
        }
        return nil
    }
}

#Preview {
    PaperDropZoneView(isImporting: false, onDropFiles: { _ in }, onRequestImport: {})
        .padding()
}
