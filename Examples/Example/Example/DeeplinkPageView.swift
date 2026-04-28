import SwiftUI

struct DeeplinkPageView: View {
    let url: URL

    var body: some View {
        NavigationView {
            List {
                Section("Received URL") {
                    Text(url.absoluteString)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }

                Section("Components") {
                    LabeledRow(label: "Scheme", value: url.scheme ?? "-")
                    LabeledRow(label: "Host", value: url.host ?? "-")
                    LabeledRow(label: "Path", value: url.path.isEmpty ? "/" : url.path)
                }

                if let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                   !items.isEmpty {
                    Section("Query Parameters") {
                        ForEach(items, id: \.name) { item in
                            LabeledRow(label: item.name, value: item.value ?? "(nil)")
                        }
                    }
                }

                Section("Test Links") {
                    ForEach(Self.testLinks, id: \.label) { link in
                        Button {
                            if let testURL = URL(string: link.url) {
                                UIApplication.shared.open(testURL)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(link.label)
                                Text(link.url)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Deeplink")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private static let testLinks: [(label: String, url: String)] = [
        ("Simple path", "nubrick-example://page/home"),
        ("With query params", "nubrick-example://page/detail?id=123&ref=test"),
        ("Campaign link", "nubrick-example://campaign?name=summer_sale&source=push"),
    ]
}

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
