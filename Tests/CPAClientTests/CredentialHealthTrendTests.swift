import Foundation
import XCTest
import CPAModels
@testable import CPAMonitorBar

final class CredentialHealthTrendTests: XCTestCase {
    func testIntermittentFailuresUseWarningToneForDegradedOverallHealth() throws {
        let health = try decodeHealth(#"""
        {
          "total_success":18,
          "total_failure":3,
          "success_rate":85.7,
          "buckets":[
            {"success":1,"failure":0,"rate":100},
            {"success":0,"failure":2,"rate":0},
            {"success":0,"failure":1,"rate":0}
          ]
        }
        """#)

        XCTAssertEqual(credentialHealthTone(for: 1, in: health), .warning)
        XCTAssertEqual(credentialHealthTone(for: 2, in: health), .warning)
    }

    func testLowOverallSuccessRateUsesCriticalTone() throws {
        let health = try decodeHealth(#"""
        {
          "total_success":4,
          "total_failure":6,
          "success_rate":40,
          "buckets":[{"success":0,"failure":1,"rate":0}]
        }
        """#)

        XCTAssertEqual(credentialHealthTone(for: 0, in: health), .critical)
    }

    func testThreeConsecutiveCompleteFailuresEscalateToCritical() throws {
        let health = try decodeHealth(#"""
        {
          "success_rate":90,
          "buckets":[
            {"success":0,"failure":1,"rate":0},
            {"success":0,"failure":1,"rate":0},
            {"success":0,"failure":1,"rate":0}
          ]
        }
        """#)

        XCTAssertEqual(credentialHealthTone(for: 0, in: health), .warning)
        XCTAssertEqual(credentialHealthTone(for: 1, in: health), .warning)
        XCTAssertEqual(credentialHealthTone(for: 2, in: health), .critical)
    }

    func testHealthyAndIdleBucketsUseNonAlarmTones() throws {
        let health = try decodeHealth(#"""
        {
          "success_rate":100,
          "buckets":[
            {"success":0,"failure":0},
            {"success":4,"failure":0,"rate":100}
          ]
        }
        """#)

        XCTAssertEqual(credentialHealthTone(for: 0, in: health), .idle)
        XCTAssertEqual(credentialHealthTone(for: 1, in: health), .normal)
    }

    func testTrendBarHeightUsesReducedTwentyFourPointCeiling() {
        XCTAssertEqual(credentialHealthBarHeight(requestCount: 0, maximumRequestCount: 10), 4)
        XCTAssertEqual(credentialHealthBarHeight(requestCount: 5, maximumRequestCount: 10), 12)
        XCTAssertEqual(credentialHealthBarHeight(requestCount: 10, maximumRequestCount: 10), 24)
    }

    private func decodeHealth(_ json: String) throws -> UsageCredentialHealth {
        try JSONDecoder().decode(UsageCredentialHealth.self, from: Data(json.utf8))
    }
}
