import SwiftUI

struct AboutPaperFocusView: View {
    // MARK: - Placeholder Content
    // 这些字段是预留给你后续修改的版权信息。
    private let appName = "PaperFocus"
    private let appVersion = "0.3.0"
    private let copyrightNotice = "© 2026 The PaperFocus authors. All rights reserved."
    private var licenseSummary: String {
        AppSettings.localizedString("本软件按 PolyForm Noncommercial License 1.0.0 授权。允许非商业使用、修改与分发；未经事先许可，不得用于商业用途。")
    }
    private let contactEmail = "support@example.com"
    private let website = "https://example.com"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                infoCard(title: LocalizedStringKey("应用信息")) {
                    row(LocalizedStringKey("应用名称"), appName)
                    row(LocalizedStringKey("版本"), appVersion)
                }

                infoCard(title: LocalizedStringKey("版权声明")) {
                    Text(copyrightNotice)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                    Text(licenseSummary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                infoCard(title: LocalizedStringKey("联系与支持")) {
                    row(LocalizedStringKey("邮箱"), contactEmail)
                    row(LocalizedStringKey("官网"), website)
                }
            }
            .padding(16)
        }
        .navigationTitle(Text("关于 PaperFocus"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func infoCard<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func row(_ key: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack {
        AboutPaperFocusView()
    }
}
