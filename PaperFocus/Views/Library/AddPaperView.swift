//
//  AddPaperView.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import SwiftUI

struct AddPaperView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var authors: String = ""
    @State private var yearText: String = ""
    @State private var selectedStatus: PaperStatus = .unread
    @State private var pdfPath: String = ""
    @State private var showPDFPicker = false
    @State private var errorMessage: String = ""

    let onSave: (_ title: String, _ authors: String, _ year: Int, _ statusRaw: String, _ pdfPath: String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("文献信息") {
                        TextField("标题", text: $title)
                        TextField("作者", text: $authors)
                        TextField("年份", text: $yearText)

                        Picker("状态", selection: $selectedStatus) {
                            ForEach(PaperStatus.allCases) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                    }

                    Section("PDF") {
                        if pdfPath.isEmpty {
                            Text("当前未选择 PDF")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(
                                AppSettings.localizedFormat(
                                    "已选择：%@",
                                    defaultValue: "Selected: %@",
                                    URL(fileURLWithPath: pdfPath).lastPathComponent
                                )
                            )
                                .font(.subheadline)

                            Text(pdfPath)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }

                        HStack {
                            Button("选择 PDF") {
                                showPDFPicker = true
                            }
                            .buttonStyle(.borderedProminent)

                            Button("移除 PDF") {
                                pdfPath = ""
                            }
                            .buttonStyle(.bordered)
                            .disabled(pdfPath.isEmpty)
                        }
                    }

                    if !errorMessage.isEmpty {
                        Section("错误") {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Divider()

                HStack {
                    Button("取消") {
                        dismiss()
                    }

                    Spacer()

                    Button("保存文献") {
                        savePaper()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .frame(minWidth: 460, minHeight: 420)
            .navigationTitle("新增文献")
        }
        .sheet(isPresented: $showPDFPicker) {
            PDFPicker { url in
                pdfPath = url.path
                showPDFPicker = false
            }
        }
    }

    private func savePaper() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthors = authors.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            errorMessage = AppSettings.localizedString("标题不能为空。")
            return
        }

        let year = Int(yearText) ?? Calendar.current.component(.year, from: .now)

        onSave(
            trimmedTitle,
            trimmedAuthors.isEmpty ? "Unknown Author" : trimmedAuthors,
            year,
            selectedStatus.rawValue,
            pdfPath
        )

        dismiss()
    }
}

#Preview {
    AddPaperView { _, _, _, _, _ in }
}
