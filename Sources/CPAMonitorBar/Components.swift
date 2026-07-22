import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ErrorBanner: View {
    let message: String
    let stale: Bool

    var body: some View {
        Label(stale ? "数据可能已过期：\(message)" : message, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SectionFeedback<Value: Sendable>: View {
    let state: SectionState<Value>

    var body: some View {
        if let message = state.errorMessage {
            ErrorBanner(message: message, stale: state.isStale)
        }
    }
}
