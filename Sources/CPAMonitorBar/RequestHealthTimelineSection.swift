import Foundation
import SwiftUI
import CPAModels

struct RequestHealthPresentation: Equatable {
    let blocks: [UsageActivityBlock]
    let totalSuccess: Int
    let totalFailure: Int
    let successRate: Double?
    let preferredRows: Int
    let maxColumns: Int
}

private enum RequestHealthLayout {
    static let defaultRows = 7
    static let defaultColumns = 52
}

private enum RequestHealthPalette {
    static let levels: [Color] = [
        .secondary.opacity(0.12),
        Color(red: 0.88, green: 0.27, blue: 0.30).opacity(0.82),
        Color(red: 0.94, green: 0.45, blue: 0.10).opacity(0.82),
        Color(red: 0.89, green: 0.68, blue: 0.10).opacity(0.82),
        Color(red: 0.48, green: 0.72, blue: 0.16).opacity(0.82),
        Color(red: 0.12, green: 0.68, blue: 0.32).opacity(0.82),
    ]
}

func requestHealthLevel(success: Int, failure: Int) -> Int {
    let safeSuccess = Double(max(success, 0))
    let total = safeSuccess + Double(max(failure, 0))
    guard total > 0 else { return 0 }
    let rate = safeSuccess / total
    if rate < 0.5 { return 1 }
    if rate < 0.65 { return 2 }
    if rate < 0.8 { return 3 }
    let healthyThreshold = min(0.99, 0.9 + 0.045 * max(0, log10(total / 10)))
    return rate < healthyThreshold ? 4 : 5
}

func requestHealthGridRows(
    blockCount: Int,
    preferredRows: Int,
    maxColumns: Int
) -> Int {
    guard blockCount > 0, preferredRows > 0, maxColumns > 0 else { return 0 }
    let rowsNeeded = (blockCount - 1) / maxColumns + 1
    return min(preferredRows, max(rowsNeeded, 1))
}

func requestHealthPresentation(activity: UsageActivityResponse) -> RequestHealthPresentation {
    let blocks = activity.blocks
    let totals = blocks.reduce(into: (success: 0, failure: 0)) { result, block in
        let success = result.success.addingReportingOverflow(max(block.success ?? 0, 0))
        let failure = result.failure.addingReportingOverflow(max(block.failure ?? 0, 0))
        result.success = success.overflow ? Int.max : success.partialValue
        result.failure = failure.overflow ? Int.max : failure.partialValue
    }
    let totalSuccess = max(activity.totalSuccess ?? totals.success, 0)
    let totalFailure = max(activity.totalFailure ?? totals.failure, 0)
    let totalRequests = Double(totalSuccess) + Double(totalFailure)
    let rate = totalRequests > 0
        ? Double(totalSuccess) / totalRequests * 100
        : nil
    let maximumDimension = max(blocks.count, 1)
    return RequestHealthPresentation(
        blocks: blocks,
        totalSuccess: totalSuccess,
        totalFailure: totalFailure,
        successRate: totalRequests > 0
            ? activity.successRate.map { min(max($0, 0), 100) } ?? rate
            : nil,
        preferredRows: min(
            max(activity.rows ?? RequestHealthLayout.defaultRows, 1),
            maximumDimension
        ),
        maxColumns: min(
            max(activity.columns ?? RequestHealthLayout.defaultColumns, 1),
            maximumDimension
        )
    )
}

struct RequestHealthTimelineSection: View {
    let state: SectionState<UsageActivityResponse>

    var body: some View {
        let presentation = state.value.map(requestHealthPresentation(activity:))
        DashboardSectionCard(
            section: .requestHealth,
            headerAccessory: { RequestHealthHeaderSummary(presentation: presentation) },
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    content(presentation: presentation)
                    SectionFeedback(state: state)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        )
    }

    @ViewBuilder
    private func content(presentation: RequestHealthPresentation?) -> some View {
        if let presentation {
            if presentation.blocks.isEmpty {
                emptyState
            } else {
                RequestHealthGrid(presentation: presentation)
            }
        } else if state.isLoading {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, minHeight: 54)
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        Text("暂无请求活动")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, minHeight: 54)
    }
}

private struct RequestHealthHeaderSummary: View {
    let presentation: RequestHealthPresentation?

    var body: some View {
        HStack(spacing: 8) {
            if let presentation {
                Text(formattedPercent(presentation.successRate))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text("· 24h")
                    .foregroundStyle(.secondary)
                HealthCount(color: .green, value: presentation.totalSuccess)
                HealthCount(color: .red.opacity(0.8), value: presentation.totalFailure)
            } else {
                Text("24h")
            }
        }
        .foregroundStyle(.secondary)
        .font(.caption)
    }
}

private struct HealthCount: View {
    let color: Color
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(value.formatted()).monospacedDigit()
        }
        .foregroundStyle(.secondary)
    }
}

private struct RequestHealthGrid: View {
    private static let spacing: CGFloat = 2
    let presentation: RequestHealthPresentation

    var body: some View {
        let rows = requestHealthGridRows(
            blockCount: presentation.blocks.count,
            preferredRows: presentation.preferredRows,
            maxColumns: presentation.maxColumns
        )
        let columns = (presentation.blocks.count + rows - 1) / rows
        GeometryReader { geometry in
            let cellSize = gridCellSize(width: geometry.size.width, columns: columns)
            HStack(alignment: .top, spacing: Self.spacing) {
                ForEach(0..<columns, id: \.self) { column in
                    VStack(spacing: Self.spacing) {
                        ForEach(0..<rows, id: \.self) { row in
                            cell(at: column * rows + row, size: cellSize)
                        }
                    }
                }
            }
        }
        .frame(height: CGFloat(rows) * 7 + CGFloat(max(rows - 1, 0)) * Self.spacing)
    }

    private func gridCellSize(width: CGFloat, columns: Int) -> CGFloat {
        let spacingWidth = CGFloat(max(columns - 1, 0)) * Self.spacing
        return min(7, max(4, (width - spacingWidth) / CGFloat(max(columns, 1))))
    }

    @ViewBuilder
    private func cell(at index: Int, size: CGFloat) -> some View {
        if presentation.blocks.indices.contains(index) {
            let block = presentation.blocks[index]
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color(for: block))
                .frame(width: size, height: size)
                .help(tooltip(for: block))
                .accessibilityLabel(tooltip(for: block))
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }

    private func color(for block: UsageActivityBlock) -> Color {
        let level = requestHealthLevel(success: block.success ?? 0, failure: block.failure ?? 0)
        return RequestHealthPalette.levels[level]
    }

    private func tooltip(for block: UsageActivityBlock) -> String {
        let start = dashboardShortTime(block.startTime)
        let end = dashboardShortTime(block.endTime)
        let success = max(block.success ?? 0, 0)
        let failure = max(block.failure ?? 0, 0)
        let total = Double(success) + Double(failure)
        let rate = total > 0 ? Double(success) / total * 100 : nil
        return "\(start) – \(end)\n成功 \(success)，失败 \(failure)，成功率 \(formattedPercent(rate))"
    }
}
