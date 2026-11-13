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
    let onDropPDF: (URL) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 34, weight: .regular))

            Text("拖入 PDF 自动新增文献")
                .font(.title3.weight(.semibold))

            Text("支持将论文 PDF 直接拖到这里，系统会自动识别 DOI 并补全文献信息。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

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
        guard let provider = providers.first else {
            print("Drop failed: no provider")
            return false
        }

        let typeIdentifier = UTType.fileURL.identifier

        guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else {
            print("Drop failed: provider does not conform to fileURL")
            return false
        }

        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
            if let error {
                print("Drop loadItem error: \(error)")
                return
            }

            if let url = item as? URL {
                handleResolvedURL(url)
                return
            }

            if let nsurl = item as? NSURL, let url = nsurl as URL? {
                handleResolvedURL(url)
                return
            }

            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                handleResolvedURL(url)
                return
            }

            print("Drop failed: unsupported dropped item type = \(String(describing: item))")
        }

        return true
    }

    private func handleResolvedURL(_ url: URL) {
        let normalizedURL: URL

        if url.isFileURL {
            normalizedURL = url
        } else {
            normalizedURL = URL(fileURLWithPath: url.path)
        }

        print("Dropped file URL: \(normalizedURL.path)")

        guard normalizedURL.pathExtension.lowercased() == "pdf" else {
            print("Drop ignored: not a PDF")
            return
        }

        DispatchQueue.main.async {
            onDropPDF(normalizedURL)
        }
    }
}

#Preview {
    PaperDropZoneView(isImporting: false) { _ in }
        .padding()
}
