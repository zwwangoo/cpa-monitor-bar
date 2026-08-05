import Foundation
import XCTest
import CPAModels
@testable import CPAMonitorBar

final class CredentialHealthTrendTests: XCTestCase {
    func testAllBucketTonesAreGeneratedInOrder() throws {
        let health = try decodeHealth(#"""
        {
          "success_rate":90,
          "buckets":[
            {"success":0,"failure":0},
            {"success":4,"failure":0},
            {"success":2,"failure":1},
            {"success":0,"failure":1},
            {"success":0,"failure":1},
            {"success":0,"failure":1}
          ]
        }
        """#)

        XCTAssertEqual(
            credentialHealthTones(health),
            [.idle, .normal, .warning, .warning, .warning, .critical]
        )
    }

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

        XCTAssertEqual(
            credentialHealthTones(health),
            [.normal, .warning, .warning]
        )
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

        XCTAssertEqual(credentialHealthTones(health), [.critical])
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

        XCTAssertEqual(
            credentialHealthTones(health),
            [.warning, .warning, .critical]
        )
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

        XCTAssertEqual(credentialHealthTones(health), [.idle, .normal])
    }

    func testTrendBarHeightUsesReducedTwentyFourPointCeiling() {
        XCTAssertEqual(credentialHealthBarHeight(requestCount: 0, maximumRequestCount: 10), 4)
        XCTAssertEqual(credentialHealthBarHeight(requestCount: 5, maximumRequestCount: 10), 12)
        XCTAssertEqual(credentialHealthBarHeight(requestCount: 10, maximumRequestCount: 10), 24)
    }

    func testToneGenerationDoesNotOverflowForUntrustedCounts() throws {
        let health = try decodeHealth(
            #"{"buckets":[{"success":5000000000000000000,"failure":5000000000000000000}]}"#
        )

        XCTAssertEqual(credentialHealthTones(health), [.warning])
    }

    private func decodeHealth(_ json: String) throws -> UsageCredentialHealth {
        try JSONDecoder().decode(UsageCredentialHealth.self, from: Data(json.utf8))
    }
}
