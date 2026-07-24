import Foundation
import XCTest
import CPAModels

final class UsageOverviewSeriesTests: XCTestCase {
    func testDecodesKeeper1137BucketAndArraySeries() throws {
        let payload = Data(#"""
        {
          "usage":{"total_requests":40,"success_count":38,"failure_count":2},
          "series":{
            "buckets":[
              "2026-07-24T08:00:00+08:00",
              "2026-07-24T09:00:00+08:00"
            ],
            "requests":[33,7],
            "tokens":[2458987,1024],
            "rpm":[0.55,0.12],
            "tpm":[40983.1,17.1],
            "cost":[1.22235,null],
            "cache_read_rate":[92.78,null]
          }
        }
        """#.utf8)

        let overview = try JSONDecoder().decode(UsageOverviewResponse.self, from: payload)
        let series = try XCTUnwrap(overview.series)
        let firstBucket = "2026-07-24T08:00:00+08:00"
        let secondBucket = "2026-07-24T09:00:00+08:00"

        XCTAssertEqual(overview.usage?.totalRequests, 40)
        XCTAssertEqual(series.requests?[firstBucket], 33)
        XCTAssertEqual(series.requests?[secondBucket], 7)
        XCTAssertEqual(series.tokens?[firstBucket], 2_458_987)
        XCTAssertEqual(series.rpm?[firstBucket], 0.55)
        XCTAssertEqual(series.tpm?[firstBucket], 40_983.1)
        XCTAssertEqual(series.cost?[firstBucket], 1.22235)
        XCTAssertNil(series.cost?[secondBucket])
        XCTAssertEqual(series.cacheReadRate?[firstBucket] ?? nil, 92.78)
        XCTAssertNil(series.cacheReadRate?[secondBucket] ?? nil)
    }

    func testKeepsLegacyDictionarySeriesCompatible() throws {
        let payload = Data(#"""
        {
          "series":{
            "requests":{"2026-07-20T10:00:00Z":4},
            "cache_read_rate":{"2026-07-20T10:00:00Z":0.2}
          }
        }
        """#.utf8)

        let overview = try JSONDecoder().decode(UsageOverviewResponse.self, from: payload)

        XCTAssertEqual(overview.series?.requests?["2026-07-20T10:00:00Z"], 4)
        XCTAssertEqual(
            overview.series?.cacheReadRate?["2026-07-20T10:00:00Z"] ?? nil,
            0.2
        )
    }
}
