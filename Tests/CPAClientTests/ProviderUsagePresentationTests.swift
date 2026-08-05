import Foundation
import XCTest
@testable import CPAMonitorBar

final class ProviderUsagePresentationTests: XCTestCase {
    func testWalletShowsOneBalanceRow() throws {
        let presentation = ProviderUsagePresentation(
            state: state(mode: .wallet(balance: 28.46))
        )

        XCTAssertEqual(presentation.modeTitle, "钱包")
        XCTAssertEqual(presentation.rows, [
            ProviderUsageRowPresentation(
                id: "balance",
                label: "余额",
                value: "$28.46",
                fractionUsed: nil,
                tone: .normal,
                resetText: nil
            ),
        ])
    }

    func testSubscriptionOmitsZeroLimitAndFormatsUsageRows() throws {
        let presentation = ProviderUsagePresentation(
            state: state(
                mode: .subscription(
                    plan: "Pro Plan",
                    remaining: 57.7,
                    windows: [
                        window(id: "1d", used: 3.2, limit: 10),
                        window(id: "7d", used: 18.4, limit: 50),
                        window(id: "30d", used: 0, limit: 0),
                    ]
                )
            )
        )

        XCTAssertEqual(presentation.modeTitle, "Pro Plan")
        XCTAssertEqual(presentation.rows.map(\.label), ["剩余额度", "日额度", "周额度"])
        XCTAssertEqual(presentation.rows[0].value, "$57.70")
        XCTAssertEqual(presentation.rows[1].value, "$3.20 / $10.00 · 32%")
        XCTAssertEqual(presentation.rows[1].fractionUsed, 0.32)
        XCTAssertEqual(presentation.rows[2].tone, .normal)
    }

    func testKeyQuotaShowsTotalAndWindowResetLabels() throws {
        let reset = Date(timeIntervalSince1970: 1_786_000_000)
        let presentation = ProviderUsagePresentation(
            state: state(
                mode: .keyQuota(
                    status: "active",
                    used: 7.4,
                    limit: 20,
                    remaining: 12.6,
                    windows: [
                        window(
                            id: "5h",
                            used: 2.4,
                            limit: 10,
                            resetsAt: reset
                        ),
                        window(id: "1d", used: 8.2, limit: 30),
                        window(id: "7d", used: 20, limit: 50),
                    ]
                )
            )
        )

        XCTAssertEqual(presentation.modeTitle, "Key 额度 · active")
        XCTAssertEqual(
            presentation.rows.map(\.label),
            ["剩余额度", "5 小时", "1 天", "7 天"]
        )
        XCTAssertEqual(presentation.rows[0].value, "$12.60 / $20.00")
        XCTAssertNotNil(presentation.rows[1].resetText)
        XCTAssertTrue(presentation.rows[1].resetText?.hasPrefix("重置 ") == true)
    }

    func testPercentagesClampAndZeroLimitsAreOmitted() {
        let presentation = ProviderUsagePresentation(
            state: state(
                mode: .subscription(
                    plan: "Plan",
                    remaining: nil,
                    windows: [
                        window(id: "high", used: 200, limit: 100),
                        window(id: "low", used: -5, limit: 100),
                        window(id: "zero", used: 1, limit: 0),
                    ]
                )
            )
        )

        XCTAssertEqual(presentation.rows.map(\.fractionUsed), [1, 0])
        XCTAssertEqual(presentation.rows.map(\.tone), [.critical, .normal])
    }

    func testToneThresholds() {
        XCTAssertEqual(providerUsageTone(fractionUsed: 0.699), .normal)
        XCTAssertEqual(providerUsageTone(fractionUsed: 0.7), .warning)
        XCTAssertEqual(providerUsageTone(fractionUsed: 0.89999), .warning)
        XCTAssertEqual(providerUsageTone(fractionUsed: 0.9), .critical)
    }

    func testStaleStatePreservesRowsAndAddsUnavailableMessage() {
        var value = state(mode: .wallet(balance: 8))
        value.errorMessage = "服务暂不可用"

        let presentation = ProviderUsagePresentation(state: value)

        XCTAssertEqual(presentation.rows.first?.value, "$8.00")
        XCTAssertEqual(presentation.statusMessage, "用量暂不可用")
    }

    func testLoadingWithoutSnapshotOnlyShowsLoadingMessage() {
        let presentation = ProviderUsagePresentation(
            state: ProviderUsageState(
                snapshot: nil,
                isLoading: true,
                errorMessage: nil
            )
        )

        XCTAssertTrue(presentation.rows.isEmpty)
        XCTAssertEqual(presentation.statusMessage, "正在读取用量…")
    }

    private func state(mode: ProviderUsageMode) -> ProviderUsageState {
        ProviderUsageState(
            snapshot: ProviderUsageSnapshot(
                mode: mode,
                currency: "USD",
                expiresAt: nil,
                fetchedAt: Date(timeIntervalSince1970: 1)
            )
        )
    }

    private func window(
        id: String,
        used: Double,
        limit: Double,
        resetsAt: Date? = nil
    ) -> ProviderUsageWindow {
        ProviderUsageWindow(
            id: id,
            used: used,
            limit: limit,
            resetsAt: resetsAt
        )
    }
}
