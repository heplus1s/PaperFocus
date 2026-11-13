//
//  PaperDatailView.swift
//  PaperFocus
//
//  Created by PaperFocus on 25/3/2026.
//

import SwiftUI
import SwiftData

struct PaperDetailView: View {
    @Environment(\.modelContext) private var modelContext

    #if os(macOS)
    @EnvironmentObject private var navigationState: AppNavigationState
    #endif

    let paper: Paper

    @State private var showPDFPicker = false
    @State private var showPDFPreview = false
    @State private var pdfPreviewURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                paperInfoCard
                abstractCard
                notesCard
                pdfCard
                actionCard
            }
            .padding()
        }
        .navigationTitle("文献详情")
        .sheet(isPresented: $showPDFPicker) {
            PDFPicker { url in
                attachPDF(url: url)
                showPDFPicker = false
            }
        }
        .navigationDestination(isPresented: $showPDFPreview) {
            if let pdfPreviewURL {
                PDFPreviewView(
                    url: pdfPreviewURL,
                    title: paper.displayTitle
                )
            }
        }
    }

    private var paperInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(paper.displayTitle)
                .font(.title2.bold())

            Text(paper.displayAuthors)
                .font(.headline)
                .foregroundStyle(.secondary)

            detailRow("年份", paper.displayYear)
            detailRow("期刊", paper.displayJournal)
            detailRow("DOI", paper.doi.isEmpty ? "—" : paper.doi)
            detailRow("状态", paper.status.displayName)
            detailRow("标签", paper.tagList.isEmpty ? "—" : paper.tagList.joined(separator: ", "))

            statusBadge(for: paper.status)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var abstractCard: some View {
        if !paper.abstractText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("摘要")
                    .font(.title3.bold())

                Text(paper.abstractText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    @ViewBuilder
    private var notesCard: some View {
        if !paper.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("备注")
                    .font(.title3.bold())

                Text(paper.notes)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private var pdfCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PDF")
                .font(.title3.bold())

            if paper.pdfPath.isEmpty {
                Text("当前还没有关联 PDF。")
                    .foregroundStyle(.secondary)
            } else {
                Text(
                    AppSettings.localizedFormat(
                        "已关联：%@",
                        defaultValue: "Linked: %@",
                        paper.pdfURL?.lastPathComponent ?? AppSettings.localizedString("未知文件")
                    )
                )
                    .font(.subheadline)

                Text(paper.pdfPath)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack {
                Button("选择 PDF") {
                    showPDFPicker = true
                }
                .buttonStyle(.borderedProminent)

                Button("预览 PDF") {
                    openPDF()
                }
                .buttonStyle(.bordered)
                .disabled(paper.pdfPath.isEmpty)
            }

            if !paper.pdfPath.isEmpty {
                Button("移除关联") {
                    removePDF()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var actionCard: some View {
        #if os(macOS)
        Button {
            navigationState.prepareTimer(for: paper.displayTitle)
        } label: {
            Label("放入右侧专注阅读", systemImage: "timer")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        #else
        NavigationLink {
            FocusTimerView(paper: paper)
        } label: {
            Label("以这篇文献开始专注阅读", systemImage: "timer")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        #endif
    }

    @ViewBuilder
    private func statusBadge(for status: PaperStatus) -> some View {
        Text(status.displayName)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func detailRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .font(.body)
    }

    private func attachPDF(url: URL) {
        paper.pdfPath = url.path
        paper.pdfFileName = url.lastPathComponent
        paper.hasPDF = true
        paper.updatedAt = .now
        try? modelContext.save()
    }

    private func openPDF() {
        guard !paper.pdfPath.isEmpty else { return }

        let url = URL(fileURLWithPath: paper.pdfPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        pdfPreviewURL = url
        showPDFPreview = true
    }

    private func removePDF() {
        paper.pdfPath = ""
        paper.pdfFileName = ""
        paper.hasPDF = false
        paper.updatedAt = .now
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        PaperDetailView(
            paper: Paper(
                title: "Example Paper",
                authors: "Author A, Author B",
                year: 2024
            )
        )
    }
}
