import Foundation
import XCTest
import CPAModels
@testable import CPAMonitorBar

final class RequestHealthTimelineTests: XCTestCase {
    func testHealthLevelMatchesKeeperThresholds() {
        XCTAssertEqual(requestHealthLevel(success: 0, failure: 0), 0)
        XCTAssertEqual(requestHealthLevel(success: 4, failure: 6), 1)
        XCTAssertEqual(requestHealthLevel(success: 6, failure: 4), 2)
        XCTAssertEqual(requestHealthLevel(success: 75, failure: 25), 3)
        XCTAssertEqual(requestHealthLevel(success: 85, failure: 15), 4)
        XCTAssertEqual(requestHealthLevel(success: 99, failure: 1), 5)
    }

    func testPresentationKeepsFullDayBlocksAndUsesServerSummary() throws {
        let activity = try decodeActivity()

        let presentation = requestHealthPresentation(activity: activity)

        XCTAssertEqual(presentation.blocks.count, 3)
        XCTAssertEqual(presentation.blocks.first?.success, 5)
        XCTAssertEqual(presentation.totalSuccess, 99)
        XCTAssertEqual(presentation.totalFailure, 1)
        XCTAssertEqual(try XCTUnwrap(presentation.successRate), 98.4, accuracy: 0.0001)
    }

    func testPresentationDerivesSummaryWhenServerOmitsIt() throws {
        let activity = try decodeActivityWithoutSummary()

        let presentation = requestHealthPresentation(activity: activity)

        XCTAssertEqual(presentation.totalSuccess, 18)
        XCTAssertEqual(presentation.totalFailure, 2)
        XCTAssertEqual(try XCTUnwrap(presentation.successRate), 90, accuracy: 0.0001)
    }

    func testPresentationKeepsSuccessRateEmptyWhenThereAreNoRequests() throws {
        let payload = Data(
            #"{"total_success":0,"total_failure":0,"success_rate":0,"blocks":[{}]}"#.utf8
        )
        let activity = try JSONDecoder().decode(UsageActivityResponse.self, from: payload)

        let presentation = requestHealthPresentation(activity: activity)

        XCTAssertNil(presentation.successRate)
    }

    func testPresentationClampsUntrustedDimensionsToAvailableBlocks() throws {
        let activity = try decodeActivity()

        let presentation = requestHealthPresentation(activity: activity)

        XCTAssertEqual(presentation.preferredRows, 3)
        XCTAssertEqual(presentation.maxColumns, 3)
    }

    func testGridRowsUseAvailableColumnsWithoutExceedingKeeperRows() {
        XCTAssertEqual(requestHealthGridRows(blockCount: 364, preferredRows: 7, maxColumns: 52), 7)
        XCTAssertEqual(requestHealthGridRows(blockCount: 121, preferredRows: 7, maxColumns: 52), 3)
        XCTAssertEqual(requestHealthGridRows(blockCount: 0, preferredRows: 7, maxColumns: 52), 0)
    }

    private func decodeActivity() throws -> UsageActivityResponse {
        let payload = Data(#"""
        {
          "timezone":"Asia/Shanghai","rows":7,"columns":52,
          "window_start":"2026-07-28T12:00:00+08:00",
          "window_end":"2026-07-29T12:00:00+08:00",
          "total_success":99,"total_failure":1,"success_rate":98.4,
          "blocks":[
            {"start_time":"2026-07-29T01:00:00+08:00","end_time":"2026-07-29T02:00:00+08:00","success":5,"failure":0,"rate":1},
            {"start_time":"2026-07-29T04:00:00+08:00","end_time":"2026-07-29T05:00:00+08:00","success":8,"failure":2,"rate":0.8},
            {"start_time":"2026-07-29T11:00:00+08:00","end_time":"2026-07-29T12:00:00+08:00","success":10,"failure":0,"rate":1}
          ]
        }
        """#.utf8)
        return try JSONDecoder().decode(UsageActivityResponse.self, from: payload)
    }

    private func decodeActivityWithoutSummary() throws -> UsageActivityResponse {
        let payload = Data(#"""
        {
          "rows":7,"columns":52,
          "blocks":[
            {"success":8,"failure":2,"rate":0.8},
            {"success":10,"failure":0,"rate":1}
          ]
        }
        """#.utf8)
        return try JSONDecoder().decode(UsageActivityResponse.self, from: payload)
    }
}
