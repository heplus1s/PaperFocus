//
//  PDFPicker.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct PDFPicker: View {
    let onPick: (URL) -> Void

    var body: some View {
        PDFPickerRepresentable(onPick: onPick)
            .ignoresSafeArea()
    }
}

#if os(iOS)
import UIKit

struct PDFPickerRepresentable: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.pdf],
            asCopy: true
        )
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        controller.shouldShowFileExtensions = true
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            print("PDFPicker picked:", url)
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("PDFPicker cancelled")
        }
    }
}
#elseif os(macOS)
import AppKit

struct PDFPickerRepresentable: NSViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeNSViewController(context: Context) -> NSViewController {
        let controller = NSViewController()
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.pdf]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true

            if panel.runModal() == .OK, let url = panel.url {
                onPick(url)
            }
        }
        return controller
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) { }
}
#endif
